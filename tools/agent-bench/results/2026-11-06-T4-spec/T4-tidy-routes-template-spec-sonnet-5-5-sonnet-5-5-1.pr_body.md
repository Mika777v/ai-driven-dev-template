## 概要
転勤で使わなくなったルートが、ルートの一覧と出勤の選択肢に残ってごちゃごちゃする。削除は戻せないので、**消さずに「使わない」にして、戻せる**ようにする（ADR-0004・要件定義 U11）。
オーナーが確かめた SPEC（Q1 の A を採用）のとおりに実装した。

Closes #（Task の番号。GitHub に接続できず確かめられなかったので、PR を作るときに書く）

## 変更内容
- **DB**: マイグレーション 4 `ALTER TABLE routes ADD COLUMN archived_at TEXT`（足すだけ。既存の行は NULL＝使う）
- **共有の型**: `Route` に `archived: boolean`。`RouteInput` には入れない。`RouteSnapshot` は変更なし
- **API**
  - `GET /api/routes` は既定で使うルートだけ。`?includeArchived=true` で全件。ほかの値は 400
  - `PATCH /api/routes/:id` `{ archived: boolean }`（べき等。無い id は 404、真偽値でなければ 400）
  - 使わなくなったルートへの `PUT` は 409。`DELETE` は今までどおり
  - 使わなくなったルートを出勤に指定する `PUT /daily-records/:date`・`POST /bulk`・`POST /bulk/preview` は 400「このルートは使わなくなっています」（見つからないときの文とは別）
  - `resolveWorkStyle` の戻り値を判別可能なユニオン型（`ok` / `reason: routeNotFound | routeArchived`）にした
  - `RouteRepository` に `setArchived`、`list` に `includeArchived`
- **画面**: ルート管理画面は全件を読み、「使わなくする」ボタン（確認なし）と、一覧の下の折りたたみ枠「使わなくなったルート（N件）」（最初は閉じる・0件なら出さない。中は「元に戻す」と「削除」のみ）。月次画面（`listRoutes` 既定のまま）は、出勤・一括設定・追加の移動の 3 か所の選択肢が自動で減る。コードの変更なし
- **文書**: ADR-0004（新規）、`adr/README.md`、`requirements.md`（F1・データの項目・U11）、`openapi.yaml`、`troubleshooting.md`、`PROGRESS.md`
- **テスト**: リポジトリ（両方向・includeArchived・べき等・他ユーザー）、マイグレーション（version 3 の DB に 4 を適用しても行が残る）、route-router（PATCH・PUT 409・GET クエリ）、`resolveWorkStyle`、daily-records / bulk のルーター（400）、フロントの `splitByArchived`・`routes-api`。`openapi.test.ts` の API 数を 16 に更新

## 確認が必要な項目
**自動マージを予約しない。** 次に当たる。
- **ADR**: `docs/adr/0004-archive-routes.md`（選択肢 A/B/C と、真偽値列 vs `archived_at` の比較）
- **DB のスキーマ**: マイグレーション 4（`routes.archived_at`）
- **要件定義**: `docs/requirements.md`（F1・データの項目・U11・更新日）

### 自分で決めたこと
- **PR を 1 つにまとめた。** SPEC の提案は「文書 → バックエンド → フロント」の 3 PR だが、GitHub に接続できず前の PR のマージを待てない（順番に依存するため）。オーナーが内容を確かめ済みなので 1 つにした。コミットは 1 つ。レビューしにくければ、3 つのブランチに分けて出し直せる
- Q6（すでに記録にある日の、使わなくなったルートの出勤を再保存）は SPEC のおすすめ①（弾く）。ただしパネルは現在の選択を選択済みにしていて、同じ選択を押しても API を呼ばない（`isSameChoice`）ので、実際に 400 が出る場面はほぼ無い。②への切り替えは不要と判断した
- 再度 `archived: true` にしても、最初に使わなくした日時（`archived_at`）を保つ（`COALESCE`）
- PATCH の 400 の本文は他と同じ `入力に誤りがあります` ＋ `fieldErrors[archived]`。`PUT` の 409 の文は SPEC のとおり
- `setArchived` は `updated_at` も更新する
- 「使わなくする」ボタンは `quiet` クラス（削除の赤より控えめ）。使わなくなったルートのチケットは少し薄く表示
- 使うルートが 0 件で使わなくなったものだけあるときは、「使うルートがありません。下の『使わなくなったルート』から元に戻せます。」と出す（SPEC Q5 は、出勤側の「ルートが無いので…」を変えない、という意味で、ルート管理画面の案内だけを足した）

## 動作確認の方法
- `npm install && npm run typecheck && npm run lint && npm run test`（手元で通った: 36 ファイル・272 テスト）
- `npm run dev` でルートを 2 件登録 → 「使わなくする」で下の枠「使わなくなったルート（1件）」に移る（確認なし）→ 画面を読み直しても残る
- カレンダーで日をクリック／一括設定／追加の移動の「ルートから選ぶ」に、使わなくしたルートが出ない。「元に戻す」で出る
- 使わなくしたルートで出勤にした日は、ルート名・金額・月の合計が変わらない。枠内の「削除」→ 確認 → 記録は変わらない
- 既存の DB（version 3）で起動すると、データを残したまま version 4 になる（テストでも確認）
- 画面（ブラウザ）での目視は、この環境ではしていない（テストとタイプチェックのみ）

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（要件定義も同じ PR で更新）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
