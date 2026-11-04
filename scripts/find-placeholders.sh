#!/usr/bin/env bash
# テンプレートの差し替え漏れ（{{PROJECT_NAME}} のような大文字の値）を探す。
# GitHub Actions の ${{ ... }} は小文字・空白を含むので引っかからない。
# 見つかったら一覧を出して終了コード 1、無ければ 0。
#
# 使い方:
#   bash scripts/find-placeholders.sh
set -uo pipefail

cd "$(dirname "$0")/.."

PATTERN='\{\{[A-Z0-9_]+\}\}'

# このスクリプト自身と、説明のために値の名前を並べている文書は除く
if grep -rnE "$PATTERN" . \
    --exclude-dir=.git \
    --exclude=find-placeholders.sh \
    --exclude=PROJECT_BOOTSTRAP_CHECKLIST.md; then
  echo ""
  echo "上の {{...}} を、プロジェクトの値に差し替えてください（docs/PROJECT_BOOTSTRAP_CHECKLIST.md §0）"
  exit 1
fi

echo "差し替え漏れはありません"
