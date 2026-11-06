## 概要
ルートの一覧に同じ名前（「自宅↔本社」）が2つあり、出勤を選ぶときに見分けられなかったため、同じ名前のルートを登録できないようにする。名前が重なると `POST /api/routes` は登録せずに 409 を返す。編集で、ほかのルートと同じ名前に変えることも止める。

Closes #<この Task の番号>

## 変更内容
- `POST /api/routes`: 入力の検証（400）の後、同じユーザーに trim 後の名前が完全に同じルートがあれば 409。本文は `{ error: "同じ名前のルートがあります", fieldErrors: [{ field: "name", message: "同じ名前のルートがあります" }] }`
- `PUT /api/routes/:id`: 検証（400）→ 対象が無ければ 404 → 名前を変えて、かつ自分以外に同じ名前があれば 409。名前を変えない編集は、すでに重なっているルートでも 200
- `RouteRepository.findByName(userId, name): Route[]` を追加（`SqliteRouteRepository` で実装）
- 画面（frontend）のコードは変更なし。409 でも `fieldErrors` の `field: "name"` が既存の `toRouteFormErrors` でルート名の欄の下に出る
- テスト: ルート API（409・空白つき・400 が先・404 が先・削除後に再利用・既存の重なり）、repository、`toRouteFormErrors`
- 文書: `docs/requirements.md`（F1・§5 バリデーション・U11）、`docs/api/openapi.yaml`（409 と `components/responses/Conflict`）、`docs/troubleshooting.md`（画面の文・ステータスの表）、`docs/PROGRESS.md`

## 確認が必要な項目
**自動マージは予約しない。**
- 要件定義の変更: `docs/requirements.md` の F1・§5・U11 の追加

## 自分で決めたこと
- 編集（PUT）でも、名前を変えて重なる場合は 409 にした（Task の文は POST だけだが、編集で抜け道が残ると目的が守れないため）。名前を変えない編集は、すでに重なっている2件でも通す
- 比べるのは trim 後の完全一致。大文字小文字・全角半角・記号はそろえない（`Home` と `home`、`自宅↔本社` と `自宅<->本社` は別の名前）
- すでにある「自宅↔本社」2件のデータは書き換えない。オーナーが画面の編集で片方の名前を変える
- DB の一意制約・マイグレーションは足さない（今のデータに重なりがあり失敗するため。個人利用・同期処理で、API で調べてから登録する間に割り込みは入らない）。スキーマを変えないので ADR は書いていない
- 409 の `error` も「同じ名前のルートがあります」（400 と見分けやすくするため）
- repository のメソッドは `findByName(userId, name): Route[]`。既存の重なりがあるので 1 件ではなく配列で返し、router 側で `excludeId` 相当（`id !== 自分`）を判定する
- 消したルートの名前は再利用できる（物理削除のため、何もしなくてよい。テストで確認）

## 動作確認の方法
- `npm run typecheck && npm run lint && npm run test`（すべて通過。261 件）
- 画面: ルートの登録フォームに既存の名前を入れて登録すると、「ルート名」の欄の下に「同じ名前のルートがあります」が出て、入力した値が残る。編集フォームでも同じ
- **注意: 画面の実機確認はこの環境では行っていない。** 画面側は既存コードが 409 でも動く見込みで、`toRouteFormErrors` のテストで形だけ固定した。マージ前にオーナーの確認をお願いしたい

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（要件定義を更新した）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
