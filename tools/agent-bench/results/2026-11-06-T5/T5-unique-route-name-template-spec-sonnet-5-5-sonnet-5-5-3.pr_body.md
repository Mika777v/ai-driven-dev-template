## 概要
ルートの一覧に同じ名前（「自宅↔本社」）が2つあり、出勤を選ぶときに区別できなかった。`POST /api/routes` と `PUT /api/routes/:id` で、同じ名前のルートを 409 で弾く。

Closes #（Task の番号）

## 変更内容
- `RouteRepository.existsByName(userId, name, exceptId?)` を追加（SQLite 実装とテスト付き）
- `POST /api/routes`: 検証（400）の後、同名があれば 409。本文は `{ error: "入力に誤りがあります", fieldErrors: [{ field: "name", message: "同じ名前のルートがあります" }] }`
- `PUT /api/routes/:id`: 400 → 404 → 409 の順。自分以外に同名があれば 409
- 画面: コードの変更なし。`api-client.ts` は 409 でも本文の `ApiError` を返し、`toRouteFormErrors` が `name` をルート名の欄の下に出す（`routes-api.test.ts`・`route-form.test.ts` で確認）
- 文書: `docs/api/openapi.yaml`（`Conflict` 応答）、`docs/troubleshooting.md`（メッセージ・409）、`docs/requirements.md` F1、`docs/PROGRESS.md`

## 自分で決めたこと
- 編集（PUT）でも弾く（抜け道を残さないため）。名前を変えずに他の欄だけ直しても、自分以外に同名が残っていれば 409（規則を単純に保つ。直すには名前を変えればよい）
- 「同じ名前」は前後の空白を除いた完全一致（大文字小文字・全角半角は区別する）
- DB の UNIQUE 制約は付けず、アプリ側で判定する。理由: 1人・1プロセスで `node:sqlite` は同期なので競合の心配が小さい。すでに同名のルートがある DB では UNIQUE の migration が失敗して起動できなくなり、戻しにくい。スキーマを変えないので ADR は書いていない。複数ユーザー化や DB 差し替えのときに `UNIQUE (user_id, name)` を足せばよい
- すでにある同名のルートは自動では改名・削除しない（どちらを残すかは本人しか分からない）。一覧に残り、編集・削除はできる
- `error` は 400 と同じ「入力に誤りがあります」にした（画面の既存の出し方をそのまま使うため）

## 確認が必要な項目
- 要件定義（`docs/requirements.md` F1）を変更している（「ルート名は、同じ人のルートの中で重ならない」を追加）。自動マージせず、オーナーの確認を待つ

## 動作確認の方法
- `npm run typecheck && npm run lint && npm run test`（通ることを確認済み）
- 画面: 同じ名前でルートを登録すると、ルート名の欄の下に「同じ名前のルートがあります」が出て、他の欄の入力は残る。名前を直して再送すると登録できる（画面での手動確認はしていない）

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
