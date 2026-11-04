#!/usr/bin/env bash
# リポジトリの設定を GitHub の API でそろえるスクリプト。何度実行しても同じ状態になる。
# 何を設定するかと理由は docs/AI_GIT_WORKFLOW.md §8。
#
# 前提:
#   - GitHub CLI（gh）をインストールし、リポジトリの管理者のアカウントでログインしている（gh auth login）
#   - .github/workflows/ci.yml と pr-title.yml が既定ブランチに入っている
#     （まだ無いチェックを必須にすると、どの PR もマージできなくなるため）
#
# 使い方:
#   REPO=<owner>/<repo> bash scripts/github/setup-repo.sh
#   REPO=<owner>/<repo> APPROVALS=1 bash scripts/github/setup-repo.sh   # チームで使う場合
set -euo pipefail

: "${REPO:?REPO=<owner>/<repo> を指定してください}"
APPROVALS="${APPROVALS:-0}"

# ---------------------------------------------------------------
# 1. 基本設定
#    - マージはスカッシュだけ（既定ブランチの履歴を「1 PR = 1 コミット」に保つ）
#    - スカッシュ後のコミットは PR のタイトルと本文にする
#    - 自動マージを有効にする / マージ後にブランチを消す
# ---------------------------------------------------------------
echo "==> repository settings"
gh api -X PATCH "repos/${REPO}" --silent \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
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
#    - 必須チェック: pr-title の conventional-commits と、ci のゲートジョブ ci-ok
#    - force push・削除の禁止、マージコミットの禁止
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
    { "type": "required_linear_history" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${APPROVALS},
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "conventional-commits" },
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
