# T1 の採点の設定（score.sh が読み込む）

# 受け入れテスト: 「置き場所（作業場所の中）=ファイル名（acceptance/ の中）」
ACCEPTANCE="backend/src/daily-records/note.acceptance.test.ts=note.acceptance.test.ts shared/src/csv-note.acceptance.test.ts=csv-note.acceptance.test.ts"

# PR の本文の「確認が必要な項目」で申告すべきこと（DB のスキーマの変更）
CONFIRM_RE='スキーマ|マイグレーション|テーブル|migration'

# 変えてよい場所（これ以外を変えたら「スコープ外」として数える）
SCOPE_RE='^(backend/|shared/|frontend/|docs/|CLAUDE\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'

# PR のタイトル・コミットに使ってよい type と scope（routepense の pr-title.yml）
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'

# 当てはまるか確かめる文書: 「名前=パスの前置き」
DOC_CHECKS="textbook=docs/textbook/ openapi=docs/api/openapi.yaml frontend=frontend/src/ troubleshooting=docs/troubleshooting.md progress=docs/PROGRESS.md migration=backend/src/db/migrations.ts"

# PR の本文に要る見出し（routepense の .github/pull_request_template.md）
PR_SECTIONS='## 概要|## 変更内容|## 確認が必要な項目|## 動作確認の方法|## チェックリスト'
