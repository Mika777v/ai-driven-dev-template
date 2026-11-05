# T2（T1 の続き）の採点の設定（score.sh が読み込む）

# 続きの Task: 前の作業の結果（bases/<名前>.diff）を土台にする。条件の名前は from-<名前>
BASES="template bare"
# 前の作業の土台を作ったときの条件（その diff は、この条件の作業場所に対して作られている）
BASE_TREATMENT_template=template
BASE_TREATMENT_bare=bare

ACCEPTANCE="backend/src/daily-records/note.acceptance.test.ts=note.acceptance.test.ts shared/src/csv-note.acceptance.test.ts=csv-note.acceptance.test.ts shared/src/csv-note-row.acceptance.test.ts=csv-note-row.acceptance.test.ts"

# DB のスキーマは変わらないので、申告の確認はしない
CONFIRM_RE=''

SCOPE_RE='^(backend/|shared/|frontend/|docs/|CLAUDE\.md$|PR_TITLE\.txt$|PR_BODY\.md$)'
TYPES='feat|fix|docs|refactor|perf|test|build|ci|chore|revert'
SCOPES='frontend|backend|shared|db|docs|textbook|ci|deps'

# 「200 文字と書いてあるところはすべて 100 文字に」: 直したか確かめる文書
DOC_CHECKS="requirements=docs/requirements.md openapi=docs/api/openapi.yaml frontend=frontend/src/ textbook=docs/textbook/ troubleshooting=docs/troubleshooting.md"

# 続きの作業場所には PR テンプレートが無いので、見出しは確かめない
PR_SECTIONS=''

# 直し漏れ: 作業の後も「200 文字」「200文字」が残っているファイルの数（テストと CHANGELOG 風の履歴は除く）
LEFTOVER_RE='200 ?文字'
