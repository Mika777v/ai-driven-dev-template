#!/usr/bin/env bash
# errnav のテスト。外部のテストの仕組みを使わず、bash だけで動かす（macOS の bash 3.2 でも動くように）。
#
# 使い方:
#   bash tools/errnav/tests/run.sh
#
# tests/fixtures/project は、PHP・Python・Node.js・Go・Ruby・Java で実際に出したエラーの出力を、
# コンテナの中のようなパス（/var/www/html・/app など）に書き換えたもの。手元のファイルに結び付けられるかを確かめる。

set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ERRNAV="$HERE/../bin/errnav"
PROJECT="$HERE/fixtures/project"
WORK=$(mktemp -d 2>/dev/null || mktemp -d -t errnav)
trap 'rm -rf "$WORK"' EXIT
export ERRNAV_CACHE_DIR="$WORK/cache" ERRNAV_COLOR=never LANG=C.UTF-8 LC_ALL=C.UTF-8
# 手元の設定に左右されないようにする
unset ERRNAV_LOGS ERRNAV_PLUGINS ERRNAV_PATH_MAP ERRNAV_OPEN_CMD ERRNAV_EDITOR ERRNAV_LINK

pass=0; fail=0
ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
ng()   { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "$2" ] && printf '%s\n' "$2" | sed 's/^/       | /' | head -n 30; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) ng "$1" "期待: $3"$'\n'"実際:"$'\n'"$2" ;; esac; }
hasnt(){ case "$2" in *"$3"*) ng "$1" "含まないはず: $3" ;; *) ok "$1" ;; esac; }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1" "期待: $3 / 実際: $2"; fi; }
en()   { "$ERRNAV" --root "$PROJECT" "$@" 2>&1; }

# イベントの番号をメッセージから引く（番号はログの更新日時の順で変わるため）
id_of() { awk -F'\t' -v m="$1" 'index($6, m) { print $1; exit }' "$ERRNAV_CACHE_DIR/events.tsv"; }
top_of() { awk -F'\t' -v id="$1" '$1 == id && $7 == 1 { print $6 ":" $4; exit }' "$ERRNAV_CACHE_DIR/frames.tsv"; }

echo "== ログの検出"
out=$(en logs)
for f in storage/logs/laravel.log logs/php.log logs/python-crash.log logs/node.log logs/go.log logs/ruby.log logs/java-crash.log logs/app.log; do
  has "検出: $f" "$out" "$f"
done
hasnt "vendor の中は探さない" "$out" "vendor/"

echo "== 抽出とまとめ"
out=$(en scan --limit 50)
has  "Laravel のエラー" "$out" "Undefined variable \$usr"
has  "同じエラーを数える（×2）" "$out" "×2"
hasnt "INFO の行は数えない" "$out" "Retrying job"
hasnt "INFO の行は数えない（Health check）" "$out" "Health check"
has  "JSON のコンテキストを省く" "$out" "Database connection failed"
hasnt "JSON のコンテキストを省く（パスワードを一覧に出さない）" "$out" "hunter2"
eq   "イベントの数" "$(awk 'END { print NR }' "$ERRNAV_CACHE_DIR/events.tsv")" "10"

echo "== 発生箇所の特定（パスの解決）"
eq "Laravel: /var/www/html → app/..." "$(top_of "$(id_of 'Undefined variable')")" "app/Http/Controllers/UserController.php:12"
eq "PHP CLI: Uncaught" "$(top_of "$(id_of 'User not found')")" "app/Services/UserService.php:6"
eq "Python: プロジェクトの最初のフレーム" "$(top_of "$(id_of 'JSONDecodeError')")" "src/app.py:4"
eq "Python: ログの中のトレース" "$(top_of "$(id_of 'ValueError: bad payload')")" "src/app.py:4"
eq "Node.js" "$(top_of "$(id_of 'Cannot read properties')")" "src/app.js:3"
eq "Go: panic" "$(top_of "$(id_of 'index out of range')")" "main.go:4"
eq "Ruby" "$(top_of "$(id_of 'RuntimeError')")" "lib/app.rb:2"
eq "Java: 根本の原因（Caused by）を先に" "$(top_of "$(id_of 'IllegalStateException')")" "src/main/java/com/example/Main.java:5"

echo "== スタックトレースの解析"
id=$(id_of 'JSONDecodeError')
frames=$(awk -F'\t' -v id="$id" '$1 == id { print $2 " " $3 ":" $4 " " $7 }' "$ERRNAV_CACHE_DIR/frames.tsv")
has "Python: 0 = いちばん内側（標準ライブラリ）" "$frames" "0 /usr/local/lib/python3.13/json/decoder.py:361 0"
has "Python: 外側ほど番号が大きい" "$frames" "5 /app/src/app.py:9 1"
id=$(id_of 'Cannot read properties')
frames=$(awk -F'\t' -v id="$id" '$1 == id { print $3 " " $7 }' "$ERRNAV_CACHE_DIR/frames.tsv")
has "Node.js: node:internal はプロジェクトの外" "$frames" "node:internal/modules/cjs/loader 0"
id=$(id_of 'Undefined variable')
frames=$(awk -F'\t' -v id="$id" '$1 == id { print $6 " " $7 }' "$ERRNAV_CACHE_DIR/frames.tsv")
has "vendor はプロジェクトの外" "$frames" "vendor/laravel/framework/src/Illuminate/Routing/Controller.php 0"

echo "== 詳細の表示"
out=$(en show "$(id_of 'index out of range')")
has "発生箇所のソースに印" "$out" ">    4 | 	return xs[i]"
has "Go の関数名" "$out" "main.get"
out=$(en show "$(id_of 'IllegalStateException')")
has "Java の根本原因" "$out" "根本原因: java.lang.NullPointerException"

echo "== 呼び出し経路"
out=$(en tree "$(id_of 'JSONDecodeError')")
has "入口が先頭" "$(printf '%s\n' "$out" | sed -n 2p)" "src/app.py:9"
has "発生箇所の印" "$out" "◀ 発生箇所"
out=$(en tree "$(id_of 'Cannot read properties')")
has "外部のフレームが3つ以上続くと畳む" "$out" "6 件（プロジェクトの外）"
out=$(en tree "$(id_of 'JSONDecodeError')" --all)
has "--all で全部出す" "$out" "json/decoder.py:361"

echo "== ソースジャンプ"
out=$(en open "$(id_of 'Cannot read properties')" < /dev/null)
eq "端末でないときは場所を出す" "$out" "src/app.js:3"
out=$(ERRNAV_FORCE_OPEN=1 ERRNAV_OPEN_CMD='echo OPEN {file} {line}' en open "$(id_of 'Cannot read properties')" < /dev/null)
has "ERRNAV_OPEN_CMD の形で開く" "$out" "OPEN $PROJECT/src/app.js 3"
# 本物のエディタの代わりに、受け取った引数を出すだけのコマンドを置く
mkdir -p "$WORK/bin"
for e in code phpstorm vim; do printf '#!/bin/sh\necho %s "$@"\n' "$e" > "$WORK/bin/$e"; chmod +x "$WORK/bin/$e"; done
out=$(ERRNAV_FORCE_OPEN=1 ERRNAV_EDITOR="$WORK/bin/code" en open "$(id_of 'Cannot read properties')" < /dev/null)
has "VS Code の形（-g file:line）" "$out" "code -g $PROJECT/src/app.js:3"
out=$(ERRNAV_FORCE_OPEN=1 ERRNAV_EDITOR="$WORK/bin/phpstorm" en open "$(id_of 'Undefined variable')" < /dev/null)
has "PhpStorm の形（--line N file）" "$out" "phpstorm --line 12 $PROJECT/app/Http/Controllers/UserController.php"
out=$(ERRNAV_FORCE_OPEN=1 ERRNAV_EDITOR="$WORK/bin/vim" en open "$(id_of 'Undefined variable')" 2 < /dev/null)
has "フレームの番号を指定（vim の +N）" "$out" "vim +12 $PROJECT/app/Http/Controllers/UserController.php"

echo "== AI 解析用のコンテキスト"
out=$(en context "$(id_of 'Database connection failed')")
for sec in "## 環境" "## エラー" "## スタックトレース" "## 呼び出し経路" "## 関連するソース" "## ログ" "## 依頼"; do has "節: $sec" "$out" "$sec"; done
has "ソースの言語" "$out" '```php'
hasnt "パスワードを伏せる" "$out" "hunter2"
out=$(en context "$(id_of 'ValueError: bad payload')")
hasnt "token を伏せる" "$out" "abcd1234efgh5678"
hasnt "Bearer を伏せる" "$out" "eyJhbGciOiJIUzI1NiJ9"
en context "$(id_of 'Cannot read properties')" -o "$WORK/ctx.md" >/dev/null
has "-o でファイルに書く" "$(head -n 1 "$WORK/ctx.md")" "# 障害解析のコンテキスト"

out=$(en context "$(id_of 'Cannot read properties')")
has "関数の出てくる箇所（rg）" "$out" "src/app.js:6:  load(1);"
out=$(ERRNAV_NO_RG=1 en context "$(id_of 'Cannot read properties')")
has "関数の出てくる箇所（rg が無いときは grep）" "$out" "src/app.js:1:function load(id) {"

echo "== 標準入力"
out=$(sed -n '1,30p' "$PROJECT/logs/node.log" | en scan -)
has "パイプで渡した出力を読む" "$out" "src/app.js:3"

echo "== 再現の確認"
cp -R "$PROJECT" "$WORK/p"
# repro はコマンドを今のディレクトリで動かすので、プロジェクトの中に入って試す
rp() { (cd "$WORK/p" && "$ERRNAV" "$@" 2>&1); }
rp scan >/dev/null
out=$(rp repro -- sh -c 'printf "%s\n" "[2026-11-04 12:00:00] local.ERROR: Fresh failure {\"exception\":\"[object] (Exception(code: 0): x at /var/www/html/app/main.php:5)" "[stacktrace]" "#0 /var/www/html/app/main.php(7): handle()" "#1 {main}" "\"}" >> storage/logs/laravel.log')
code=$?
eq "増えたエラーがあれば 0（再現した）" "$code" "0"
has "増えた分だけを読む" "$out" "Fresh failure"
hasnt "前からあるエラーは混ぜない" "$out" "Undefined variable"
has "元のログの行番号を保つ" "$(rp show latest)" "storage/logs/laravel.log:29"
rp repro -- true >/dev/null; eq "増えていなければ 1（再現しなかった）" "$?" "1"
rp repro --bisect -- true >/dev/null; eq "--bisect で入れ替える" "$?" "0"
rp repro --expect 'boom' -- sh -c 'echo boom >&2' >/dev/null; eq "--expect はコマンドの出力も見る" "$?" "0"

echo "== 設定"
mkdir -p "$WORK/p/.errnav"
printf '%s\n' 'ERRNAV_LOGS="logs/node.log"' 'ERRNAV_NO_SEARCH=1' 'ERRNAV_GENERIC_LOG_GLOBS=' > "$WORK/p/.errnav/config"
out=$(rp logs)
has "ERRNAV_LOGS で指定したログ" "$out" "logs/node.log"
hasnt "探さない設定" "$out" "laravel.log"

echo
echo "結果: $pass 件成功 / $fail 件失敗"
[ "$fail" -eq 0 ]
