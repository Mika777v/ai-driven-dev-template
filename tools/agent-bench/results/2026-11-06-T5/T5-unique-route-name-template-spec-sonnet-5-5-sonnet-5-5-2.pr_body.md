## 概要
ルートの一覧に同じ名前（例: 「自宅↔本社」）が2つ並び、出勤を選ぶときに区別できなくなった。同じ名前のルートは登録できないようにする（409）。

Closes #<Task の番号>
<!-- 番号が分からなかったため、マージ前に埋める -->

## 変更内容
- `POST /api/routes`: 同じ `userId` に同じ名前（前後の空白を除いた完全一致）があれば、登録せずに 409。本文は 400 と同じ形（`error: "入力に誤りがあります"`、`fieldErrors: [{ field: "name", message: "同じ名前のルートがあります" }]`）。形の誤り（400）は重複の確認より先
- `RouteRepository.findByName(userId, name, exceptId?)` を追加（SQLite 実装つき）
- 画面: 実装の変更なし。`api-client` がステータスに関係なく `fieldErrors` を返し、`toRouteFormErrors` が `name` の欄の下に出す。409 でも同じことをテストで確認
- `docs/api/openapi.yaml`（POST・PUT に 409 / `DuplicateRouteName`）、`docs/troubleshooting.md`（画面のメッセージと API のステータスに 409）、`docs/PROGRESS.md` を更新

## 自分で決めたこと（Task に書いていない点）
- **`PUT /api/routes/:id` も止める**（他のルートと同じ名前に変えると 409。自分の名前のままの保存は 200、無い id は 404 を先に返す）。編集で同名にできると登録で止めた意味が無くなるため。依頼の範囲を少し広げている
- 「同じ名前」は前後の空白を除いた完全一致。全角/半角・大文字小文字は同じとはみなさない
- **DB の UNIQUE 制約・マイグレーションは入れない**（アプリで保存前に確認する）。今の DB に既存の重複がある可能性が高く、UNIQUE を足すと起動に失敗しうる。必要になったら既存データの整理方針と一緒に別 Task（ADR つき）にする。同期 API の `node:sqlite` で利用者は1名なので、確認と保存の間に割り込みは入らない
- 既存の重複ルートは自動で直さない・警告も出さない。画面から名前を変える・削除する。重複したままの片方の他の項目だけを直すときも名前が同じなので 409 になる（troubleshooting に記載）
- `error` の文は 400 と同じ「入力に誤りがあります」のまま（フロントは `fieldErrors` があれば使わない）
- 重複は同じ `userId` の中だけで判定する
- ADR は書かない（アプリでの確認は戻しやすい判断）

## 確認が必要な項目
なし（DB のスキーマ・要件定義・ADR・`shared/` の型は変えていない）。
補足: `docs/requirements.md` の F1 に「ルート名は、同じ人の中で重複できない（前後の空白を除いた完全一致）」を足すのがよい。要件定義の変更になるので、この PR には含めず、別 PR（オーナーの確認待ち）にする。

## 動作確認の方法
- `npm run typecheck && npm run lint && npm run test`（通過済み。257 件）
- 画面: ルートを登録 → 同じ名前でもう一度登録すると、ルート名の欄の下に「同じ名前のルートがあります」が出る。名前を変えて再送信すると登録できる
- API: 同じ名前で `POST /api/routes` → 409、`GET /api/routes` の件数は増えない

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [ ] 要件定義（docs/requirements.md）と食い違っていない（F1 への1行追記は別 PR）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.ai/code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
