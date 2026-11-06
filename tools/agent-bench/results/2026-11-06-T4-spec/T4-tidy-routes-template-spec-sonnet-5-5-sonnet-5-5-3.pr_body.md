## 概要
転勤で使わなくなったルートが、ルート管理の一覧と出勤の選択肢に残ってごちゃごちゃする問題に対応する。削除（取り消せず `searchUrl` も失う）の代わりに、**戻せる「使わない」状態（アーカイブ）**を足し、一覧と選択肢から隠す。経緯と選択肢は ADR-0004、要件は `docs/requirements.md` の F1・U11。

Closes #<Task の番号>
<!-- Task の Issue 番号が分からなかったので空けてある。PR を作るときに入れる -->

## 変更内容
- **DB**: migration version 4 で `routes.archived_at`（NULL = 使っている）を追加。既存のルートは全部「使っている」のまま
- **型**: `Route` に `archived: boolean`。`RouteInput`・`RouteSnapshot` には入れない
- **API**（`docs/api/openapi.yaml` も更新）
  - `GET /api/routes` は既定で使っているルートだけ。`?includeArchived=true` で全部
  - `POST /api/routes/:id/archive`・`/restore`（204 / 無ければ 404 / すでにその状態でも成功）
  - `PUT /api/routes/:id` は使わないルートなら 409。`DELETE` は使わないルートにも使える
  - 日次記録の作成・更新、一括設定の下見・登録で、使わないルートの `routeId` は 400（`routeId` のフィールドエラー）。`resolveWorkStyle` が理由（`notFound` / `archived`）を返す形にした
- **画面**
  - ルート管理: 各ルートに「使わない」ボタン（確認なし、実行後に「元に戻す」）。一覧の下に折りたたみ「使わないルート（N件）」（「戻す」「削除」）
  - 出勤の選択肢（日の編集パネル・一括設定・追加の移動）は `GET /api/routes` の既定の挙動で使わないルートが出なくなる。日の編集パネルは、その日の記録が使っているルートだけ従来どおり残る（`buildOptions` は変更なし）
- **文書**: ADR-0004（新規）と ADR 一覧、要件定義（F1・Route・U11・画面の流れ）、`troubleshooting.md`（409 と 400 の文）、`PROGRESS.md`
- **テスト**: リポジトリ（archive / restore / 一覧の絞り込み・冪等・編集不可）、ルーター（各ステータス）、`resolveWorkStyle`、日次記録・一括設定の 400、migration 4（version 3 の DB から上げる）、フロントの API クライアントと `splitByArchived`、`openapi.test.ts`（API 17 個）

## 自分で決めたこと
オーナー確認済みの SPEC（おすすめ案）に沿った。SPEC に細かく書かれていなかった点:
- **1 つの PR にまとめた**。SPEC は「① ADR・要件・DB・API → ② 画面」の 2 PR を案としていたが、この環境では PR をマージ待ちできず、①だけだと画面が使わないルートを読めない（②が `includeArchived` に依存）ので、一続きで出す。分けたい場合は、フロントの変更（`frontend/` と `styles.css`）を別ブランチに切り出せる
- `archive` を 2 回呼んでも `archived_at` は上書きしない（`COALESCE`）。`updated_at` は archive / restore では変えない（ルートの内容を編集したわけではないため）
- `PUT` の判定順は 400（入力の誤り）→ 404（無い）→ 409（使わない）。`update` の SQL も `archived_at IS NULL` を条件にして、判定の間に変わっても編集されないようにした
- `routeId` のエラー文: 「このルートは使わない設定になっています」（SPEC どおり）。見つからない文は従来のまま
- 「元に戻す」は、通知の行に出すリンク風のボタン。別の操作（保存・編集・削除・戻す）をすると消える
- ルート管理画面だけ `includeArchived=true` で読み、`splitByArchived`（純粋関数）で 2 つの一覧に分ける

## 確認が必要な項目
**自動マージせず、オーナーが読んでからマージする。**
- **ADR**: `docs/adr/0004-archive-routes.md`（新規。削除のみ / `archived_at` 列 / 別テーブル / 真偽値の比較）
- **DB のスキーマ**: `routes.archived_at` の追加（migration 4）。追加のみで既存データは壊れないが、main に入れた後の直しは migration 5 になる
- **要件定義**: `docs/requirements.md` の F1・Route・決定の記録 U11

## 動作確認の方法
- `npm run typecheck && npm run lint && npm run test` が通る（37 ファイル 275 テスト、手元で確認済み）
- `npm run dev` で `http://localhost:5173` を開く（**画面は手元でブラウザ確認できていない**。型・lint・テストのみ。確認をお願いしたい）
  1. ルート管理で 2 件以上登録し、片方の「使わない」を押す → 一覧から消え、通知に「元に戻す」が出る。下の「使わないルート（1件）」を開くと入っている。再読み込みしても保たれる
  2. 月次画面の日の編集パネル・一括設定・追加の移動に、使わないルートが出ない
  3. 使わないルートで作った記録の日を開く → ルート名・金額はそのまま、選択肢にもその日のぶんだけ残る。月の合計・CSV は変わらない
  4. 「戻す」→ 一覧と選択肢に戻る。「削除」は確認付き
  5. API: `curl -X POST localhost:3000/api/routes/<id>/archive` → 204、その後に `PUT` → 409、`/api/daily-records/<日付>` に `routeId` を送ると 400

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（要件定義も同じ PR で更新）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
