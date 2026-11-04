# errnav: ログの検出・エラーの抽出・パスの解決・まとめ

# ---- ログの検出 -------------------------------------------------------------------
ERRNAV_GENERIC_LOG_GLOBS='*.log log/*.log logs/*.log tmp/*.log tmp/log/*.log tmp/logs/*.log var/log/*.log var/logs/*.log nohup.out npm-debug.log* yarn-error.log* lerna-debug.log*'
ERRNAV_SEARCH_EXCLUDES='.git node_modules vendor .venv venv .bundle .errnav dist build target .next .nuxt __pycache__'

# 候補のログを、新しい順に ROOT からの相対パスで出す
errnav_detect_logs() {
  (
    cd "$ERRNAV_ROOT" || exit 0
    shopt -s nullglob
    {
      # 1. 設定（ERRNAV_LOGS）・プラグイン・よくある置き場所のグロブ
      local g f
      for g in $ERRNAV_LOGS $(errnav_hook logs) $ERRNAV_GENERIC_LOG_GLOBS; do
        for f in $g; do [ -f "$f" ] && printf '%s\n' "$f"; done
      done
      # 2. 深さ4までの *.log を探す（ログは .gitignore されていることが多いので、無視の設定を使わない）
      if [ -z "$ERRNAV_NO_SEARCH" ]; then
        if [ -n "$ERRNAV_FD" ]; then
          local ex=
          for g in $ERRNAV_SEARCH_EXCLUDES; do ex="$ex -E $g"; done
          # shellcheck disable=SC2086
          "$ERRNAV_FD" -H -I -t f -e log -d 4 $ex . 2>/dev/null | sed 's#^\./##'
        else
          local prune=
          for g in $ERRNAV_SEARCH_EXCLUDES; do prune="$prune -name $g -o"; done
          # shellcheck disable=SC2086
          find . -maxdepth 4 \( ${prune% -o} \) -prune -o -type f -name '*.log' -print 2>/dev/null | sed 's#^\./##'
        fi
      fi
    } | awk 'NF && !seen[$0]++' | while IFS= read -r f; do
      [ -s "$f" ] && printf '%s\n' "$f"
    done | _errnav_sort_by_mtime
  )
}

# 新しい順に並べる（ls -t は Linux と macOS の両方にある）
_errnav_sort_by_mtime() {
  local list=() f
  while IFS= read -r f; do list[${#list[@]}]="$f"; done
  [ ${#list[@]} -eq 0 ] && return 0
  ls -t -- "${list[@]}" 2>/dev/null
}

# ---- 抽出 -------------------------------------------------------------------------
# キャッシュを空にする
errnav_reset_cache() {
  local cache="$ERRNAV_CACHE"
  rm -rf "$cache/raw" "$cache/events.tsv" "$cache/frames.raw.tsv" "$cache/frames.tsv" "$cache/groups.tsv" "$cache/paths.tsv"
  mkdir -p "$cache/raw" || errnav_die "キャッシュを作れません: $cache"
  : > "$cache/events.tsv"; : > "$cache/frames.raw.tsv"
  ERRNAV_ENTRY_RE_ALL=$(errnav_entry_re)
}

# 1つのファイルを解析して、キャッシュに足す
# errnav_parse_one FILE 表示の名前 行番号のずれ
errnav_parse_one() {
  local file="$1" name="$2" lineoff="${3:-0}" cache="$ERRNAV_CACHE" tmp mode id0
  tmp="$cache/.input"
  errnav_preprocess < "$file" > "$tmp"
  # タイムスタンプなどのある行が1つでもあれば「エントリ」で区切る。無ければ字下げで区切る
  if grep -Eq "$ERRNAV_ENTRY_RE_ALL" "$tmp" 2>/dev/null; then mode="$ERRNAV_ENTRY_RE_ALL"; else mode=""; fi
  id0=$(awk 'END { print NR }' "$cache/events.tsv")
  awk -v entry_re="$mode" -v error_re="$ERRNAV_ERROR_RE" -v logname="$name" -v id0="$id0" \
      -v lineoff="$lineoff" -v rawdir="$cache/raw" -v events="$cache/events.tsv" \
      -v frames="$cache/frames.raw.tsv" -v warn="${ERRNAV_WARN:-0}" \
      -f "$ERRNAV_HOME/lib/parse.awk" "$tmp"
  rm -f "$tmp"
}

# 解析の仕上げ: パスを解決し、同じエラーをまとめる
errnav_finish_scan() {
  errnav_resolve_frames
  errnav_group
}

# errnav_scan_files FILE...   （"-" は標準入力）
# ERRNAV_CACHE に events.tsv・frames.tsv・groups.tsv・raw/ を作る
errnav_scan_files() {
  errnav_reset_cache
  local f name total lineoff part="$ERRNAV_CACHE/.part"
  # 古いログから順に読み、新しいイベントほど番号が大きくなるようにする（引数は新しい順）
  local ordered=()
  for f in "$@"; do ordered=("$f" "${ordered[@]}"); done
  for f in "${ordered[@]}"; do
    lineoff=0
    if [ "$f" = - ]; then
      name="(stdin)"; f="$ERRNAV_CACHE/stdin.log"; cat > "$f"
    else
      name="$f"
      case "$f" in /*) ;; *) [ -f "$ERRNAV_ROOT/$f" ] && f="$ERRNAV_ROOT/$f" ;; esac
    fi
    [ -r "$f" ] || { errnav_warn "読めません: $f"; continue; }
    # 大きなログは末尾だけを読む（ERRNAV_TAIL_LINES。0 なら全部）
    total=$(wc -l < "$f" | tr -d ' ')
    if [ "$ERRNAV_TAIL_LINES" -gt 0 ] && [ "$total" -gt "$ERRNAV_TAIL_LINES" ]; then
      tail -n "$ERRNAV_TAIL_LINES" "$f" > "$part"
      lineoff=$((total - ERRNAV_TAIL_LINES))
      errnav_parse_one "$part" "$name" "$lineoff"
      rm -f "$part"
    else
      errnav_parse_one "$f" "$name" 0
    fi
  done
  errnav_finish_scan
}

# ---- パスの解決 ---------------------------------------------------------------------
# ログに書かれたパス（コンテナの中のパス・別のマシンのパス）を、手元のファイルに結び付ける
# 出力: 解決したパス（ROOT からの相対。外なら絶対）。見つからなければ空
errnav_resolve_path() {
  local raw="$1" p map from to
  case "$raw" in node:*|internal/*|\<*|\[*) return 0 ;; esac   # 実行環境の内部（ファイルは無い）
  p="$raw"
  # 1. 設定とプラグインのパスの対応（from=to）
  while IFS= read -r map; do
    [ -n "$map" ] || continue
    from="${map%%=*}"; to="${map#*=}"
    case "$p" in "$from"/*|"$from") p="$to${p#"$from"}"; break ;; esac
  done <<ERRNAV_EOF
$ERRNAV_PATH_MAPS
ERRNAV_EOF
  # 2. そのままある
  case "$p" in
    /*) if [ -f "$p" ]; then _errnav_rel "$p"; return; fi ;;
    *)  if [ -f "$ERRNAV_ROOT/$p" ]; then printf '%s\n' "${p#./}"; return; fi ;;
  esac
  # 3. ソースの置き場所の下にあるか（Java の com/example/Foo.java → src/main/java/com/example/Foo.java）
  local r
  for r in $ERRNAV_SRC_ROOTS_ALL; do
    if [ -f "$ERRNAV_ROOT/$r/${p#/}" ]; then printf '%s\n' "$r/${p#/}"; return; fi
  done
  # 4. 前から1段ずつ削って、ROOT の下にあるか（/var/www/html/app/Foo.php → app/Foo.php）
  local q="${p#/}" n=0
  while [ "${q#*/}" != "$q" ] && [ $n -lt 12 ]; do
    q="${q#*/}"; n=$((n + 1))
    if [ -f "$ERRNAV_ROOT/$q" ]; then printf '%s\n' "$q"; return; fi
  done
  # 5. ディレクトリ付きの末尾で探す（Java の com/example/Foo.java など）。1件に決まるときだけ
  case "$raw" in
    */*) _errnav_find_suffix "${p#/}" ;;
  esac
}

_errnav_rel() {
  case "$1" in
    "$ERRNAV_ROOT"/*) printf '%s\n' "${1#"$ERRNAV_ROOT"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

_errnav_find_suffix() {
  local suffix="$1" base hits
  base=$(basename "$suffix")
  if [ -n "$ERRNAV_FD" ]; then
    hits=$(cd "$ERRNAV_ROOT" && "$ERRNAV_FD" -H -I -t f -F -x "$base" -E .git -E node_modules -E .errnav . 2>/dev/null)
  else
    hits=$(cd "$ERRNAV_ROOT" && find . \( -name .git -o -name node_modules -o -name .errnav \) -prune -o -type f -name "$base" -print 2>/dev/null)
  fi
  # 末尾が「/<suffix>」と一致するものだけを残し、1件に決まるときだけ返す
  hits=$(printf '%s\n' "$hits" | sed 's#^\./##' | awk -v s="/$suffix" 'NF { p = "/" $0; if (length(p) >= length(s) && substr(p, length(p) - length(s) + 1) == s) print $0 }')
  if [ -n "$hits" ] && [ "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')" = 1 ]; then printf '%s\n' "$hits"; fi
}

errnav_resolve_frames() {
  local cache="$ERRNAV_CACHE" raw res inproj
  # パスの対応を1回だけ集める（設定の ERRNAV_PATH_MAP は空白区切り、プラグインは1行ずつ）
  ERRNAV_PATH_MAPS=$( { printf '%s\n' $ERRNAV_PATH_MAP; errnav_hook path_map; } | awk 'NF')
  ERRNAV_SRC_ROOTS_ALL="$ERRNAV_SRC_ROOTS $(errnav_hook src_roots | tr '\n' ' ')"
  : > "$cache/paths.tsv"
  cut -f3 "$cache/frames.raw.tsv" | awk 'NF && !seen[$0]++' | while IFS= read -r raw; do
    res=$(errnav_resolve_path "$raw")
    inproj=0
    if [ -n "$res" ]; then
      case "$res" in /*) ;; *) printf '%s\n' "$res" | grep -Eq "$ERRNAV_VENDOR_RE" || inproj=1 ;; esac
    fi
    printf '%s\t%s\t%s\n' "$raw" "$res" "$inproj"
  done > "$cache/paths.tsv"
  # frames.tsv: id idx raw line func resolved inproj
  awk -F'\t' -v OFS='\t' 'NR == FNR { res[$1] = $2; inp[$1] = $3; next } { print $1, $2, $3, $4, $5, res[$3], (inp[$3] == "" ? 0 : inp[$3]) }' \
    "$cache/paths.tsv" "$cache/frames.raw.tsv" > "$cache/frames.tsv"
}

# ---- まとめ（同じエラーを1行にする） ---------------------------------------------------------
# groups.tsv: latest_id  count  level  time  summary  location  log  first_id
errnav_group() {
  local cache="$ERRNAV_CACHE"
  awk -F'\t' -v OFS='\t' '
    FILENAME == ARGV[1] {
      # 各イベントの代表のフレーム: プロジェクトの中の最初 → 解決できた最初 → 最初
      id = $1
      if ($7 == 1 && !(id in tp)) tp[id] = $6 ":" $4
      if ($6 != "" && !(id in tr)) tr[id] = $6 ":" $4
      if (!(id in tf)) tf[id] = $3 ":" $4
      next
    }
    {
      id = $1
      loc = (id in tp) ? tp[id] : ((id in tr) ? tr[id] : ((id in tf) ? tf[id] : ""))
      sig = $6; gsub(/0x[0-9a-fA-F]+/, "X", sig); gsub(/[0-9]+/, "N", sig); sig = sig "|" loc
      if (!(sig in cnt)) { order[++n] = sig; first[sig] = id }
      cnt[sig]++; last[sig] = id; lv[sig] = $5; tm[sig] = $4; sm[sig] = $6; lc[sig] = loc; lg[sig] = $2
    }
    END { for (i = 1; i <= n; i++) { s = order[i]; print last[s], cnt[s], lv[s], tm[s], sm[s], lc[s], lg[s], first[s] } }
  ' "$cache/frames.tsv" "$cache/events.tsv" | sort -t "$(printf '\t')" -k1,1nr > "$cache/groups.tsv"
}

errnav_cache_ready() { [ -s "$ERRNAV_CACHE/events.tsv" ] && [ -f "$ERRNAV_CACHE/frames.tsv" ]; }

# キャッシュが無ければ、検出したログを読む
errnav_ensure_scanned() {
  errnav_cache_ready && return 0
  local logs=() f
  while IFS= read -r f; do logs[${#logs[@]}]="$f"; done <<ERRNAV_EOF
$(errnav_detect_logs)
ERRNAV_EOF
  [ -n "${logs[0]}" ] || errnav_die "ログが見つかりません。errnav scan <ログ> か、.errnav/config の ERRNAV_LOGS で指定してください"
  errnav_scan_files "${logs[@]}"
  errnav_cache_ready || errnav_die "エラーは見つかりませんでした"
}
