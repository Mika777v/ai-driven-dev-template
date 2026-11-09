#!/usr/bin/env bash
# リポジトリの設定を GitHub の API でそろえるスクリプト。何度実行しても同じ状態になる。
# 元: ai-driven-dev-template の scripts/github/setup-repo.sh。このリポジトリ向けに次を変えた:
#   - マージコミットも許す（bench/ を git subtree で取り込む PR は「Create a merge commit」でマージするため。AGENTS.md §6）。
#     そのため直線の履歴（required_linear_history）は求めない
#   - 必須チェックは ci-ok だけ（このリポジトリには PR タイトルの確認 pr-title.yml が無い。ci.yml のコメントのとおり）
#
# 前提:
#   - GitHub CLI（gh）をインストールし、リポジトリの管理者のアカウントでログインしている（gh auth login）
#   - .github/workflows/ci.yml が既定ブランチに入っている
#     （まだ無いチェックを必須にすると、どの PR もマージできなくなるため）
#
# 使い方:
#   REPO=<owner>/<repo> bash scripts/github/setup-repo.sh
#   REPO=<owner>/<repo> bash scripts/github/setup-repo.sh --codespace   # Codespaces で動かす場合
#   REPO=<owner>/<repo> APPROVALS=1 bash scripts/github/setup-repo.sh   # チームで使う場合
#
# --codespace: Codespaces が自動で入れる GITHUB_TOKEN は権限が狭く、gh はこれを優先して使うので、
#   リポジトリの設定・ルールセットの変更が権限不足で失敗する。このスクリプトの中だけ GITHUB_TOKEN を外し、
#   gh にログインしていなければ gh auth login を始める（対話。管理者のアカウントで）。
#   Codespaces の中（環境変数 CODESPACES=true）で付け忘れたときは、止めて付けるよう案内する
set -euo pipefail

: "${REPO:?REPO=<owner>/<repo> を指定してください}"
APPROVALS="${APPROVALS:-0}"

CODESPACE=0
for arg in "$@"; do
  case "$arg" in
    --codespace) CODESPACE=1 ;;
    *) echo "知らない引数: $arg（使えるのは --codespace）" >&2; exit 2 ;;
  esac
done

if [ "$CODESPACE" = 1 ]; then
  echo "==> codespace: GITHUB_TOKEN を外して、gh のログインを確かめる"
  unset GITHUB_TOKEN GH_TOKEN
  if ! gh auth status >/dev/null 2>&1; then
    gh auth login
  fi
elif [ "${CODESPACES:-}" = "true" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "Codespaces の中です。自動で入る GITHUB_TOKEN では権限が足りないので、--codespace を付けて実行してください" >&2
  exit 1
fi

# ---------------------------------------------------------------
# 1. 基本設定
#    - マージはスカッシュとマージコミット（マージコミットは subtree の取り込み用）。リベースは使わない
#    - スカッシュ後のコミットは PR のタイトルと本文にする
#    - 自動マージを有効にする / マージ後にブランチを消す
# ---------------------------------------------------------------
echo "==> repository settings"
gh api -X PATCH "repos/${REPO}" --silent \
  -F allow_squash_merge=true \
  -F allow_merge_commit=true \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=true \
  -F allow_update_branch=true \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY

# ---------------------------------------------------------------
# 2. 依存ライブラリの脆弱性の通知
# ---------------------------------------------------------------
echo "==> dependabot alerts"
gh api -X PUT "repos/${REPO}/vulnerability-alerts" --silent

# ---------------------------------------------------------------
# 3. 既定ブランチの保護（Repository Ruleset）
#    - PR 必須（承認数は APPROVALS。1人開発なら 0）
#    - 必須チェック: ci のゲートジョブ ci-ok
#    - force push・削除の禁止（マージコミットは subtree の取り込みのために許す）
#    - 管理者も例外にしない
# ---------------------------------------------------------------
echo "==> ruleset: main-protection"
RULESET_JSON=$(cat <<JSON
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${APPROVALS},
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash", "merge"]
      } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "ci-ok" }
        ]
      } }
  ]
}
JSON
)

RULESET_ID=$(gh api "repos/${REPO}/rulesets" --jq '.[] | select(.name=="main-protection") | .id')
if [ -n "${RULESET_ID}" ]; then
  echo "${RULESET_JSON}" | gh api -X PUT "repos/${REPO}/rulesets/${RULESET_ID}" --silent --input -
else
  echo "${RULESET_JSON}" | gh api -X POST "repos/${REPO}/rulesets" --silent --input -
fi

echo "done"
