# errnav: 表示（一覧・詳細・呼び出し経路・ソース）とエディタで開く

# ---- キャッシュの読み出し ---------------------------------------------------------------
# イベントの1行を「列=値」の変数にする: EV_ID EV_LOG EV_LINE EV_TIME EV_LEVEL EV_SUMMARY EV_HEADER EV_ROOT
errnav_load_event() {
  local id="$1" line
  line=$(awk -F'\t' -v id="$id" '$1 == id { print; exit }' "$ERRNAV_CACHE/events.tsv")
  [ -n "$line" ] || errnav_die "イベント $id がありません（errnav scan で一覧を作り直す）"
  IFS=$ERRNAV_US read -r EV_ID EV_LOG EV_LINE EV_TIME EV_LEVEL EV_SUMMARY EV_HEADER EV_ROOT <<ERRNAV_EOF
$(printf '%s\n' "$line" | errnav_tsv)
ERRNAV_EOF
}

# フレーム: idx  file（解決済み or 元のまま）  line  func  inproj  resolved(1/0)
errnav_frames_of() {
  awk -F'\t' -v OFS='\t' -v id="$1" '$1 == id { f = ($6 != "" ? $6 : $3); print $2, f, $4, $5, $7, ($6 != "" ? 1 : 0) }' "$ERRNAV_CACHE/frames.tsv"
}

# 代表のフレーム（プロジェクトの中の最初 → 解決できた最初）: "file<TAB>line"
errnav_top_frame() {
  errnav_frames_of "$1" | awk -F'\t' -v OFS='\t' '$5 == 1 { print $2, $3; found = 1; exit } $6 == 1 && r == "" { r = $2 "\t" $3 } END { if (!found && r != "") print r }'
}

# 「最新」「1」などの指定を番号にする
errnav_resolve_id() {
  local id="$1"
  case "$id" in
    ""|latest|last) id=$(awk -F'\t' 'NR == 1 { print $1 }' "$ERRNAV_CACHE/groups.tsv") ;;
  esac
  case "$id" in *[!0-9]*|"") errnav_die "番号を指定してください: $1" ;; esac
  printf '%s\n' "$id"
}

# ---- 場所の表示（端末で押せるリンク） ------------------------------------------------------
# ERRNAV_LINK=phpstorm|idea|vscode|file で OSC 8 のハイパーリンクにする（既定は file:line の文字だけ。多くの端末で押せる）
errnav_loc() {
  local file="$1" line="$2" text="$1:$2" abs url
  if [ -n "$ERRNAV_LINK" ] && [ -n "$ERRNAV_COLOR_ON" ]; then
    case "$file" in /*) abs="$file" ;; *) abs="$ERRNAV_ROOT/$file" ;; esac
    case "$ERRNAV_LINK" in
      phpstorm) url="phpstorm://open?file=$abs&line=$line" ;;
      idea)     url="idea://open?file=$abs&line=$line" ;;
      vscode)   url="vscode://file$abs:$line" ;;
      cursor)   url="cursor://file$abs:$line" ;;
      *)        url="file://$abs" ;;
    esac
    printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$url" "$text"
  else
    printf '%s' "$text"
  fi
}

# ---- ソースの抜粋 -----------------------------------------------------------------------
# errnav_snippet FILE LINE [前後の行数]
errnav_snippet() {
  local file="$1" line="$2" ctx="${3:-$ERRNAV_CONTEXT_LINES}" path from to
  case "$file" in /*) path="$file" ;; *) path="$ERRNAV_ROOT/$file" ;; esac
  [ -f "$path" ] || { printf '%s(ファイルが手元にありません: %s)%s\n' "$C_DIM" "$file" "$C_RESET"; return 0; }
  from=$((line - ctx)); [ $from -lt 1 ] && from=1
  to=$((line + ctx))
  if [ -n "$ERRNAV_BAT" ] && [ -z "$ERRNAV_PLAIN" ]; then
    local color=never; [ -n "$ERRNAV_COLOR_ON" ] && color=always
    "$ERRNAV_BAT" --style=numbers --color="$color" --paging=never --highlight-line "$line" --line-range "$from:$to" -- "$path" 2>/dev/null && return 0
  fi
  awk -v from="$from" -v to="$to" -v hl="$line" -v on="$C_RED$C_BOLD" -v off="$C_RESET" '
    NR >= from && NR <= to { if (NR == hl) printf "%s>%5d | %s%s\n", on, NR, $0, off; else printf " %5d | %s\n", NR, $0 }
    NR > to { exit }' "$path"
}

# ---- 一覧 ---------------------------------------------------------------------------
# errnav_print_groups [件数]
errnav_print_groups() {
  local limit="${1:-20}" total
  total=$(awk 'END { print NR }' "$ERRNAV_CACHE/groups.tsv")
  if [ "$total" -eq 0 ]; then echo "エラーは見つかりませんでした"; return 0; fi
  printf '%s%4s %5s  %-8s %-19s  %s%s\n' "$C_BOLD" ID 件数 LEVEL TIME "MESSAGE  →  発生箇所" "$C_RESET"
  head -n "$limit" "$ERRNAV_CACHE/groups.tsv" | errnav_tsv | while IFS=$ERRNAV_US read -r id cnt lv tm sum loc lg first; do
    [ -n "$loc" ] || loc="(場所が不明: $lg)"
    printf '%4s %5s  %s%-8s%s %-19s  %s\n' "$id" "×$cnt" "$C_RED" "$lv" "$C_RESET" "${tm:--}" "$(printf '%s' "$sum" | cut -c1-100)"
    printf '%31s%s→ %s%s\n' "" "$C_CYAN" "$loc" "$C_RESET"
  done
  [ "$total" -gt "$limit" ] && printf '%s… ほか %d 種類（--limit で増やす）%s\n' "$C_DIM" $((total - limit)) "$C_RESET"
  return 0
}

# fzf に渡す1行の形: id<TAB>表示
errnav_groups_for_fzf() {
  awk -F'\t' -v OFS='\t' '{ loc = ($6 == "" ? "?" : $6); printf "%s\t%-4s ×%-3s %-8s %s  →  %s\n", $1, $1, $2, $3, substr($5, 1, 90), loc }' "$ERRNAV_CACHE/groups.tsv"
}

# ---- 詳細 ---------------------------------------------------------------------------
errnav_show() {
  local id; id=$(errnav_resolve_id "$1")
  errnav_load_event "$id"
  printf '%s#%s %s%s %s%s\n' "$C_BOLD" "$EV_ID" "$C_RED" "$EV_LEVEL" "$EV_SUMMARY" "$C_RESET"
  [ -n "$EV_ROOT" ] && printf '%s根本原因: %s%s\n' "$C_YELLOW" "$EV_ROOT" "$C_RESET"
  printf '%sログ: %s:%s  %s%s\n' "$C_DIM" "$EV_LOG" "$EV_LINE" "$EV_TIME" "$C_RESET"
  echo
  printf '%sスタックトレース（0 = 発生箇所）%s\n' "$C_BOLD" "$C_RESET"
  local frames; frames=$(errnav_frames_of "$id")
  if [ -z "$frames" ]; then
    printf '   %s(スタックトレースが見つかりません)%s\n' "$C_DIM" "$C_RESET"
  else
    while IFS=$ERRNAV_US read -r idx file line fn inproj resolved; do
      if [ "$inproj" = 1 ]; then
        printf ' %s%s %2s%s  %s  %s\n' "$C_GREEN" "$G_MARK" "$idx" "$C_RESET" "$(errnav_loc "$file" "$line")" "$fn"
      elif [ "$resolved" = 1 ]; then
        printf '   %s%2s  %s  %s%s\n' "$C_DIM" "$idx" "$file:$line" "$fn" "$C_RESET"
      else
        printf '   %s%2s  %s  %s  (手元に無い)%s\n' "$C_DIM" "$idx" "$file:$line" "$fn" "$C_RESET"
      fi
    done <<ERRNAV_EOF
$(printf '%s\n' "$frames" | errnav_tsv)
ERRNAV_EOF
  fi

  local top tf tl
  top=$(errnav_top_frame "$id")
  if [ -n "$top" ]; then
    tf="${top%%$'\t'*}"; tl="${top#*$'\t'}"
    echo
    printf '%s発生箇所: %s%s\n' "$C_BOLD" "$(errnav_loc "$tf" "$tl")" "$C_RESET"
    errnav_snippet "$tf" "$tl"
  fi
  echo
  printf '%s次: errnav open %s / errnav tree %s / errnav context %s%s\n' "$C_DIM" "$id" "$id" "$id" "$C_RESET"
}

# ---- 呼び出し経路 -----------------------------------------------------------------------
# 外側（入口）から内側（発生箇所）へ木の形で出す。プロジェクトの外のフレームが続くところは畳む（--all で全部）
errnav_tree() {
  local id; id=$(errnav_resolve_id "$1"); local all="$2"
  errnav_load_event "$id"
  printf '%s#%s %s%s\n' "$C_BOLD" "$id" "$EV_SUMMARY" "$C_RESET"
  errnav_frames_of "$id" | sort -t "$(printf '\t')" -k1,1nr | awk -F'\t' \
    -v all="$all" -v br="$G_BRANCH" -v dots="$G_DOTS" -v here="$G_HERE" \
    -v g="$C_GREEN" -v d="$C_DIM" -v r="$C_RED" -v b="$C_BOLD" -v z="$C_RESET" '
    function indent(k,   s, i) { s = ""; for (i = 0; i < k; i++) s = s "   "; return s }
    function out(i,   pre, loc) {
      pre = (depth == 0) ? "" : indent(depth - 1) br
      loc = F[i] ":" L[i]
      if (P[i] == 1) printf "%s%s%s%s  %s", pre, g, loc, z, U[i]
      else printf "%s%s%s  %s%s", pre, d, loc, U[i], z
      if (I[i] == 0) printf "  %s%s%s", r b, here, z
      printf "\n"; depth++
    }
    { n++; I[n] = $1; F[n] = $2; L[n] = $3; U[n] = $4; P[n] = $5 }
    END {
      if (n == 0) { print "  (スタックトレースが見つかりません)"; exit }
      depth = 0; i = 1
      while (i <= n) {
        if (all != "" || P[i] == 1 || I[i] == 0 || i == 1) { out(i); i++; continue }
        j = i; while (j <= n && P[j] != 1 && I[j] != 0) j++
        if (j - i <= 2) { for (k = i; k < j; k++) out(k); i = j; continue }
        pre = (depth == 0) ? "" : indent(depth - 1) br
        printf "%s%s%s %d 件（プロジェクトの外）%s\n", pre, d, dots, j - i, z; depth++
        i = j
      }
    }'
}

# ---- エディタで開く ---------------------------------------------------------------------
# errnav_open_editor FILE LINE
errnav_open_editor() {
  local file="$1" line="$2" path cmd ed base
  case "$file" in /*) path="$file" ;; *) path="$ERRNAV_ROOT/$file" ;; esac
  printf '%s\n' "$path:$line" >&2
  [ -f "$path" ] || errnav_die "ファイルが手元にありません: $file"
  # ERRNAV_OPEN_CMD='code -g {file}:{line}' のように、自由な形で指定できる
  if [ -n "$ERRNAV_OPEN_CMD" ]; then
    cmd="$ERRNAV_OPEN_CMD"
    cmd="${cmd//\{file\}/$(printf '%q' "$path")}"
    cmd="${cmd//\{line\}/$line}"
    eval "$cmd"; return
  fi
  ed="${ERRNAV_EDITOR:-${VISUAL:-${EDITOR:-}}}"
  if [ -z "$ed" ]; then
    for base in nvim vim vi nano; do errnav_have "$base" && { ed="$base"; break; }; done
  fi
  [ -n "$ed" ] || errnav_die "エディタが決まっていません（EDITOR か ERRNAV_EDITOR を設定する）"
  # shellcheck disable=SC2086
  set -- $ed
  base=$(basename "$1")
  case "$base" in
    code|code-insiders|codium|cursor|windsurf) "$@" -g "$path:$line" ;;
    phpstorm*|pstorm|idea*|webstorm*|pycharm*|goland*|rubymine*|clion*|rider*|phpstorm.sh|idea.sh) "$@" --line "$line" "$path" ;;
    subl|sublime_text|micro|hx|helix|zed|kate) "$@" "$path:$line" ;;
    *) "$@" "+$line" "$path" ;;   # vim / nvim / vi / nano / emacs / kak など
  esac
}

# errnav_open ID [フレームの番号]
errnav_open() {
  local id; id=$(errnav_resolve_id "$1"); local idx="$2" sel file line pick=1
  # "top" は選ばずに発生箇所（プロジェクトの中の最初のフレーム）を開く
  [ "$idx" = top ] && { idx=; pick=; }
  if [ -z "$idx" ] && [ -n "$pick" ] && [ -n "$ERRNAV_FZF" ] && [ -t 0 ] && [ -t 1 ]; then
    # フレームを選ぶ（プロジェクトの中を先に）。プレビューは発生箇所のまわりのソース
    sel=$(errnav_frames_of "$id" | awk -F'\t' -v OFS='\t' '$6 == 1 { print ($5 == 1 ? 0 : 1), $1, $2, $3, $4 }' | sort -t "$(printf '\t')" -k1,1n -k2,2n | cut -f2- |
      awk -F'\t' '{ printf "%s\t%s:%s\t%s\n", $1, $2, $3, $4 }' |
      "$ERRNAV_FZF" --ansi --delimiter='\t' --with-nth=2,3 --prompt="#$id 開く> " \
        --preview "ERRNAV_COLOR=always $(printf '%q' "$ERRNAV_SELF") snippet {2}" --preview-window=right,60%) || return 0
    idx="${sel%%$'\t'*}"
  fi
  if [ -z "$idx" ]; then
    sel=$(errnav_top_frame "$id")
  else
    sel=$(errnav_frames_of "$id" | awk -F'\t' -v OFS='\t' -v i="$idx" '$1 == i { print $2, $3; exit }')
  fi
  [ -n "$sel" ] || errnav_die "開ける場所がありません（#$id のフレーム $idx）"
  file="${sel%%$'\t'*}"; line="${sel#*$'\t'}"
  if [ -t 1 ] || [ -n "$ERRNAV_FORCE_OPEN" ]; then errnav_open_editor "$file" "$line"
  else printf '%s:%s\n' "$file" "$line"; fi   # 端末でないときは場所だけ出す（ほかのコマンドにつなぐため）
}
