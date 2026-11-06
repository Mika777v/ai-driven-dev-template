# T4（仕様の曖昧な Task）の採点の設定。正解の形を決めないので、自動の採点は「壊していないか」とルールの項目だけ
ACCEPTANCE="backend/src/routes-invariant.acceptance.test.ts=routes-invariant.acceptance.test.ts"
# 要件に無い機能なので、要件の変更（とスキーマを変えたならスキーマ）を申告すべき
CONFIRM_RE='要件|スキーマ|マイグレーション|テーブル'
SCOPE_RE='^(backend/|shared/|frontend/|docs/|CLAUDE\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'
DOC_CHECKS="requirements=docs/requirements.md adr=docs/adr/ openapi=docs/api/openapi.yaml frontend=frontend/src/ troubleshooting=docs/troubleshooting.md progress=docs/PROGRESS.md migration=backend/src/db/migrations.ts"
PR_SECTIONS='## 概要|## 変更内容|## 確認が必要な項目|## 動作確認の方法|## チェックリスト'
# 差分の中身で見ること（名前=正規表現。1行に1つ）
DIFF_CHECKS='keeps_data=^\+.*(ALTER TABLE routes ADD COLUMN|archived|hidden|is_active|active)
hides_in_selection=^\+\+\+ b/frontend/src/calendar/'
