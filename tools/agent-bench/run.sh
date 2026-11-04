#!/usr/bin/env bash
# テンプレート（CLAUDE.md の運用ルール）の効果を測るベンチマーク。
# 同じ Task を「テンプレートあり」と「最小限の CLAUDE.md」で AI（Claude Code）に実装させ、
# 機能が正しいか（見せていない受け入れテスト）・ルールを守ったか・使った量を比べる。
#
# 使い方:
#   bash tools/agent-bench/run.sh prepare      # 対象のリポジトリを取得し、依存を入れる（1回だけ）
#   bash tools/agent-bench/run.sh dry          # AI を動かさずに確かめる（受け入れテストが落ちること・正解の実装で通ること）
#   bash tools/agent-bench/run.sh run          # AI を動かして測る（料金・利用枠を使う）
#   bash tools/agent-bench/run.sh report       # 結果の表
#
# 主な設定（環境変数）:
#   BENCH_OUT         作業と結果の置き場所（既定: ${TMPDIR:-/tmp}/agent-bench）
#   BENCH_REPO        対象のリポジトリ（既定: https://github.com/Mika777v/routepense）
#   BENCH_BASE        土台のコミット（既定: 41ac314。routepense の CLAUDE.md を短くした後の main）
#   BENCH_TASK        Task（既定: T1-daily-note。tasks/ の下のディレクトリ名）
#   BENCH_CONDITIONS  条件（既定: "template minimal"）
#                       template  土台の CLAUDE.md のまま（運用のルールの要点と「いつ何を読むか」）
#                       minimal   CLAUDE.md を、説明・技術スタック・コマンドだけにする
#   BENCH_RUNS        1つの条件で何回動かすか（既定: 2）
#   BENCH_MODEL       使うモデル（比べるときは固定する）
#   BENCH_MAX_BUDGET  1回あたりの上限（ドル。既定: 5）
#   BENCH_TIMEOUT     1回あたりの上限（秒。既定: 1800。timeout コマンドがあるときだけ）
#
# 必要なもの: git・jq・Node.js 22・claude（Claude Code の CLI。ログイン済み）

set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

OUT="${BENCH_OUT:-${TMPDIR:-/tmp}/agent-bench}"
REPO="${BENCH_REPO:-https://github.com/Mika777v/routepense}"
BASE="${BENCH_BASE:-41ac314}"
TASK_NAME="${BENCH_TASK:-T1-daily-note}"
TASK="$HERE/tasks/$TASK_NAME"
CONDITIONS="${BENCH_CONDITIONS:-template minimal}"
RUNS="${BENCH_RUNS:-2}"
MAX_BUDGET="${BENCH_MAX_BUDGET:-5}"
TIMEOUT_SEC="${BENCH_TIMEOUT:-1800}"
INSTALL="${BENCH_INSTALL:-npm ci --no-audit --no-fund}"

die() { printf 'bench: %s\n' "$*" >&2; exit 2; }
info() { printf '%s\n' "$*" >&2; }
[ -f "$TASK/task.md" ] || die "Task がありません: $TASK"

# 両方の条件で同じ指示。運用のルールのことは書かない（CLAUDE.md から読むかを見るため）
prompt() {
  cat <<'EOF'
次の Task を実装して、PR を出す直前まで進めてください。
GitHub には接続できないので、push と PR の作成はできません。代わりに、PR のタイトルを PR_TITLE.txt、本文を PR_BODY.md に書いてください（この2つはコミットしない）。変更はコミットまでしてください。
質問はできないので、決めることがあれば自分で決めて、PR の本文に書いてください。

EOF
  cat "$TASK/task.md"
}

# ---- 準備 -----------------------------------------------------------------------
cmd_prepare() {
  mkdir -p "$OUT"
  if [ -d "$OUT/src/.git" ]; then
    git -C "$OUT/src" fetch -q origin main || die "fetch に失敗しました"
  else
    git clone -q "$REPO" "$OUT/src" || die "clone に失敗しました: $REPO"
  fi
  local ref="origin/$BASE"
  git -C "$OUT/src" rev-parse -q --verify "$ref^{commit}" >/dev/null || ref="$BASE"
  git -C "$OUT/src" rev-parse -q --verify "$ref^{commit}" >/dev/null || die "土台 $BASE が見つかりません"
  rm -rf "$OUT/base"; mkdir -p "$OUT/base"
  git -C "$OUT/src" archive "$ref" | tar -x -C "$OUT/base" || die "展開に失敗しました"
  info "==> 依存を入れる: $INSTALL"
  (cd "$OUT/base" && eval "$INSTALL") < /dev/null > "$OUT/install.log" 2>&1 || die "依存を入れられません（$OUT/install.log）"
  info "準備ができました: $OUT"
}

# ---- 作業場所（毎回まっさら。git の履歴は1コミットだけ） ------------------------------------------
make_workspace() {
  local cond="$1" ws="$2"
  rm -rf "$ws"
  cp -R "$OUT/base" "$ws" || die "作業場所を作れません"
  case "$cond" in
    template) ;;
    minimal) cp "$HERE/fixtures/routepense-minimal-CLAUDE.md" "$ws/CLAUDE.md" ;;
    *) die "知らない条件: $cond" ;;
  esac
  (
    cd "$ws" && git init -q -b main && git add -A &&
      git -c user.name=bench -c user.email=bench@example.invalid commit -q -m "snapshot" &&
      git config user.name "bench-agent" && git config user.email "agent@example.invalid"
  ) || die "git の初期化に失敗しました"
}

# ---- AI を動かさない確認 ---------------------------------------------------------------
cmd_dry() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  local ws="$OUT/ws-dry"
  echo "== 何もしない場合（受け入れテストは落ちるはず）"
  make_workspace template "$ws"
  bash "$HERE/score.sh" "$ws" "$TASK" | grep -E '^(accept_|suite_ok|typecheck_ok|branch_ok|pr_title_ok)' | sed 's/^/  /'
  if [ -f "$TASK/reference.patch" ]; then
    echo "== 正解の実装（reference.patch）を当てた場合（受け入れテストは全部通るはず）"
    make_workspace template "$ws"
    (cd "$ws" && git apply "$TASK/reference.patch" && git checkout -q -b feat/daily-note &&
      git add -A && git commit -q -m "feat(backend): 日次記録にメモを付ける" &&
      printf 'feat(backend): 日次記録にメモを付ける\n' > PR_TITLE.txt &&
      printf '## 概要\n## 変更内容\n## 確認が必要な項目\nDB のスキーマの変更（マイグレーション 4）\n## 動作確認の方法\n## チェックリスト\n' > PR_BODY.md) || die "正解の実装を当てられません"
    bash "$HERE/score.sh" "$ws" "$TASK" | sed 's/^/  /'
  fi
  rm -rf "$ws"
}

# ---- 測る -----------------------------------------------------------------------
cmd_run() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  command -v claude >/dev/null || die "claude（Claude Code の CLI）がありません"
  command -v jq >/dev/null || die "jq がありません"
  mkdir -p "$OUT/runs"
  local cond rep tag ws start end status to=()
  command -v timeout >/dev/null && to=(timeout "$TIMEOUT_SEC")
  for rep in $(seq 1 "$RUNS"); do
    for cond in $CONDITIONS; do
      tag="$TASK_NAME-$cond-$rep"
      [ -s "$OUT/runs/$tag.score" ] && { info "== $tag（済み。やり直すなら $OUT/runs/$tag.* を消す）"; continue; }
      ws="$OUT/ws-$tag"
      make_workspace "$cond" "$ws"
      info "== $tag"
      start=$(date +%s)
      # 書き換えは許す。サブエージェント（数えられなくなる）と Web は使わせない。ユーザーの設定と MCP は読まない
      # 標準入力は /dev/null にする（claude が標準入力を読んで止まらないように）
      (cd "$ws" && "${to[@]}" claude -p "$(prompt)" --output-format stream-json --verbose \
        --allowedTools "Bash" "Read" "Grep" "Glob" "Edit" "Write" "Skill" \
        --disallowedTools "NotebookEdit" "Task" "Agent" "WebFetch" "WebSearch" \
        --setting-sources project,local --strict-mcp-config --no-session-persistence \
        --max-budget-usd "$MAX_BUDGET" ${BENCH_MODEL:+--model "$BENCH_MODEL"} \
        < /dev/null > "$OUT/runs/$tag.jsonl" 2> "$OUT/runs/$tag.err")
      status=$?
      end=$(date +%s)
      info "   採点する"
      { printf 'exit\t%s\nsec_wall\t%s\n' "$status" "$((end - start))"
        bash "$HERE/score.sh" "$ws" "$TASK"; } > "$OUT/runs/$tag.score" 2> "$OUT/runs/$tag.score.err"
      # 差分を残してから作業場所を消す（後で人が読めるように）
      (cd "$ws" && git diff "$(git rev-list --max-parents=0 HEAD | tail -n 1)" HEAD > "$OUT/runs/$tag.diff"
        cp PR_TITLE.txt "$OUT/runs/$tag.pr_title.txt" 2>/dev/null; cp PR_BODY.md "$OUT/runs/$tag.pr_body.md" 2>/dev/null)
      rm -rf "$ws"
    done
  done
  cmd_report
}

# ---- 結果 -----------------------------------------------------------------------
usage_of() {
  jq -r -s '
    ([ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") ] | length) as $tools
    | (map(select(.type == "result")) | last // {}) as $r
    | [ $tools, ($r.num_turns // ""),
        (($r.usage.input_tokens // 0) + ($r.usage.output_tokens // 0) + ($r.usage.cache_creation_input_tokens // 0) + ($r.usage.cache_read_input_tokens // 0)),
        ($r.total_cost_usd // ""), ((($r.duration_ms // 0) / 1000) | floor) ] | @tsv' "$1"
}

cmd_report() {
  ls "$OUT"/runs/*.score >/dev/null 2>&1 || die "結果がありません（先に run）"
  local keys="accept_passed accept_total suite_ok typecheck_ok lint_ok branch_ok branch_named commits_conventional uncommitted pr_title_ok pr_sections_ok pr_confirm_declared pr_links_issue touched_textbook touched_openapi touched_frontend touched_troubleshooting touched_progress migration_rewritten out_of_scope files_changed"
  local rows="$OUT/results.tsv" f tag k
  { printf 'run\ttools\tturns\ttokens\tcost_usd\tsec'; for k in $keys; do printf '\t%s' "$k"; done; printf '\n'; } > "$rows"
  for f in "$OUT"/runs/*.score; do
    tag=$(basename "$f" .score)
    { printf '%s\t%s' "$tag" "$(usage_of "$OUT/runs/$tag.jsonl" 2>/dev/null || printf '\t\t\t\t')"
      for k in $keys; do printf '\t%s' "$(awk -F'\t' -v k="$k" '$1 == k { print $2; exit }' "$f")"; done
      printf '\n'; } >> "$rows"
  done
  echo "1回ごと: $rows"
  echo
  # 縦に並べる（項目が多いので、1列 = 1回）
  awk -F'\t' '{ for (i = 1; i <= NF; i++) cell[i, NR] = $i; if (NF > nf) nf = NF; n = NR }
    END { for (i = 1; i <= nf; i++) { printf "%-24s", cell[i, 1]; for (j = 2; j <= n; j++) printf " %-22s", cell[i, j]; printf "\n" } }' "$rows" | sed '1s/^run */項目                    /'
}

case "${1:-}" in
  prepare) cmd_prepare ;;
  dry)     cmd_dry ;;
  run)     cmd_run ;;
  report)  cmd_report ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
