#!/usr/bin/env bash
# errnav のベンチマーク: 同じ不具合を「errnav なし」と「errnav あり」で AI（Claude Code）に調べさせ、
# ツールの呼び出しの回数・トークン・時間・正解したかを比べる。
#
# 使い方:
#   bash tools/errnav/bench/run.sh prepare      # 対象のリポジトリを取得し、依存を入れる（1回だけ）
#   bash tools/errnav/bench/run.sh dry          # AI を動かさずに、各シナリオでテストが落ちることと errnav の結果を確かめる
#   bash tools/errnav/bench/run.sh run          # AI を動かして測る（料金がかかる）
#   bash tools/errnav/bench/run.sh report       # 結果の表を出す
#
# 主な設定（環境変数）:
#   BENCH_OUT          作業と結果の置き場所（既定: ${TMPDIR:-/tmp}/errnav-bench）
#   BENCH_REPO         対象のリポジトリ（既定: https://github.com/Mika777v/routepense）
#   BENCH_BASE         不具合を入れる前のブランチ（既定: main）
#   BENCH_BUGS         不具合のコミットがあるブランチ（既定: bench/errnav-bugs）
#   BENCH_RUNS         1つのシナリオ・条件で何回動かすか（既定: 3）
#   BENCH_ONLY         動かすシナリオを絞る（例: "B1 B3"）
#   BENCH_CONDITIONS   動かす条件（既定: "without with"）
#   BENCH_MODEL        使うモデル（既定: Claude Code の既定。比べるときは固定する）
#   BENCH_MAX_BUDGET   1回あたりの上限（ドル。既定: 2）
#   BENCH_TIMEOUT      1回あたりの上限（秒。既定: 900。timeout コマンドがあるときだけ）
#   BENCH_INSTALL      依存を入れるコマンド（既定: npm ci --no-audit --no-fund）
#
# 必要なもの: git・claude（Claude Code の CLI。ログイン済み）・jq

set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ERRNAV_DIR=$(cd "$HERE/.." && pwd)

OUT="${BENCH_OUT:-${TMPDIR:-/tmp}/errnav-bench}"
REPO="${BENCH_REPO:-https://github.com/Mika777v/routepense}"
BASE="${BENCH_BASE:-main}"
BUGS="${BENCH_BUGS:-bench/errnav-bugs}"
RUNS="${BENCH_RUNS:-3}"
CONDITIONS="${BENCH_CONDITIONS:-without with}"
MAX_BUDGET="${BENCH_MAX_BUDGET:-2}"
TIMEOUT_SEC="${BENCH_TIMEOUT:-900}"
INSTALL="${BENCH_INSTALL:-npm ci --no-audit --no-fund}"
TEST_CMD="${BENCH_TEST_CMD:-npm test}"

# 両方の条件で同じ指示。「あり」だけ、errnav の使い方を足す
PROMPT_BASE='`npm test` が失敗しています。失敗の原因になっているコードの場所（ファイルと行）を特定し、なぜ失敗するのかを短く説明してください。コードは直さないでください（ファイルを書き換えない）。最後の行は `原因: <ファイルのパス>:<行番号>` の形にしてください。'
PROMPT_WITH=' このリポジトリには障害解析ツール tools/errnav があります。まず `npm test 2>&1 | tools/errnav/bin/errnav scan -` を実行し、`tools/errnav/bin/errnav context latest` から調べ始めてください。'
# 「あり」の条件で、CLAUDE.md に足す行（テンプレートの AGENTS.md と同じ内容）
CLAUDE_MD_LINE='- 不具合の調べ方・再現の確かめ方: `tools/errnav/README.md`（`tools/errnav/bin/errnav show latest`・`context`・`repro`）。まず errnav を使い、取れないとき（知らない形のログ・エラーの出ない不具合）は自分で grep などで調べてよい'

die() { printf 'bench: %s\n' "$*" >&2; exit 2; }
info() { printf '%s\n' "$*" >&2; }

scenarios() { grep -v '^#' "$HERE/scenarios.tsv" | awk -F'\t' 'NF >= 5'; }

selected() {
  [ -z "$BENCH_ONLY" ] && return 0
  case " $BENCH_ONLY " in *" $1 "*) return 0 ;; esac
  return 1
}

bug_commit() {
  git -C "$OUT/src" log --format=%H --fixed-strings --grep="$1" "origin/$BUGS" | head -n 1
}

# ---- 準備 -----------------------------------------------------------------------
cmd_prepare() {
  mkdir -p "$OUT"
  if [ -d "$OUT/src/.git" ]; then
    git -C "$OUT/src" fetch -q origin "$BASE" "$BUGS" || die "fetch に失敗しました"
  else
    git clone -q --no-single-branch "$REPO" "$OUT/src" || die "clone に失敗しました: $REPO"
    git -C "$OUT/src" fetch -q origin "$BUGS" || die "ブランチ $BUGS がありません"
  fi
  rm -rf "$OUT/base"; mkdir -p "$OUT/base"
  git -C "$OUT/src" archive "origin/$BASE" | tar -x -C "$OUT/base" || die "展開に失敗しました"
  info "==> 依存を入れる: $INSTALL"
  (cd "$OUT/base" && eval "$INSTALL") > "$OUT/install.log" 2>&1 || die "依存を入れられません（$OUT/install.log）"
  local id prefix
  while IFS=$'\t' read -r id prefix _; do
    [ -n "$(bug_commit "$prefix")" ] || die "$id の不具合のコミット（件名「$prefix」）が $BUGS にありません"
  done <<EOF
$(scenarios)
EOF
  info "準備ができました: $OUT"
}

# ---- 作業場所（毎回まっさら。git の履歴に答えが残らないよう、履歴は1コミットだけにする） ---------------
make_workspace() {
  local id="$1" cond="$2" ws="$3" prefix sha
  prefix=$(scenarios | awk -F'\t' -v id="$id" '$1 == id { print $2 }')
  sha=$(bug_commit "$prefix")
  [ -n "$sha" ] || die "$id の不具合のコミットが見つかりません（先に prepare）"
  rm -rf "$ws"
  cp -R "$OUT/base" "$ws" || die "作業場所を作れません"
  git -C "$OUT/src" show "$sha" | (cd "$ws" && git apply) || die "$id の不具合を当てられません"
  if [ "$cond" = with ]; then
    mkdir -p "$ws/tools/errnav"
    # テストの材料（エラーの入ったログ）は持ち込まない。探索の邪魔になるため
    cp -R "$ERRNAV_DIR/bin" "$ERRNAV_DIR/lib" "$ERRNAV_DIR/plugins" "$ERRNAV_DIR/README.md" "$ERRNAV_DIR/ARCHITECTURE.md" "$ws/tools/errnav/"
    printf '\n## 不具合の調べ方\n%s\n' "$CLAUDE_MD_LINE" >> "$ws/CLAUDE.md"
    printf '.errnav/cache/\n' >> "$ws/.gitignore"
  fi
  (
    cd "$ws" && git init -q && git add -A &&
      git -c user.name=bench -c user.email=bench@example.invalid commit -q -m "snapshot"
  ) || die "git の初期化に失敗しました"
}

# ---- AI を動かさない確認 ---------------------------------------------------------------
cmd_dry() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  local id prefix file lo hi kind ws
  while IFS=$'\t' read -r id prefix file lo hi kind; do
    selected "$id" || continue
    ws="$OUT/ws-dry"
    make_workspace "$id" with "$ws"
    printf '== %s（%s）\n' "$id" "$kind"
    (cd "$ws" && eval "$TEST_CMD") > "$OUT/dry-$id.out" 2>&1 && info "  !! テストが通ってしまいました（不具合が効いていない）"
    printf '  テストの失敗: %s\n' "$(grep -E '^ +Tests ' "$OUT/dry-$id.out" | head -n 1 | sed 's/^ *//')"
    printf '  正解: %s:%s-%s\n' "$file" "$lo" "$hi"
    (cd "$ws" && ERRNAV_COLOR=never tools/errnav/bin/errnav scan - < "$OUT/dry-$id.out" | sed -n '2,3p' | sed 's/^/  errnav: /')
    rm -rf "$ws"
  done <<EOF
$(scenarios)
EOF
}

# ---- 測る -----------------------------------------------------------------------
cmd_run() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  command -v claude >/dev/null || die "claude（Claude Code の CLI）がありません"
  command -v jq >/dev/null || die "jq がありません"
  mkdir -p "$OUT/runs"
  local id prefix file lo hi kind cond rep tag ws prompt start end status
  local to=(); command -v timeout >/dev/null && to=(timeout "$TIMEOUT_SEC")
  while IFS=$'\t' read -r id prefix file lo hi kind; do
    selected "$id" || continue
    for rep in $(seq 1 "$RUNS"); do
      for cond in $CONDITIONS; do
        tag="$id-$cond-$rep"
        [ -s "$OUT/runs/$tag.jsonl" ] && { info "== $tag（済み。やり直すなら $OUT/runs/$tag.jsonl を消す）"; continue; }
        ws="$OUT/ws-$tag"
        make_workspace "$id" "$cond" "$ws"
        prompt="$PROMPT_BASE"; [ "$cond" = with ] && prompt="$PROMPT_BASE$PROMPT_WITH"
        info "== $tag"
        start=$(date +%s)
        # 調べるだけにする: 書き換えのツールとサブエージェント（呼び出しの回数が数えられなくなる）は使わせない
        # ユーザーの設定（フックなど）と MCP は読まない。条件をそろえるため
        (cd "$ws" && "${to[@]}" claude -p "$prompt" --output-format stream-json --verbose \
          --allowedTools "Bash" "Read" "Grep" "Glob" \
          --disallowedTools "Edit" "Write" "NotebookEdit" "Task" "Agent" "WebFetch" "WebSearch" \
          --setting-sources project,local --strict-mcp-config --no-session-persistence \
          --max-budget-usd "$MAX_BUDGET" ${BENCH_MODEL:+--model "$BENCH_MODEL"} \
          > "$OUT/runs/$tag.jsonl" 2> "$OUT/runs/$tag.err")
        status=$?
        end=$(date +%s)
        printf '%s\t%s\t%s\n' "$status" "$((end - start))" "$(git -C "$ws" status --porcelain | grep -v '^?? .errnav/' | wc -l | tr -d ' ')" > "$OUT/runs/$tag.meta"
        rm -rf "$ws"
      done
    done
  done <<EOF
$(scenarios)
EOF
  cmd_report
}

# ---- 結果 -----------------------------------------------------------------------
# 1回分を1行にする: id cond rep 正解 ツール回数 Bash Read Grep Glob ターン 入力 出力 キャッシュ作成 キャッシュ読み 料金 秒 終了コード 書き換え 答え
row_of() {
  local f="$1" id cond rep file lo hi answer afile aline ok meta
  tag=$(basename "$f" .jsonl); id="${tag%%-*}"; rep="${tag##*-}"; cond="${tag#*-}"; cond="${cond%-*}"
  IFS=$'\t' read -r _ _ file lo hi _ <<EOF
$(scenarios | awk -F'\t' -v id="$id" '$1 == id')
EOF
  answer=$(jq -r 'select(.type == "result") | .result // ""' "$f" 2>/dev/null | grep -E '原因[:：]' | tail -n 1)
  afile=$(printf '%s' "$answer" | sed -E 's/.*原因[:：][[:space:]]*`?([^`[:space:]]+):([0-9]+).*/\1/')
  aline=$(printf '%s' "$answer" | sed -E 's/.*原因[:：][[:space:]]*`?([^`[:space:]]+):([0-9]+).*/\2/')
  ok=0
  case "$afile" in *"$file") ok=1; if [ "$aline" -ge "$lo" ] 2>/dev/null && [ "$aline" -le "$hi" ] 2>/dev/null; then ok=2; fi ;; esac
  meta=$(cat "${f%.jsonl}.meta" 2>/dev/null || printf '\t\t')
  jq -r --arg id "$id" --arg cond "$cond" --arg rep "$rep" --arg ok "$ok" --arg meta "$meta" --arg ans "$afile:$aline" -s '
    def tools: [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name ];
    (tools) as $t
    | (map(select(.type == "result")) | last // {}) as $r
    | ($meta | split("\t")) as $m
    | [ $id, $cond, $rep, $ok, ($t | length),
        ($t | map(select(. == "Bash")) | length), ($t | map(select(. == "Read")) | length),
        ($t | map(select(. == "Grep")) | length), ($t | map(select(. == "Glob")) | length),
        ($r.num_turns // ""), ($r.usage.input_tokens // ""), ($r.usage.output_tokens // ""),
        ($r.usage.cache_creation_input_tokens // ""), ($r.usage.cache_read_input_tokens // ""),
        ($r.total_cost_usd // ""), ((($r.duration_ms // 0) / 1000) | floor), ($m[0] // ""), ($m[2] // ""), $ans ]
    | @tsv' "$f"
}

cmd_report() {
  local f rows="$OUT/results.tsv"
  ls "$OUT"/runs/*.jsonl >/dev/null 2>&1 || die "結果がありません（先に run）"
  printf 'id\tcond\trep\tcorrect\ttools\tbash\tread\tgrep\tglob\tturns\tin\tout\tcache_create\tcache_read\tcost_usd\tsec\texit\tchanged\tanswer\n' > "$rows"
  for f in "$OUT"/runs/*.jsonl; do row_of "$f" >> "$rows"; done
  echo "1回ごと: $rows（correct: 2 = ファイルと行が合う / 1 = ファイルだけ合う / 0 = 外れ）"
  echo
  # シナリオ × 条件 の平均
  awk -F'\t' -v OFS='\t' '
    NR == 1 { next }
    { k = $1 "\t" $2; n[k]++; ok[k] += ($4 == 2); fileok[k] += ($4 >= 1); t[k] += $5; tu[k] += $10
      tok[k] += $11 + $12 + $13 + $14; c[k] += $15; s[k] += $16; if (!(k in seen)) { seen[k] = 1; order[++m] = k } }
    END {
      printf "%-4s %-8s %3s %9s %9s %7s %7s %10s %8s %6s\n", "id", "cond", "n", "正解(行)", "正解(file)", "ツール", "ターン", "トークン", "料金$", "秒"
      for (i = 1; i <= m; i++) { k = order[i]; split(k, a, "\t")
        printf "%-4s %-8s %3d %7d/%-2d %7d/%-2d %7.1f %7.1f %10.0f %8.3f %6.0f\n", a[1], a[2], n[k], ok[k], n[k], fileok[k], n[k], t[k]/n[k], tu[k]/n[k], tok[k]/n[k], c[k]/n[k], s[k]/n[k] }
    }' "$rows"
}

case "${1:-}" in
  prepare) cmd_prepare ;;
  dry)     cmd_dry ;;
  run)     cmd_run ;;
  report)  cmd_report ;;
  *) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
