# errnav — IDE に依存しない障害解析ツール

> **目的**: ログからエラーを取り出し、スタックトレースを正規化して、発生箇所のソースへすぐに飛べるようにする。PhpStorm で「トレースの行を押すとソースが開く」体験を、端末だけで再現する。
> **いつ読むか**: 不具合を調べるとき・直したものが再現しなくなったかを確かめるとき・AI に不具合の調査を頼むとき。
> **設計**: [ARCHITECTURE.md](ARCHITECTURE.md)

```
$ errnav scan
  ID 件数  LEVEL    TIME                 MESSAGE  →  発生箇所
   9   ×2  ERROR    2026-11-04 10:01:00  Undefined variable $usr
                               → app/Http/Controllers/UserController.php:12
   4   ×1  PANIC    -                    panic: runtime error: index out of range [5] with length 3
                               → main.go:4

$ errnav open 9        # エディタで app/Http/Controllers/UserController.php の12行目を開く
$ errnav context 9 --copy   # AI に貼るためのコンテキストをクリップボードへ
```

## できること

| 機能 | コマンド | 内容 |
|---|---|---|
| ログファイルの自動検出 | `errnav logs` | よくある置き場所・プラグインの候補・深さ4までの `*.log` を新しい順に（`.gitignore` されたログも探す） |
| エラーの抽出 | `errnav scan` | タイムスタンプ・レベルでログを区切り、エラーだけを取り出す。同じエラーは件数にまとめる |
| 発生箇所の特定 | `errnav scan` / `show` | コンテナの中のパス（`/var/www/html/...`）を手元のファイルに結び付け、プロジェクトのコードの最初のフレームを示す |
| スタックトレースの解析 | `errnav show ID` | PHP・Python・Node.js（vitest を含む）・Java/Kotlin・Go・Ruby のトレースを「0 = 発生箇所」の順にそろえる。例外の連鎖は根本の原因を先に |
| ソースジャンプ | `errnav open ID [FRAME]` | 設定したエディタで、その行を開く（vim・VS Code・PhpStorm・Sublime など）。fzf があればフレームを選べる |
| 呼び出し経路の可視化 | `errnav tree ID` | 入口から発生箇所までを木の形で。依存ライブラリのフレームが続くところは畳む |
| AI 解析用コンテキスト | `errnav context ID` | 環境・トレース・ソースの抜粋・最近の変更・ログを Markdown 1つに。秘密情報らしい値は伏せる |
| 再現の確認 | `errnav repro -- CMD` | コマンドを動かした間に**増えたログだけ**を解析。再現したら終了コード 0 |

## 入れ方

追加の導入は要りません（Bash と標準のコマンドだけで動きます）。パスを通すと楽です。

```bash
ln -s "$PWD/tools/errnav/bin/errnav" ~/.local/bin/errnav
```

```bash
errnav doctor
```

あると便利なもの（無くても動く）:

| ツール | あるとどうなるか | 無いとき |
|---|---|---|
| [fzf](https://github.com/junegunn/fzf) | `errnav` だけで一覧を選び、プレビューを見て Enter で開ける | 番号で指定する |
| [bat](https://github.com/sharkdp/bat) | ソースの抜粋に色が付く | 行番号つきの文字だけ |
| [fd](https://github.com/sharkdp/fd) | ログ・ファイルの探索が速い | `find` を使う |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | AI 用コンテキストで、発生箇所の関数が出てくる箇所を速く探す | `grep -r` を使う |

Debian / Ubuntu で入る `fdfind`・`batcat` の名前でも見つけます。

## 使い方

### よくある流れ

```bash
errnav                    # 一覧（fzf があれば選んで、Enter で発生箇所を開く）
errnav show latest        # 最新のエラーの詳細
errnav tree latest        # 呼び出し経路
errnav open latest        # 発生箇所をエディタで開く
errnav open 9 3           # #9 のフレーム3を開く
```

### fzf の画面のキー

| キー | 動き |
|---|---|
| Enter | 発生箇所をエディタで開く |
| Ctrl-O | フレームを選んで開く |
| Ctrl-T | 呼び出し経路 |
| Ctrl-A | AI 用のコンテキストをクリップボードに写す |

### コマンドの出力を直接読む

ログのファイルが無くても、パイプで渡せます。

```bash
php artisan test 2>&1 | errnav scan -
```

```bash
npm test 2>&1 | errnav scan -
```

### 再現を確かめる（直したかの確認）

```bash
errnav repro --expect 'Undefined variable' -- curl -s localhost:8000/users/7
```

- コマンドを動かす前のログの大きさを覚え、**増えた分**とコマンドの出力だけを解析します（前からあるエラーと混ざらない）
- 終了コード: 再現した = 0、再現しなかった = 1
- `--bisect` を付けると逆になり、`git bisect run` で「どのコミットから出るようになったか」を探せます:

```bash
git bisect run tools/errnav/bin/errnav repro --bisect --expect 'Undefined variable' -- php artisan test --filter UserTest
```

### AI に調査を頼む

```bash
errnav context latest --copy
```

```bash
errnav context 9 -o /tmp/error-9.md
```

出力は「環境 → エラー → 正規化したトレース → 呼び出し経路 → 発生箇所のソース → 発生箇所の関数が出てくる箇所 → 最近の変更 → ログの全文 → 依頼」の順の Markdown です。`password`・`token`・`Bearer`・AWS のキーなどの値は `***` に伏せますが、**できる範囲の処理なので、貼る前に目で確かめてください。**

AI のエージェント（Claude Code など）がリポジトリの中で動いているなら、`errnav show` と `errnav context` をそのまま実行させても構いません。

## 設定

`<プロジェクトのルート>/.errnav/config` に、シェルの変数として書きます（`.envrc` と同じく、シェルとして読み込まれます）。

```bash
# 読むログ（グロブ。空白区切り）
ERRNAV_LOGS="storage/logs/*.log docker/logs/app.log"

# ログのパスと手元のパスの対応（多くは自動で結び付くので、合わないときだけ）
ERRNAV_PATH_MAP="/var/www/html=. /usr/src/app=."

# エディタ（どれか1つ）
ERRNAV_EDITOR="phpstorm"                 # PhpStorm（--line N file の形で開く）
# ERRNAV_EDITOR="code"                   # VS Code（-g file:line）
# ERRNAV_OPEN_CMD='nvim +{line} {file}'  # 自由な形

# 端末のリンクを押したときに開くアプリ（OSC 8 に対応した端末で）
# ERRNAV_LINK=phpstorm   # phpstorm / idea / vscode / cursor / file

# そのほか
# ERRNAV_PLUGINS="php node"     # 使うプラグインを決め打ち（既定は自動で検出）
# ERRNAV_TAIL_LINES=5000        # ログの末尾の何行を読むか（0 で全部）
# ERRNAV_CONTEXT_LINES=6        # ソースの抜粋の前後の行数
# ERRNAV_WARN=1                 # WARN もエラーとして扱う
# ERRNAV_VENDOR_RE='(^|/)(vendor|node_modules)/'   # プロジェクトの外とみなすパス
```

キャッシュは `.errnav/cache/` に作ります（`.gitignore` 済み）。

### 環境変数

| 変数 | 意味 |
|---|---|
| `ERRNAV_ROOT` | プロジェクトのルート（`--root` と同じ） |
| `ERRNAV_CACHE_DIR` | キャッシュの置き場所 |
| `ERRNAV_COLOR` | `always` / `never` / `auto`。`NO_COLOR` も見る |
| `ERRNAV_ASCII` | 1 で木の線などを ASCII にする |
| `ERRNAV_NO_FZF` / `ERRNAV_NO_BAT` | 入っていても使わない |

## プラグイン

フレームワークごとの差（ログの置き場所・ログの癖・ソースの置き場所）を受け持ちます。

| プラグイン | 当てはまる条件 | 内容 |
|---|---|---|
| `php` | `composer.json`・`artisan`・`index.php` | Laravel（`storage/logs`）・Symfony（`var/log`）、Monolog の JSON 形式のトレースを分ける |
| `node` | `package.json` | `logs/`・npm / yarn のデバッグのログ、ソースマップのメモ |
| `python` | `pyproject.toml`・`requirements.txt`・`manage.py` など | `src/` をソースの置き場所に、Django のメモ |
| `java` | `pom.xml`・`build.gradle(.kts)` | `src/main/java` などからクラスのファイルを探す |
| `go` | `go.mod` | `-trimpath` のパスの結び付け |
| `ruby` | `Gemfile` | Rails の `log/`、字下げの無いトレースを整える |

プロジェクト固有のプラグインは `.errnav/plugins/<名前>.sh` に置きます。最小の例:

```bash
# .errnav/plugins/myapp.sh
errnav_register myapp
errnav_myapp_detect() { [ -f "$1/myapp.toml" ]; }
errnav_myapp_logs() { printf '%s\n' 'var/myapp/*.log'; }
errnav_myapp_path_map() { printf '%s\n' '/opt/myapp=.'; }
```

使える関数の一覧は [ARCHITECTURE.md §5](ARCHITECTURE.md)。

## 動く環境

- Linux・WSL・macOS（bash 3.2 以上。macOS の標準の bash と BSD のコマンドで動くように書いています）
- awk は gawk・mawk・macOS の awk のどれでも

## AI のスキルとして使う

Claude Code では、[skill/SKILL.md](skill/SKILL.md) を `.claude/skills/errnav/SKILL.md` に置くと、「エラーを調べる」場面でだけ errnav の手順が読み込まれます（ふだんの作業では、名前と説明の数十トークンしか読まれない）。

```bash
mkdir -p .claude/skills/errnav && cp tools/errnav/skill/SKILL.md .claude/skills/errnav/
```

## 効果（routepense で測った結果）

2026-11-04 に、[routepense](https://github.com/Mika777v/routepense) に仕込んだ3つの不具合を Claude Code に調べさせて比べた（各条件1回なので傾向として読む）。どの条件でも、3つとも原因のファイルと行を正しく答えた。

| 不具合 | errnav なし | errnav あり | 短い CLAUDE.md | 短い CLAUDE.md + スキル |
|---|---|---|---|---|
| 例外（落ちる場所と原因が離れている） | 3回 / 15.2万 | 2回 / 11.3万 | 2回 / 10.3万 | 3回 / 14.0万 |
| ライブラリ（SQLite）の奥のエラー | 5回 / 22.6万 | 3回 / 15.4万 | 4回 / 17.8万 | 3回 / 13.9万 |
| 例外なし（値だけが違う） | 2回 / 10.9万 | 2回 / 11.2万 | 2回 / 9.9万 | 3回 / 13.5万 |

（ツールの呼び出しの回数 / トークンの合計）

わかったこと:

- **例外の出る不具合では、errnav でツールの呼び出しが1〜2回、トークンが2〜4割減った。** 例外の出ない不具合では差が無い（errnav が原因の場所を示せないため）
- **毎回読まれる CLAUDE.md を短くすると、1ターンあたり約1割減る**（約 10.8KB → 1.2KB で約 3,400 トークン）。AI はターンのたびに全部を読み直すので、詳しい運用は `docs/` に移し、CLAUDE.md（AGENTS.md）には要点だけを置く
- **スキルにすると、AI は指示されなくても調査のときに errnav を使った。** ただ読み込みでターンが2つ増えるので、小さな不具合では得も損も小さい

測るのに使ったスクリプトは、テンプレートには入れていない（routepense 専用のため）。git の履歴（#3〜#5 で追加し、その後に削除）と、ブランチ `bench/agent-bench`（テンプレートの運用ルール全体を測る版）に残っている。

## テスト

```bash
bash tools/errnav/tests/run.sh
```

`tests/fixtures/project` には、PHP・Python・Node.js・Go・Ruby・Java で実際に出したエラーの出力を、コンテナの中のようなパスに書き換えて置いています。新しいログの形に対応するときは、実際の出力をここに足してテストを書いてください。

## 制限

- Windows のパス（`C:\...`）には対応していません（WSL の中のパスは使えます）
- ビルドした後のコード（`dist/`・圧縮した JS）は、ソースマップで元に戻しません（`node --enable-source-maps` で元のパスを出すと結び付きます）
- 1行に全部が入った JSON のログは、PHP（Monolog）の形だけを分けます。ほかの形は、トレースの最初の1フレームだけを読みます
- 秘密情報を伏せる処理は、よくある書き方だけを対象にしています
