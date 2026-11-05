# T3（影響度: 高）の採点の設定
ACCEPTANCE="backend/src/taxi-api.acceptance.test.ts=taxi-api.acceptance.test.ts backend/src/db/taxi-migration.acceptance.test.ts=taxi-migration.acceptance.test.ts shared/src/taxi-csv.acceptance.test.ts=taxi-csv.acceptance.test.ts"
CONFIRM_RE='スキーマ|マイグレーション|テーブル|migration'
SCOPE_RE='^(backend/|shared/|frontend/|docs/|CLAUDE\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'
DOC_CHECKS="requirements=docs/requirements.md openapi=docs/api/openapi.yaml frontend=frontend/src/ textbook=docs/textbook/ troubleshooting=docs/troubleshooting.md progress=docs/PROGRESS.md migration=backend/src/db/migrations.ts database=backend/src/db/database.ts"
PR_SECTIONS='## 概要|## 変更内容|## 確認が必要な項目|## 動作確認の方法|## チェックリスト'
