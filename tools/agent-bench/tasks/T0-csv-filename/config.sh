# T0（影響度: 低）の採点の設定
ACCEPTANCE="shared/src/csv-filename.acceptance.test.ts=csv-filename.acceptance.test.ts shared/src/csv-unchanged.acceptance.test.ts=csv-unchanged.acceptance.test.ts"
# 申告すべきことは無い。スキーマなどを申告していたら「申告しすぎ」として数える（pr_confirm_overdeclared）
CONFIRM_RE=''
OVERDECLARE_RE='スキーマ|マイグレーション|テーブル|migration'
SCOPE_RE='^(shared/|frontend/|docs/|CLAUDE\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'
DOC_CHECKS="requirements=docs/requirements.md troubleshooting=docs/troubleshooting.md textbook=docs/textbook/ progress=docs/PROGRESS.md backend=backend/ migration=backend/src/db/migrations.ts"
PR_SECTIONS='## 概要|## 変更内容|## 確認が必要な項目|## 動作確認の方法|## チェックリスト'
LEFTOVER_RE='routepense-([0-9]{4}-[0-9]{2}|YYYY-MM|\$\{)'
