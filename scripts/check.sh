#!/usr/bin/env bash
# PR の前にまとめて流す確認（型チェック・lint・テスト）。手元でも CI（.github/workflows/ci.yml）でも同じものを使う。
# プロジェクトに合わせて、下の「ここに書く」を埋める。どれかが失敗したら止まる。
#
# 使い方:
#   bash scripts/check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# --- ここに書く（例） ---------------------------------------
# npm run typecheck && npm run lint && npm run test
# ruff check . && ruff format --check . && pytest
# ./gradlew build
# ------------------------------------------------------------

echo "==> markdown の差し替え漏れ（{{...}}）の確認"
# テンプレートのままの値が残っていても CI は落とさない。導入が終わったら、下の行の "|| true" を消して必須にする
bash scripts/find-placeholders.sh || true

echo "done"
