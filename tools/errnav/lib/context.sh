# errnav: AI 解析用のコンテキスト（Markdown）を作る
#
# AI に「このエラーを直して」と頼むときに、AI が自分で集めると時間がかかるもの
# （正規化したトレース・発生箇所のソース・最近の変更・ログの前後）を1つにまとめる。

# 秘密情報らしいものを伏せる（できる範囲で。貼る前に人が目で確かめる）
# macOS の sed は大文字小文字を無視する I が使えないので、よくある書き方を並べている
# Bearer を先に伏せる（「Authorization: Bearer xxx」の xxx を残さないため）
errnav_redact() {
  sed -E \
    -e 's/(Bearer)[[:space:]]+[A-Za-z0-9._~+\/=-]+/\1 ***/g' -e 's/(Basic)[[:space:]]+[A-Za-z0-9+\/=]{12,}/\1 ***/g' \
    -e 's/((password|Password|PASSWORD|passwd|pwd|PWD|secret|Secret|SECRET|token|Token|TOKEN|api[_-]?key|API[_-]?KEY|apiKey|ApiKey|access[_-]?key|ACCESS[_-]?KEY|accessKey|client[_-]?secret|CLIENT[_-]?SECRET|clientSecret|authorization|Authorization|AUTHORIZATION|cookie|Cookie|COOKIE|session[_-]?id|SESSION[_-]?ID|sessionId)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?)[^"'"'"'[:space:],&}]+/\1***/g' \
    -e 's/AKIA[0-9A-Z]{16}/AKIA***/g' \
    -e 's/(gh[pousr]_)[A-Za-z0-9]{20,}/\1***/g' \
    -e 's/(sk-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]{16,}/\1***/g' \
    -e 's#(://[^/:@[:space:]]+:)[^@/[:space:]]+@#\1***@#g'
}

_errnav_lang_of() {
  case "$1" in
    *.php) echo php ;; *.py) echo python ;; *.js|*.mjs|*.cjs) echo javascript ;; *.ts|*.tsx) echo typescript ;;
    *.java) echo java ;; *.kt) echo kotlin ;; *.go) echo go ;; *.rb) echo ruby ;; *.rs) echo rust ;;
    *.cs) echo csharp ;; *.sh) echo bash ;; *) echo "" ;;
  esac
}

# フレームの関数の表記から、検索に使う名前だけを取り出す
#   UserService->find() → find / com.example.Main.name → name / main.get → get / Object.<anonymous> → （なし）
_errnav_func_name() {
  awk '{
    s = $0; sub(/\(.*$/, "", s); sub(/ \[as .*$/, "", s); sub(/^(async|new) /, "", s)
    n = split(s, a, /->|::|[.#: ]/); s = a[n]
    if (s ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && length(s) >= 3 && s !~ /^(main|run|call|handle|invoke|apply|anonymous|module|closure)$/) print s
  }'
}

# 単語として検索する（rg があれば rg、無ければ grep）。依存ライブラリ・キャッシュは除く
errnav_search_word() {
  local w="$1"
  if [ -n "$ERRNAV_RG" ]; then
    (cd "$ERRNAV_ROOT" && rg -n --no-heading -w -F -g '!vendor/' -g '!node_modules/' -g '!.errnav/' -g '!*.log' -- "$w" . 2>/dev/null | sed 's#^\./##')
  else
    (cd "$ERRNAV_ROOT" && grep -rnwF --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.errnav --exclude='*.log' -- "$w" . 2>/dev/null | sed 's#^\./##')
  fi
}

# errnav_context ID [最大のフレーム数]
errnav_context() {
  local id; id=$(errnav_resolve_id "$1"); local maxf="${2:-3}"
  errnav_load_event "$id"
  local ERRNAV_COLOR_ON= C_RESET= C_BOLD= C_DIM= C_RED= C_GREEN= C_YELLOW= C_BLUE= C_CYAN=
  local ERRNAV_PLAIN=1

  local count; count=$(awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$ERRNAV_CACHE/groups.tsv")
  {
    printf '# 障害解析のコンテキスト: %s\n\n' "$EV_SUMMARY"
    printf '> errnav %s が %s に作成。秘密情報らしい値は伏せているが、貼る前に目で確かめること。\n\n' "$ERRNAV_VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf '## 環境\n\n'
    printf -- '- プロジェクト: `%s`\n' "$(basename "$ERRNAV_ROOT")"
    printf -- '- OS: %s（%s）\n' "$(errnav_os)" "$(uname -sr 2>/dev/null)"
    if git -C "$ERRNAV_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      local dirty; dirty=$(git -C "$ERRNAV_ROOT" status --porcelain 2>/dev/null | grep -v '^?? .errnav/' | awk 'END { print NR }')
      printf -- '- git: ブランチ `%s`、コミット `%s`、未コミットの変更 %s 件\n' \
        "$(git -C "$ERRNAV_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)" "$(git -C "$ERRNAV_ROOT" rev-parse --short HEAD 2>/dev/null)" "$dirty"
    fi
    printf -- '- 検出したフレームワーク: %s\n\n' "${ERRNAV_ACTIVE:- なし}"

    printf '## エラー\n\n'
    printf -- '- 内容: `%s`\n' "$EV_SUMMARY"
    [ -n "$EV_ROOT" ] && printf -- '- 根本原因（Caused by）: `%s`\n' "$EV_ROOT"
    printf -- '- レベル: %s\n' "$EV_LEVEL"
    [ -n "$EV_TIME" ] && printf -- '- 時刻: %s\n' "$EV_TIME"
    printf -- '- ログ: `%s` の %s 行目\n' "$EV_LOG" "$EV_LINE"
    [ -n "$count" ] && printf -- '- 同じエラーの件数（このスキャンの範囲）: %s\n' "$count"
    echo

    printf '## スタックトレース（正規化。0 = 発生箇所、▶ = プロジェクトのコード）\n\n'
    printf '| # | 場所 | 関数 |\n|---|---|---|\n'
    errnav_frames_of "$id" | awk -F'\t' '{ m = ($5 == 1) ? "▶ " : ""; gsub(/\|/, "\\|", $4); printf "| %s | %s`%s:%s` | %s |\n", $1, m, $2, $3, $4 }'
    echo

    printf '## 呼び出し経路\n\n```text\n'
    errnav_tree "$id" | tail -n +2
    printf '```\n\n'

    printf '## 関連するソース\n\n'
    local shown=0 idx file line fn inproj resolved files=""
    while IFS=$ERRNAV_US read -r idx file line fn inproj resolved; do
      [ "$inproj" = 1 ] || continue
      [ $shown -lt "$maxf" ] || break
      shown=$((shown + 1)); files="$files $file"
      printf '### フレーム %s: `%s:%s`%s\n\n' "$idx" "$file" "$line" "${fn:+（$fn）}"
      printf '```%s\n' "$(_errnav_lang_of "$file")"
      errnav_snippet "$file" "$line" "$ERRNAV_CONTEXT_LINES"
      printf '```\n\n'
    done <<ERRNAV_EOF
$(errnav_frames_of "$id" | errnav_tsv)
ERRNAV_EOF
    [ $shown -eq 0 ] && printf '（プロジェクトの中のフレームが見つかりませんでした。ERRNAV_PATH_MAP でパスの対応を設定すると解決できることがあります）\n\n'

    # 発生箇所の関数を呼んでいる所・定義している所（AI が呼び出し元をたどる手がかり）
    local fname refs
    fname=$(errnav_frames_of "$id" | awk -F'\t' '$5 == 1 && $4 != "" { print $4; exit }' | _errnav_func_name)
    if [ -n "$fname" ]; then
      refs=$(errnav_search_word "$fname" | head -n "${ERRNAV_CONTEXT_REFS:-15}")
      if [ -n "$refs" ]; then
        printf '## `%s` が出てくる箇所（%s で検索。先頭 %s 件）\n\n```text\n%s\n```\n\n' "$fname" "${ERRNAV_RG:-grep}" "${ERRNAV_CONTEXT_REFS:-15}" "$refs"
      fi
    fi

    if [ -n "$files" ] && git -C "$ERRNAV_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
      local changes
      # shellcheck disable=SC2086
      changes=$( (cd "$ERRNAV_ROOT" && git log -n 5 --date=short --format='%h %ad %s' -- $files 2>/dev/null
                  git diff --stat HEAD -- $files 2>/dev/null | sed 's/^/(未コミット) /') )
      if [ -n "$changes" ]; then
        printf '## 関係するファイルの最近の変更\n\n```text\n%s\n```\n\n' "$changes"
      fi
    fi

    printf '## ログ（このエラーの全文。長い場合は先頭 %s 行）\n\n```text\n' "${ERRNAV_CONTEXT_LOG_LINES:-60}"
    head -n "${ERRNAV_CONTEXT_LOG_LINES:-60}" "$ERRNAV_CACHE/raw/$id.txt"
    printf '```\n\n'

    local hint; hint=$(errnav_hook hint)
    if [ -n "$hint" ]; then printf '## フレームワークのメモ\n\n%s\n\n' "$hint"; fi

    printf '## 依頼\n\n'
    printf '上のエラーについて、次の順に答えてください。\n\n'
    printf '1. 原因の仮説（確からしい順。根拠にしたフレーム・ソースの行を示す）\n'
    printf '2. 再現の手順（コマンド。`tools/errnav/bin/errnav repro --expect '"'"'<内容の一部>'"'"' -- <コマンド>` で確かめられる形）\n'
    printf '3. 修正の案（差分）と、その修正で再現しなくなることの確かめ方\n'
    printf '4. 足りない情報があれば、何を見れば決められるか\n'
  } | errnav_redact
}

# クリップボードに写す（macOS / Wayland / X11 / WSL）
errnav_copy() {
  if errnav_have pbcopy; then pbcopy
  elif [ -n "$WAYLAND_DISPLAY" ] && errnav_have wl-copy; then wl-copy
  elif errnav_have xclip; then xclip -selection clipboard
  elif errnav_have xsel; then xsel --clipboard --input
  elif errnav_have clip.exe; then clip.exe
  else cat > /dev/null; errnav_warn "クリップボードのコマンドが見つかりません（-o FILE でファイルに書き出せます）"; return 1
  fi
}
