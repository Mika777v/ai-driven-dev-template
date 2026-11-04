# errnav: 共通の部品（設定・色・外部コマンド・プラグイン）
#
# bash 3.2（macOS の標準）でも動くように書く:
#   連想配列・mapfile・${var,,}・set -u（空の配列で落ちる）は使わない

ERRNAV_VERSION="0.1.0"

# TSV を bash の read で読むときの区切り。タブは「空白」なので、空の欄が詰められて列がずれる。
# 空白でない区切り（ASCII の Unit Separator）に置き換えてから読む
ERRNAV_US=$'\037'
errnav_tsv() { tr '\t' '\037'; }

# ---- 出力 -------------------------------------------------------------------
errnav_die()  { printf 'errnav: %s\n' "$*" >&2; exit 2; }
errnav_warn() { printf 'errnav: %s\n' "$*" >&2; }
errnav_info() { [ -n "$ERRNAV_QUIET" ] || printf '%s\n' "$*" >&2; }

errnav_setup_color() {
  # ERRNAV_COLOR=always|never|auto（既定 auto。NO_COLOR があれば色を付けない）
  local mode="${ERRNAV_COLOR:-auto}"
  if [ "$mode" = always ] || { [ "$mode" = auto ] && [ -t 1 ] && [ -z "$NO_COLOR" ]; }; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
    ERRNAV_COLOR_ON=1
  else
    C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=
    ERRNAV_COLOR_ON=
  fi
}

errnav_setup_glyphs() {
  case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in
    *UTF-8*|*utf8*|*UTF8*|*utf-8*) [ -z "$ERRNAV_ASCII" ] && { G_BRANCH='└─ '; G_MARK='▶'; G_HERE='◀ 発生箇所'; G_DOTS='…'; return; } ;;
  esac
  G_BRANCH='`- '; G_MARK='>'; G_HERE='<- here'; G_DOTS='...'
}

# ---- 環境 -------------------------------------------------------------------
errnav_have() { command -v "$1" >/dev/null 2>&1; }

errnav_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo mac ;;
    Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi ;;
    MINGW*|MSYS*|CYGWIN*) echo windows-bash ;;
    *) echo unknown ;;
  esac
}

errnav_setup_tools() {
  # Debian / Ubuntu では fd は fdfind、bat は batcat という名前で入る
  ERRNAV_FD=; ERRNAV_BAT=; ERRNAV_RG=; ERRNAV_FZF=
  if errnav_have fd; then ERRNAV_FD=fd; elif errnav_have fdfind; then ERRNAV_FD=fdfind; fi
  if errnav_have bat; then ERRNAV_BAT=bat; elif errnav_have batcat; then ERRNAV_BAT=batcat; fi
  errnav_have rg && ERRNAV_RG=rg
  errnav_have fzf && ERRNAV_FZF=fzf
  [ -n "$ERRNAV_NO_FZF" ] && ERRNAV_FZF=
  [ -n "$ERRNAV_NO_BAT" ] && ERRNAV_BAT=
  [ -n "$ERRNAV_NO_RG" ] && ERRNAV_RG=
  return 0
}

# 絶対パスにする（realpath / readlink -f が無い環境向け）
errnav_abspath() {
  local p="$1"
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  if [ -d "$p" ]; then (cd "$p" 2>/dev/null && pwd -P); return; fi
  local d; d=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) || { printf '%s\n' "$p"; return; }
  printf '%s/%s\n' "$d" "$(basename "$p")"
}

# ファイルの大きさ（バイト）。macOS の wc は前に空白を付けるので数に直す
errnav_size() { local n; n=$(wc -c < "$1" 2>/dev/null) || n=0; echo $((n + 0)); }

# ---- プロジェクトと設定 ---------------------------------------------------------
errnav_setup_project() {
  if [ -n "$ERRNAV_ROOT" ]; then
    ERRNAV_ROOT=$(errnav_abspath "$ERRNAV_ROOT")
  else
    ERRNAV_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ERRNAV_ROOT=$(pwd -P)
  fi
  ERRNAV_CONF_DIR="$ERRNAV_ROOT/.errnav"
  # 設定ファイルはシェルとして読み込む（.envrc と同じく、信頼できるリポジトリでだけ使う）
  if [ -f "$ERRNAV_CONF_DIR/config" ]; then
    # shellcheck disable=SC1091
    . "$ERRNAV_CONF_DIR/config"
  fi
  ERRNAV_CACHE="${ERRNAV_CACHE_DIR:-$ERRNAV_CONF_DIR/cache}"
  ERRNAV_TAIL_LINES="${ERRNAV_TAIL_LINES:-5000}"
  ERRNAV_CONTEXT_LINES="${ERRNAV_CONTEXT_LINES:-6}"
  # プロジェクトの外とみなすパス（依存ライブラリ・生成物）
  ERRNAV_VENDOR_RE="${ERRNAV_VENDOR_RE:-(^|/)(vendor|node_modules|\.venv|venv|site-packages|dist-packages|bower_components|\.bundle|gems|target|build|dist|\.next|\.nuxt)/}"
  ERRNAV_ENTRY_RE_DEFAULT='^(\[?[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ T][0-9][0-9]:[0-9][0-9]|[A-Z], \[[0-9][0-9][0-9][0-9]-|\[(Mon|Tue|Wed|Thu|Fri|Sat|Sun) |(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 0-9][0-9] [0-9][0-9]:|[0-9][0-9]/[A-Z][a-z][a-z]/[0-9][0-9][0-9][0-9]|\{"|(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|CRITICAL|FATAL|SEVERE)[]: [|]|PHP (Fatal|Warning|Notice|Parse|Deprecated))'
  ERRNAV_ERROR_RE="${ERRNAV_ERROR_RE:-(ERROR|CRITICAL|FATAL|ALERT|EMERGENCY|SEVERE|PANIC|panic: |Exception|Traceback|Uncaught|Fatal error|Error:|Error\)|ERR!)}"
}

# ---- プラグイン -------------------------------------------------------------------
# プラグインは plugins/<名前>.sh。次の関数を定義できる（detect 以外は任意）:
#   errnav_<名前>_detect ROOT     このプロジェクトに当てはまるなら 0 を返す
#   errnav_<名前>_logs            ログの候補（ROOT からの相対のグロブ）を1行ずつ出す
#   errnav_<名前>_entry_re        エントリの始まりの行の正規表現（ERE）を出す
#   errnav_<名前>_path_map        「ログのパスの前置き=手元のパス」を1行ずつ出す（例: /var/www/html=.）
#   errnav_<名前>_src_roots       ソースの置き場所（ROOT からの相対）を1行ずつ出す（例: src/main/java）
#   errnav_<名前>_preprocess      ログを標準入力から読み、解析の前に整えて標準出力に出す
#   errnav_<名前>_hint            AI 解析用のコンテキストに足す、フレームワーク固有のメモを出す
ERRNAV_ALL_PLUGINS=
errnav_register() { ERRNAV_ALL_PLUGINS="$ERRNAV_ALL_PLUGINS $1"; }

errnav_load_plugins() {
  local f
  for f in "$ERRNAV_HOME"/plugins/*.sh "$ERRNAV_CONF_DIR"/plugins/*.sh; do
    [ -f "$f" ] || continue
    # shellcheck disable=SC1090
    . "$f"
  done
  ERRNAV_ACTIVE=
  local p
  if [ -n "$ERRNAV_PLUGINS" ]; then
    # 設定で決めたものだけを使う（例: ERRNAV_PLUGINS="php node"）
    for p in $ERRNAV_PLUGINS; do
      case " $ERRNAV_ALL_PLUGINS " in *" $p "*) ERRNAV_ACTIVE="$ERRNAV_ACTIVE $p" ;; *) errnav_warn "プラグイン $p がありません" ;; esac
    done
  else
    for p in $ERRNAV_ALL_PLUGINS; do
      if errnav_plugin_has "$p" detect && "errnav_${p}_detect" "$ERRNAV_ROOT"; then ERRNAV_ACTIVE="$ERRNAV_ACTIVE $p"; fi
    done
  fi
}

errnav_plugin_has() { declare -F "errnav_$1_$2" >/dev/null 2>&1; }

# 有効なプラグインの全部で、ある関数を呼び、出力をつなげる
errnav_hook() {
  local h="$1" p; shift
  for p in $ERRNAV_ACTIVE; do
    errnav_plugin_has "$p" "$h" && "errnav_${p}_${h}" "$@"
  done
  return 0
}

# プラグインの前処理を順につなげる（無ければそのまま流す）
errnav_preprocess() {
  local p chain=
  for p in $ERRNAV_ACTIVE; do errnav_plugin_has "$p" preprocess && chain="$chain $p"; done
  if [ -z "$chain" ]; then cat; return; fi
  set -- $chain
  _errnav_pre_chain "$@"
}
_errnav_pre_chain() {
  local p="$1"; shift
  if [ $# -eq 0 ]; then "errnav_${p}_preprocess"; else "errnav_${p}_preprocess" | _errnav_pre_chain "$@"; fi
}

# エントリの始まりの正規表現: 既定 + プラグインの分 + 設定（ERRNAV_ENTRY_RE）
errnav_entry_re() {
  local re="$ERRNAV_ENTRY_RE_DEFAULT" extra
  while IFS= read -r extra; do
    [ -n "$extra" ] && re="$re|$extra"
  done <<ERRNAV_EOF
$(errnav_hook entry_re)
ERRNAV_EOF
  [ -n "$ERRNAV_ENTRY_RE" ] && re="$re|$ERRNAV_ENTRY_RE"
  printf '%s\n' "$re"
}

errnav_init() {
  errnav_setup_color
  errnav_setup_glyphs
  errnav_setup_tools
  errnav_setup_project
  errnav_load_plugins
}
