## 概要
転勤などで使わなくなったルートが、ルートの一覧と出勤の選択肢（日の編集パネル・一括設定・追加の移動）を散らかしていた。削除はすでにできるが、戻せないので押しにくい。そこで、**いつでも戻せる「使わない」にしまう機能**を足した。しまったルートは一覧の「使わないルート（n件）」にまとまり、3か所の選択肢から消える。過去の記録は変わらない。

オーナーが確かめた SPEC（要件の案 Q1〜Q12 のおすすめ）のとおりに作った。SPEC §4 は 4 つの PR に分ける案だったが、この作業は 1 つの Task なので 1 ブランチ・1 PR にまとめた（要件・ADR・DB/API・画面の順にコミットを分けてはいない。レビューは下の「変更内容」の区分で読める）。

Closes #（Task の番号。GitHub に接続できず、番号を確かめられなかったので、PR を作るときに書く）

## 変更内容
- **shared**: `Route` に任意の `archivedAt?: string`。`RouteInput` からは `archivedAt` を外す。`activeRoutes`（使っているルート）・`archivedRoutes`（新しくしまった順）の純粋関数とテスト
- **DB**: マイグレーション v4 `ALTER TABLE routes ADD COLUMN archived_at TEXT`（v1〜v3 は書き換えない）。今までの行は NULL（使っている）。v3 のデータベースに当てても読めるテストあり
- **API**:
  - `PUT /api/routes/:id/archive`（しまう）・`DELETE /api/routes/:id/archive`（戻す）。何度呼んでも 200、無い id は 404。2回目のしまうは日時を変えない
  - `PUT /api/routes/:id`（編集）は `archived_at` に触れない。本文の `archivedAt` は無視する
  - `GET /api/routes` は全件（`archivedAt` 付き）
  - 日の PUT・一括の下見・一括の登録で、しまったルートの `routeId` は 400（`fieldErrors` の `workStyle.routeId`「使わないにしたルートは選べません。ルートの画面で戻してください」）。存在しない `routeId` は今までの文のまま。`resolveWorkStyle` は失敗の理由を持つ判別可能なユニオンを返すようにした
  - `docs/api/openapi.yaml` に 2 つの API と `archivedAt` を足し、`openapi.test.ts` の API の数を 15 → 17 にした
- **画面**:
  - ルートの画面: 「使っているルート」と「使わないルート（n件）」（`<details>`、最初は閉じる。0 件なら出さない）。ボタンは「使わない」「使うに戻す」（確認なし、結果は帯に出す）。しまった切符は地の色を薄くした（`--ticket-archived` を `:root` に足した）。使っているルートが 0 件でしまったルートがあるときの案内文あり
  - 日の編集パネル・一括設定・追加の移動は、使っているルートだけを選択肢に出す（`CalendarPage` が一覧を読むときに `activeRoutes` で絞る）。0 件の文を直した。しまったルートの日を開くと、今までの `buildOptions` のとおりコピーの名前で今の選択として出る
  - `routes-api.ts` に `archiveRoute`・`unarchiveRoute`（テストあり）
- **文書**: `docs/requirements.md`（F1・§4 の図・§5 の Route・決定の記録 U11）、`docs/adr/0004-route-archive.md` と ADR の表、`docs/troubleshooting.md`（新しいエラー文・画面の文・「出勤の選択肢にルートが出ない」）、`docs/PROGRESS.md`

## 自分で決めたこと
SPEC の範囲で、SPEC に書いていなかった細部を決めた。
- **細かい文**: しまう・戻すの帯の文は「「◯◯」を使わないにしました」「「◯◯」を使うに戻しました」。ボタンの名前は「使わない」「使うに戻す」。しまったルートの切符は文字色も `--ink-soft` にした
- **ルートの絞り込みの場所**: 3 か所それぞれで絞らず、`CalendarPage` が一覧を読んだ時点で `activeRoutes` で絞った。下の部品（日の編集パネル・一括設定・追加の移動・一括設定の当てはめ）は「渡されたルートだけを選択肢にする」まま変えていない
- **戻したときの並び**: 一覧の並びは `created_at, id` のままなので、戻したルートは元の位置に戻る。しまったルートの並びは `archivedAt` の新しい順
- **ADR-0003 の「15 個」**: ADR は書き換えない決まりなので、API が 17 個になっても ADR-0003 の文は直していない
- **PR を 1 つにした**: 上の「概要」のとおり

## 確認が必要な項目
**自動マージせず、オーナーの確認を待つ。**
- **DB のスキーマ**: マイグレーション v4（`routes.archived_at`）。main に入れた後は書き換えられない
- **要件定義**: `docs/requirements.md` の F1・§5・決定の記録 U11
- **ADR**: `docs/adr/0004-route-archive.md`（状態は「提案」）

## 動作確認の方法
```bash
npm install
npm run typecheck && npm run lint && npm run test   # 268 件が通る（手元で確認済み）
npm run dev                                         # http://localhost:5173
```
1. 「ルート」の画面でルートを 2 件登録する（「使わない」と「削除」が並ぶ）
2. 片方の「使わない」を押す → 帯に「「◯◯」を使わないにしました」。「使わないルート（1件）」が出る（閉じている。開くと薄い色の切符で「使うに戻す」「削除」がある）
3. 「カレンダー」に移り、日を開く → 出勤のボタン・「一括設定」のルート・「追加の移動」の選択肢に、しまったルートが出ない
4. 先にしまったルートで出勤を入れておいた日を開く → そのルートが押された状態で出る。別の区分を選ぶとそのボタンは消える
5. 「ルート」に戻って「使うに戻す」 → 元の位置に戻り、3 か所の選択肢にまた出る
6. API を直接: しまったルートの `routeId` で `PUT /api/daily-records/2026-11-02` → 400（`workStyle.routeId` に専用の文）。`/api/docs` の Swagger UI にも新しい 2 つの API が出る

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（要件定義も同じ PR で直した）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
