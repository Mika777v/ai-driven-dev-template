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
#                       bare      minimal に加えて、運用のルールの文書（DEV_RULES・GITHUB_WORKFLOW・PROGRESS・
#                                 PR / Issue のテンプレート・pr-title.yml）も消す。「ルールが無い」状態
#                       none      bare に加えて docs/adr/README.md（ADR を書くときのルール）も消す
#   BENCH_RUNS        1つの条件で何回動かすか（既定: 2）
#   BENCH_MODEL       使うモデル（比べるときは固定する）
#   BENCH_SPEC_MODEL  決めると、実装の前に、このモデルが要件を詰める段階を入れる（コードは変えず SPEC.md を書く）。
#                     実装する AI には、Task と詰めた要件（オーナーが確かめた扱い）を渡す
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
# shellcheck disable=SC1091
. "$TASK/config.sh"
# 続きの Task は、条件の既定を from-<土台> にする
if [ -n "$BASES" ] && [ -z "$BENCH_CONDITIONS" ]; then
  CONDITIONS=""; for b in $BASES; do CONDITIONS="$CONDITIONS from-$b"; done
fi

# 両方の条件で同じ指示。運用のルールのことは書かない（CLAUDE.md から読むかを見るため）
prompt() {
  cat <<'EOF'
次の Task を実装して、PR を出す直前まで進めてください。
GitHub には接続できないので、push と PR の作成はできません。代わりに、PR のタイトルを PR_TITLE.txt、本文を PR_BODY.md に書いてください（この2つはコミットしない）。変更はコミットまでしてください。
質問はできないので、決めることがあれば自分で決めて、PR の本文に書いてください。

EOF
  cat "$TASK/task.md"
  if [ -n "$SPEC_FILE" ] && [ -s "$SPEC_FILE" ]; then
    printf '\n\n---\n\n# 要件を詰めた結果（オーナーが確かめ、この内容で進めてよいと言った）\n\n'
    cat "$SPEC_FILE"
  fi
}

# 要件を詰める段階への指示（ベンチではオーナーに聞けないので、おすすめの答えを採用した扱いにする）
spec_prompt() {
  cat <<'EOF'
あなたは、実装の前に要件を詰める役です。コードや文書は変えないでください（git のコミットもしない）。
次の Task を読み、リポジトリ（要件定義・ADR・コード）を調べて、実装する人に渡す要件を SPEC.md に書いてください。

- 依頼のあいまいなところ、オーナーに確かめるべきことを洗い出す。それぞれに、選択肢・おすすめ・理由を書く
- オーナーにはこの後で確かめるので、おすすめの答えを採用したものとして、要件（やること・やらないこと・受け入れ条件）を書く
- 戻しにくい変更（DB のスキーマ・要件定義の変更など）が要るなら、そう書く

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
# 条件ごとの手当て（CLAUDE.md の差し替え・ルールの文書を消す）
treat() {
  local cond="$1" ws="$2"
  case "$cond" in
    template) ;;
    minimal) cp "$HERE/fixtures/routepense-minimal-CLAUDE.md" "$ws/CLAUDE.md" ;;
    bare)
      # テンプレートが持ち込んだ運用のルールの文書も消す（プロジェクトの中身の文書・CI は残す）
      cp "$HERE/fixtures/routepense-minimal-CLAUDE.md" "$ws/CLAUDE.md"
      rm -rf "$ws/docs/DEV_RULES.md" "$ws/docs/GITHUB_WORKFLOW.md" "$ws/docs/PROGRESS.md" \
        "$ws/.github/pull_request_template.md" "$ws/.github/ISSUE_TEMPLATE" "$ws/.github/workflows/pr-title.yml"
      ;;
    none)
      # bare に加えて、ADR の書き方（いつ書くか・自動マージしないこと）を書いた docs/adr/README.md も消す。
      # ADR そのもの（0001〜）はプロジェクトの中身として残す
      treat bare "$ws"
      rm -f "$ws/docs/adr/README.md"
      ;;
    *) die "知らない条件: $cond" ;;
  esac
}

make_workspace() {
  local cond="$1" ws="$2"
  rm -rf "$ws"
  cp -R "$OUT/base" "$ws" || die "作業場所を作れません"
  if [ -n "$BASES" ]; then
    make_followup_workspace "$cond" "$ws"; return
  fi
  treat "$cond" "$ws"
  (
    cd "$ws" && git init -q -b main && git add -A &&
      git -c user.name=bench -c user.email=bench@example.invalid commit -q -m "snapshot" &&
      git tag bench-start &&
      git config user.name "bench-agent" && git config user.email "agent@example.invalid"
  ) || die "git の初期化に失敗しました"
}

# 続きの Task の作業場所: 前の作業の結果を、スカッシュマージした後の main と同じ形で入れる。
# 続きをやる AI の条件はそろえる（どちらも CLAUDE.md は最小限・ルールの文書なし）。違うのは前の作業が残した物だけ
make_followup_workspace() {
  local cond="$1" ws="$2" name treatment
  name="${cond#from-}"
  case " $BASES " in *" $name "*) ;; *) die "知らない条件: $cond（from-<${BASES// /|}>）" ;; esac
  eval "treatment=\${BASE_TREATMENT_$name:-$name}"
  treat "$treatment" "$ws"               # 前の作業をしたときの作業場所に戻す（diff がそれに対して作られているため）
  treat bare "$ws"                       # 続きの条件をそろえる（ルールの文書と案内を外す）
  [ "$name" = template ] && git -C "$OUT/src" show "$(base_ref):docs/PROGRESS.md" > "$ws/docs/PROGRESS.md" 2>/dev/null
  (
    cd "$ws" && git init -q -b main && git add -A &&
      git -c user.name=bench -c user.email=bench@example.invalid commit -q -m "snapshot" &&
      git apply "$TASK/bases/$name.diff" && git add -A &&
      git -c user.name=bench -c user.email=bench@example.invalid commit -q -F - <<MSG &&
$(cat "$TASK/bases/$name.pr_title.txt")

$(cat "$TASK/bases/$name.pr_body.md")
MSG
      git tag bench-start &&
      git config user.name "bench-agent" && git config user.email "agent@example.invalid"
  ) || die "続きの作業場所を作れません（$name）"
}

base_ref() {
  local ref="origin/$BASE"
  git -C "$OUT/src" rev-parse -q --verify "$ref^{commit}" >/dev/null || ref="$BASE"
  printf '%s\n' "$ref"
}

# ---- AI を動かさない確認 ---------------------------------------------------------------
cmd_dry() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  local ws="$OUT/ws-dry" cond name
  if [ -n "$BASES" ]; then
    for cond in $CONDITIONS; do
      name="${cond#from-}"
      echo "== $cond: 何もしない場合（新しい要求の受け入れテストは落ちるはず）"
      make_workspace "$cond" "$ws"
      git -C "$ws" log --format='  前の作業: %s' -1
      bash "$HERE/score.sh" "$ws" "$TASK" | grep -E '^(accept_|suite_ok|leftover_files)' | sed 's/^/  /'
      if [ -f "$TASK/reference-from-$name.patch" ]; then
        echo "== $cond: 正解の実装（reference-from-$name.patch）を当てた場合（受け入れテストは全部通るはず）"
        (cd "$ws" && git apply "$TASK/reference-from-$name.patch") || die "正解の実装を当てられません"
        bash "$HERE/score.sh" "$ws" "$TASK" | grep -E '^(accept_|leftover_files)' | sed 's/^/  /'
      fi
    done
    rm -rf "$ws"; return
  fi
  echo "== 何もしない場合（受け入れテストは落ちるはず）"
  make_workspace template "$ws"
  bash "$HERE/score.sh" "$ws" "$TASK" | grep -E '^(accept_|suite_ok|typecheck_ok|branch_ok|pr_title_ok)' | sed 's/^/  /'
  if [ -f "$TASK/reference.patch" ]; then
    echo "== 正解の実装（reference.patch）を当てた場合（受け入れテストは全部通るはず）"
    make_workspace template "$ws"
    (cd "$ws" && git apply "$TASK/reference.patch" && git checkout -q -b feat/daily-note &&
      git add -A && git commit -q -m "feat: 正解の実装（dry）" &&
      printf 'feat: 正解の実装（dry）\n' > PR_TITLE.txt &&
      printf '## 概要\n## 変更内容\n## 確認が必要な項目\n（dry の仮の本文）\n## 動作確認の方法\n## チェックリスト\n' > PR_BODY.md) || die "正解の実装を当てられません"
    bash "$HERE/score.sh" "$ws" "$TASK" | sed 's/^/  /'
  fi
  rm -rf "$ws"
}

# ---- 測る -----------------------------------------------------------------------
# 利用枠の上限で止まった回か（止まった回は採点せず、結果を残さない。次の run でやり直す）
hit_limit() {
  jq -e -s 'map(select(.type == "result")) | last | (.is_error == true) and ((.result // "") | test("limit"; "i"))' "$1" >/dev/null 2>&1
}

cmd_run() {
  [ -d "$OUT/base" ] || die "先に prepare を実行してください"
  command -v claude >/dev/null || die "claude（Claude Code の CLI）がありません"
  command -v jq >/dev/null || die "jq がありません"
  mkdir -p "$OUT/runs"
  local cond rep tag ws start end status to=()
  command -v timeout >/dev/null && to=(timeout "$TIMEOUT_SEC")
  for rep in $(seq 1 "$RUNS"); do
    for cond in $CONDITIONS; do
      # モデルを決めたときは、結果の名前にモデルを入れる（ほかのモデルの結果を上書きしないように）
      tag="$TASK_NAME-$cond-${BENCH_SPEC_MODEL:+spec-${BENCH_SPEC_MODEL#claude-}-}${BENCH_MODEL:+${BENCH_MODEL#claude-}-}$rep"
      [ -s "$OUT/runs/$tag.score" ] && { info "== $tag（済み。やり直すなら $OUT/runs/$tag.* を消す）"; continue; }
      ws="$OUT/ws-$tag"
      make_workspace "$cond" "$ws"
      info "== $tag"
      SPEC_FILE=""
      if [ -n "$BENCH_SPEC_MODEL" ]; then
        info "   要件を詰める（$BENCH_SPEC_MODEL）"
        (cd "$ws" && "${to[@]}" claude -p "$(spec_prompt)" --output-format stream-json --verbose \
          --allowedTools "Bash" "Read" "Grep" "Glob" "Write" \
          --disallowedTools "Edit" "NotebookEdit" "Task" "Agent" "WebFetch" "WebSearch" \
          --setting-sources project,local --strict-mcp-config --no-session-persistence \
          --max-budget-usd "$MAX_BUDGET" --model "$BENCH_SPEC_MODEL" \
          < /dev/null > "$OUT/runs/$tag.spec.jsonl" 2> "$OUT/runs/$tag.spec.err")
        if hit_limit "$OUT/runs/$tag.spec.jsonl"; then
          rm -rf "$ws" "$OUT/runs/$tag".*; die "利用枠の上限で止まった（$tag）。上限が戻ってから run をもう一度"
        fi
        cp "$ws/SPEC.md" "$OUT/runs/$tag.spec.md" 2>/dev/null || info "   SPEC.md が書かれなかった"
        # 要件の段階が触った物は戻す（実装の段階は、同じ土台から始める）
        (cd "$ws" && git status --porcelain > "$OUT/runs/$tag.spec.touched" && git reset -q --hard bench-start && git clean -qfd)
        SPEC_FILE="$OUT/runs/$tag.spec.md"
      fi
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
      if hit_limit "$OUT/runs/$tag.jsonl"; then
        rm -rf "$ws" "$OUT/runs/$tag".*; die "利用枠の上限で止まった（$tag）。上限が戻ってから run をもう一度"
      fi
      info "   採点する"
      { printf 'exit\t%s\nsec_wall\t%s\n' "$status" "$((end - start))"
        bash "$HERE/score.sh" "$ws" "$TASK"; } > "$OUT/runs/$tag.score" 2> "$OUT/runs/$tag.score.err"
      # 差分を残してから作業場所を消す（後で人が読めるように）
      (cd "$ws" && git diff bench-start HEAD > "$OUT/runs/$tag.diff"
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
