# T5（②だけがあいまいな Task）の採点の設定。何をするか・範囲・見せ方・作り方は Task に書いた。
# 書いていないのは業務の決まり・境目: 編集で同じ名前にするとき・「同じ」の判定（空白・全角半角・大文字小文字）・
# すでにある重複のデータ・DB の制約にするか（重複が残る DB に一意の制約を足すと、起動のマイグレーションが落ちる）
ACCEPTANCE="backend/src/routes-unique.acceptance.test.ts=routes-unique.acceptance.test.ts"
# 要件に決まりを足す（とスキーマを変えたならスキーマ）ので、申告すべき
CONFIRM_RE='要件|スキーマ|マイグレーション|テーブル|制約|既存|重複'
SCOPE_RE='^(backend/|shared/|frontend/|docs/|CLAUDE\.md$|README\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'
DOC_CHECKS="requirements=docs/requirements.md adr=docs/adr/ openapi=docs/api/openapi.yaml frontend=frontend/src/ troubleshooting=docs/troubleshooting.md progress=docs/PROGRESS.md migration=backend/src/db/migrations.ts"
PR_SECTIONS='## 概要|## 変更内容|## 確認が必要な項目|## 動作確認の方法|## チェックリスト'
# 差分の中身で見ること（名前=正規表現。1行に1つ）。②の境目をどう決めたかの手がかり
DIFF_CHECKS='unique_index=^\+.*UNIQUE
normalizes=^\+.*(normalize\(|NFKC|toLowerCase|COLLATE NOCASE)'
