## 概要
転勤で使わなくなったルートが、ルートの一覧と出勤などの選択肢を散らかしている。削除は既にあるが戻せないため、**消さずに「しまう」（あとで戻せる）** を足した。しまったルートは、ルート画面では畳んだ「しまったルート」に分け、月次画面の出勤・追加の移動・一括設定の選択肢には出さない。

Closes #（Task の番号。GitHub に接続できず、Issue を探せなかったため空欄。push 前に埋める）

## 変更内容
- DB: マイグレーション version 4 で `routes.archived_at`（NULL なら使用中）を追加
- shared: `Route.archived?: boolean`（しまっているときだけ true）と、選択肢用の純粋関数 `activeRoutes`
- backend: `POST /api/routes/{id}/archive`・`/unarchive`。`GET /api/routes` はしまったルートも返す。編集してもしまったまま
- frontend: ルート画面の切符に「しまう / 戻す」ボタン、畳んだ「しまったルート（N件）」。月次画面にはしまっていないルートだけ渡す。しまったルートを使っている日は、日の編集パネルに今の選択として残る（既存の処理）
- docs: ADR-0004、要件定義 F1・U11、`openapi.yaml`（API 15 → 17 個）、`troubleshooting.md`、`PROGRESS.md`
- テスト: リポジトリ・API・フロントの API 呼び出し・`activeRoutes` を追加

## 自分で決めたこと
- **削除ではなく「しまう」を作った**: 依頼は「片付けたい」で、削除は既にある。戻せる方が、また通うルートに安全だと判断（選択肢は ADR-0004）
- しまったルートも `GET /api/routes` に含める（ルート画面で戻すため）。選択肢から外すのは画面側（`activeRoutes`）
- backend の記録の保存は、しまったルートを**弾かない**。しまったルートの日を開き直して保存し直せるようにするため
- 「しまう」は `PUT` ではなく専用の `POST` にした（編集の欄ではなく操作のため。本文の検証が要らない）
- 「しまう」の確認ダイアログは出さない（戻せるため）。画面上部のお知らせに結果を出す
- 「しまったルート」は `<details>` で畳み、最初は閉じておく

## 確認が必要な項目
**自動マージせず、オーナーの確認を待つ**（次に当てはまる）
- ADR: `docs/adr/0004-archive-routes.md`（選択肢 A 削除だけ / B 列を足す / C 画面だけで隠す → B）
- DB のスキーマ: `backend/src/db/migrations.ts` の version 4（列を1つ足すだけ。既存の行は NULL＝使用中）
- 要件定義: `docs/requirements.md` の F1 と決定 U11

## 動作確認の方法
1. `npm run typecheck && npm run lint && npm run test`（259 件すべて通過）
2. `npm run dev` → 「ルート」画面でルートを2つ登録し、片方の「しまう」を押す
   - 一覧から消えて、下の「しまったルート（1件）」に畳まれる。開くと「戻す」が出る
3. 「カレンダー」画面で日をクリック → 出勤の選択肢と、一括設定・追加の移動のルート選択に、しまったルートが出ない
4. しまったルートで出勤にしていた日は、変わらず表示される。「戻す」で選択肢に戻る

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（U11 を足して合わせた）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
