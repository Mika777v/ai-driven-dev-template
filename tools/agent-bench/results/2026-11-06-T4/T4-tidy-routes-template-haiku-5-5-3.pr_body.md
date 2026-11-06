## 概要

転勤で使わなくなったルートを、削除せずに「しまう」（アーカイブ）ことができるようにした。しまったルートは一覧の「しまっているルート」の枠に分け、一括設定・日の編集・追加の移動の選択肢から外す。「戻す」で、また選べるようになる。削除は今まで通り残す。

理由: ルートの一覧と出勤の選択肢が増えてごちゃごちゃしていた。削除は取り消せず、転勤で戻るかもしれないルートを消すと再登録になる。決めた経緯は `docs/adr/0004-archive-routes.md`。

Closes #（Task の番号は未確認。GitHub に接続できないため空けてある。オーナーが番号を入れてください）

## 変更内容

- **shared**: `Route` に `archived?: true` を足す（しまったときだけ項目を付ける。`searchUrl` と同じ書き方）。`RouteInput` からは外した（しまう・戻すは専用の API で行う）
- **DB**: マイグレーション v4 で `routes.archived_at` を足す（NULL = 使っているルート）
- **backend**
  - `RouteRepository.setArchived`（SQLite 実装は `sqlite-route-repository.ts`）
  - `POST /api/routes/{id}/archive`・`POST /api/routes/{id}/restore`。結果のルートを返し、無ければ 404
  - 編集してもしまった印は変わらない。しまったルートも、編集・削除できる
- **API の仕様書**: `docs/api/openapi.yaml` に2つの API と `Route.archived` を書き足した。`openapi.test.ts` の件数を 15 → 17 に
- **frontend**
  - ルートの画面: 「使っているルート」と「しまっているルート」に分けて出す。切符の下のボタンは「しまう」か「戻す」（戻せるので確認は出さない）
  - 月次画面: 一括設定・日の編集・追加の移動に渡すルートを `choosableRoutes` で絞る
  - `frontend/src/routes/route-archive.ts`: `splitRoutes`・`choosableRoutes`（純粋関数。テストあり）
  - 切符の薄い表示（`.ticket.is-archived`）
- **docs**: 要件 F1・データ項目・決定の記録 U11（`docs/requirements.md`）、ADR-0004 と ADR の一覧、`docs/troubleshooting.md` に1行、`docs/PROGRESS.md`

## 確認が必要な項目

- **DB のスキーマの変更**: `routes` に `archived_at`（TEXT・NULL 可）の列を足す（マイグレーション v4）。列を足すだけで、既存の行とデータは動かさない。既存のルートは使っているルートのまま残る
- **要件定義の変更**: `docs/requirements.md` の F1・データ項目（`archived`）・U11
- **ADR の追加**: `docs/adr/0004-archive-routes.md`（削除ではなくしまう。まとめて削除は見送った）

上の3つに当てはまるので、自動マージは予約していない。オーナーが読んでからマージしてください。

## 自分で決めたこと

- **片付けの形**: 複数のルートをまとめて削除する機能ではなく、「しまう」（戻せる）を選んだ。まとめて削除は取り消せない操作を増やすため見送った（ADR-0004）
- **印の付け方**: 列 `archived_at` の有無で持つ。API の JSON は、しまったときだけ `archived: true` を付ける（使っているルートには項目が無い。`searchUrl` と同じ）
- **API は専用の2本**: `archive`・`restore`（POST）にした。PUT の入力（`RouteInput`）には入れない。編集で、しまった印が変わったり戻ったりしないようにするため
- **絞り込みの場所は画面側**: `choosableRoutes`。API は今まで通り全部のルートを返す（API 側で絞ると、ルートの一覧に別の使い方が出来なくなるため）
- **しまう操作に確認は出さない**: 戻せるため。削除の確認は今まで通り
- **記録は変えない**: 記録は `routeId` とコピーした値を持つので、しまっても金額と区間は変わらない。しまったルートを使っていた日は、記録の名前（「出勤（…）」）で今の選択として出る
- **既知の小さな不具合（今回は直さない）**: 追加の移動の「登録済みのルートから選ぶ」で、しまったルート（または削除したルート）を使っていた既存の追加の移動を直すと、選択欄の表示が「手で入力する」に見える。値は変わらない。ADR-0004「影響」に書いた

## 動作確認の方法

```bash
npm install
npm run typecheck && npm run lint && npm run test   # 261 件（追加分 11 件を含む）
npm run build -w frontend                            # 画面のビルドも通る
npm run dev
```

画面で確かめること（**この PR を作った環境では、画面を実際に開いて手で確かめてはいない**。テストと型チェック、ビルドまで）:

1. ルート画面で、ルートを1件「しまう」→「しまっているルート」の枠に移り、通知が出る
2. 月次画面の日の編集パネルと一括設定の出勤の選択肢に、しまったルートが出ないこと。しまう前にそのルートを使った日は、記録の名前で「出勤（…）」と出ること
3. ルート画面で「戻す」→ 上の枠に戻り、選択肢にも出ること
4. API: `curl -X POST http://localhost:3000/api/routes/<id>/archive` → 200 で `"archived":true`。無い id は 404

## チェックリスト

- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（F1・データ項目・U11 を更新した）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)
