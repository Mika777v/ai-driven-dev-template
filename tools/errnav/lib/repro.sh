# errnav: 再現の確認
#
# コマンドを動かす前のログの大きさを覚えておき、動かした後に「増えた分」とコマンドの出力だけを解析する。
# 古いエラーと混ざらないので、「直したつもりのエラーがまだ出るか」をすぐに確かめられる。
#
# 終了コード: 0 = 再現した / 1 = 再現しなかった / 2 = 使い方の誤り
# （git bisect run に渡すときは --bisect を付ける。再現した = bad(1)、しなかった = good(0) に入れ替える）

errnav_repro() {
  local expect="" bisect="" logs_opt=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --expect) expect="$2"; shift 2 ;;
      --expect=*) expect="${1#*=}"; shift ;;
      --bisect) bisect=1; shift ;;
      --log) logs_opt[${#logs_opt[@]}]="$2"; shift 2 ;;
      --) shift; break ;;
      -*) errnav_die "repro の知らないオプション: $1" ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || errnav_die "使い方: errnav repro [--expect 正規表現] [--log ファイル] -- コマンド..."

  local work="$ERRNAV_CACHE/repro"
  rm -rf "$work"; mkdir -p "$work"

  # 1. いまのログの大きさを覚える
  local logs=() f
  if [ ${#logs_opt[@]} -gt 0 ]; then logs=("${logs_opt[@]}")
  else while IFS= read -r f; do [ -n "$f" ] && logs[${#logs[@]}]="$f"; done <<ERRNAV_EOF
$(errnav_detect_logs)
ERRNAV_EOF
  fi
  local i=0 path
  : > "$work/sizes"
  for f in "${logs[@]}"; do
    case "$f" in /*) path="$f" ;; *) path="$ERRNAV_ROOT/$f" ;; esac
    printf '%s\t%s\n' "$f" "$(errnav_size "$path")" >> "$work/sizes"
  done

  # 2. コマンドを動かす（出力は画面にも出し、ファイルにも残す）
  errnav_info "$C_DIM==> $*$C_RESET"
  local start end status
  start=$(date +%s)
  "$@" 2>&1 | tee "$work/output.log"
  status=${PIPESTATUS[0]}
  end=$(date +%s)

  # 3. 増えた分を切り出す（小さくなっていたらログが回されたとみなして全部を読む）
  local inputs=() before after name lineoff
  while IFS=$'\t' read -r f before; do
    [ -n "$f" ] || continue
    case "$f" in /*) path="$f" ;; *) path="$ERRNAV_ROOT/$f" ;; esac
    [ -f "$path" ] || continue
    after=$(errnav_size "$path")
    [ "$after" -eq "$before" ] && continue
    name=$(printf '%s' "$f" | tr '/' '_')
    if [ "$after" -gt "$before" ]; then
      tail -c +"$((before + 1))" "$path" > "$work/$name"
      lineoff=$(head -c "$before" "$path" | wc -l | tr -d ' ')
    else
      cp "$path" "$work/$name"; lineoff=0
    fi
    printf '%s\t%s\t%s\n' "$work/$name" "$f" "$lineoff" >> "$work/new"
    inputs[${#inputs[@]}]="$work/$name"
  done < "$work/sizes"

  # 4. 増えた分とコマンドの出力を解析する（結果は通常のキャッシュに入れ、show / context でそのまま見られる）
  errnav_repro_scan "$work"

  local reproduced=0 nerr
  nerr=$(awk 'END { print NR }' "$ERRNAV_CACHE/events.tsv")
  if [ -n "$expect" ]; then
    if cat "$work/output.log" "${inputs[@]}" 2>/dev/null | grep -Eq -- "$expect"; then reproduced=1; fi
  else
    [ "$nerr" -gt 0 ] && reproduced=1
  fi

  echo >&2
  printf '%s==> 終了コード %s、%s 秒、新しいエラー %s 件%s\n' "$C_BOLD" "$status" "$((end - start))" "$nerr" "$C_RESET" >&2
  [ "$nerr" -gt 0 ] && errnav_print_groups 10 >&2
  if [ $reproduced = 1 ]; then
    printf '%s再現しました%s%s\n' "$C_RED$C_BOLD" "${expect:+（/$expect/ に一致）}" "$C_RESET" >&2
    [ "$nerr" -gt 0 ] && printf '%s次: errnav show latest / errnav context latest%s\n' "$C_DIM" "$C_RESET" >&2
    [ -n "$bisect" ] && return 1
    return 0
  fi
  printf '%s再現しませんでした%s%s\n' "$C_GREEN$C_BOLD" "${expect:+（/$expect/ に一致する行なし）}" "$C_RESET" >&2
  [ -n "$bisect" ] && return 0
  return 1
}

# 増えた分を、元のログの名前と行番号のまま解析する
errnav_repro_scan() {
  local work="$1" file name lineoff
  errnav_reset_cache
  while IFS=$'\t' read -r file name lineoff; do
    [ -s "$file" ] && errnav_parse_one "$file" "$name" "$lineoff"
  done <<ERRNAV_EOF
$( [ -f "$work/new" ] && cat "$work/new"; printf '%s\t%s\t0\n' "$work/output.log" "(コマンドの出力)")
ERRNAV_EOF
  errnav_finish_scan
}
