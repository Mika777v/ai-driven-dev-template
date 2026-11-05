#!/usr/bin/env bash
# 作業が終わった作業場所を採点し、「項目<TAB>値」を1行ずつ出す。
#
# 使い方:
#   bash tools/agent-bench/score.sh <作業場所> <Task のディレクトリ>
#
# 値は 1 = できた / 0 = できていない（ほかは数や文字）。
# 受け入れテストは、作業場所に置いて流した後に消す（作業場所を元の状態に戻す）。

set -o pipefail
WS="$1"; TASK="$2"
[ -d "$WS/.git" ] && [ -f "$TASK/config.sh" ] || { echo "使い方: score.sh <作業場所> <Task のディレクトリ>" >&2; exit 2; }
# shellcheck disable=SC1091
. "$TASK/config.sh"
cd "$WS" || exit 2

out() { printf '%s\t%s\n' "$1" "$2"; }
yes() { if "$@" >/dev/null 2>&1; then echo 1; else echo 0; fi; }

# 作業の始まり。続きの Task では、前の作業のコミットの後（タグ bench-start）から数える
root=$(git rev-parse -q --verify bench-start 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -n 1)

# ---- git ------------------------------------------------------------------------
branch=$(git rev-parse --abbrev-ref HEAD)
out branch "$branch"
case "$branch" in main|master|HEAD) out branch_ok 0 ;; *) out branch_ok 1 ;; esac
out branch_named "$(printf '%s' "$branch" | grep -Eq "^($TYPES)/" && echo 1 || echo 0)"

# 作業のコミット（スナップショットの後）。どのブランチにあっても数える
commits=$(git rev-list --count --all --not "$root")
out commits "$commits"
bad=0
while IFS= read -r subject; do
  [ -n "$subject" ] || continue
  printf '%s' "$subject" | grep -Eq "^($TYPES)(\(($SCOPES)\))?!?: .+" || bad=$((bad + 1))
done <<EOF
$(git log --all --format=%s --not "$root")
EOF
out commits_conventional "$([ "$commits" -gt 0 ] && [ "$bad" -eq 0 ] && echo 1 || echo 0)"

# 書きかけ（コミットしていない変更）。PR_TITLE.txt・PR_BODY.md・キャッシュは除く
dirty=$(git status --porcelain | grep -vE ' (PR_TITLE\.txt|PR_BODY\.md)$|\.errnav/' | wc -l | tr -d ' ')
out uncommitted "$dirty"

# 変えたファイル（スナップショットから、作業ブランチの先まで + 書きかけ）
changed=$( { git diff --name-only "$root" HEAD; git status --porcelain | cut -c4-; } | sort -u | grep -v '^$')
out files_changed "$(printf '%s\n' "$changed" | grep -c .)"
out out_of_scope "$(printf '%s\n' "$changed" | grep -v '^$' | grep -cvE "$SCOPE_RE")"
for kv in $DOC_CHECKS; do
  name="${kv%%=*}"; prefix="${kv#*=}"
  out "touched_$name" "$(printf '%s\n' "$changed" | grep -q "^$prefix" && echo 1 || echo 0)"
done

# 既にあるマイグレーションを書き換えていないか（削った行があれば書き換えとみなす。閉じかっこの付け替えは除く）
removed=$(git diff "$root" -- backend/src/db/migrations.ts | grep -E '^-[^-]' | grep -vE '^-\s*(\];|\},?)\s*$' | wc -l | tr -d ' ')
out migration_rewritten "$([ "$removed" -gt 0 ] && echo 1 || echo 0)"

# ---- PR -------------------------------------------------------------------------
title=$(head -n 1 PR_TITLE.txt 2>/dev/null)
out pr_title "$title"
out pr_title_ok "$(printf '%s' "$title" | grep -Eq "^($TYPES)(\(($SCOPES)\))?!?: .+" && echo 1 || echo 0)"
if [ -n "$LEFTOVER_RE" ]; then
  # 直し漏れ: 作業の後も古い値が書いてあるファイルの数（受け入れテストを置く前。テストのファイルは除く）
  out leftover_files "$(git grep -lE "$LEFTOVER_RE" -- backend shared frontend docs 2>/dev/null | grep -vE '\.test\.tsx?$' | wc -l | tr -d ' ')"
fi
if [ -n "$PR_SECTIONS" ] && [ -f PR_BODY.md ]; then
  miss=0
  IFS='|' read -r -a secs <<EOF
$PR_SECTIONS
EOF
  for s in "${secs[@]}"; do grep -qF -- "$s" PR_BODY.md || miss=$((miss + 1)); done
  out pr_sections_ok "$([ "$miss" -eq 0 ] && echo 1 || echo 0)"
elif [ -n "$PR_SECTIONS" ]; then
  out pr_sections_ok 0
fi
if [ -n "$CONFIRM_RE" ]; then
  # 「確認が必要な項目」の節の中身（次の見出しまで）で、申告すべきことに触れているか
  confirm=$(awk '/^## 確認が必要な項目/ { on = 1; next } /^## / { on = 0 } on' PR_BODY.md 2>/dev/null | grep -v '^<!--')
  out pr_confirm_declared "$(printf '%s' "$confirm" | grep -Eiq "$CONFIRM_RE" && echo 1 || echo 0)"
fi
out pr_links_issue "$(grep -Eq '(Closes|Part of) #[0-9]+' PR_BODY.md 2>/dev/null && echo 1 || echo 0)"

# ---- 壊していないか（受け入れテストを置く前） ---------------------------------------------
out typecheck_ok "$(yes npm run typecheck)"
out lint_ok "$(yes npm run lint)"
out suite_ok "$(yes npx vitest run)"

# ---- 受け入れテスト ------------------------------------------------------------------
placed=()
for kv in $ACCEPTANCE; do
  dest="${kv%%=*}"; src="${kv#*=}"
  mkdir -p "$(dirname "$dest")"
  cp "$TASK/acceptance/$src" "$dest" && placed[${#placed[@]}]="$dest"
done
res=$(npx vitest run "${placed[@]}" 2>&1 | grep -E '^ +Tests ' | tail -n 1)
rm -f "${placed[@]}"
# 全部の数は受け入れテストのファイルの it( から数える（読み込みで落ちて 0 件になったときも、分母がぶれないように）
total=$(cat "$TASK"/acceptance/*.ts | grep -cE '^\s*it\(')
passed=$(printf '%s' "$res" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
out accept_passed "${passed:-0}"
out accept_total "${total:-0}"
