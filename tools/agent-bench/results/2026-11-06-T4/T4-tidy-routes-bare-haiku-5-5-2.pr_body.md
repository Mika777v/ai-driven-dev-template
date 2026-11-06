## 何をしたか

転勤で使わなくなったルートを、**アーカイブ**で片付けられるようにしました。

- アーカイブしたルートは、ルート画面の一覧の下に「アーカイブ済み（N件）」として畳んで置く（普段は閉じている）
- アーカイブしたルートは、出勤・追加の移動・一括設定の選択肢に出ない
- 「使うルートに戻す」で、いつでも戻せる
- ルートの中身と過去の記録は変わらない（記録は今までどおり、記録したときの値のコピーで表示する）

既存の「削除」は残しています。削除は取り消せないので、片付けには「アーカイブ」を使う想定です。

## 自分で決めたこと（オーナーの確認をお願いします）

1. **削除ではなくアーカイブにした**（ADR-0004）。削除は既にあり、取り消せない。「今は使わないが戻すかもしれない」ルートまで消すのは重いと判断しました。
2. **印は `routes` テーブルの列（`archived`）にした。** 別テーブルへの移動（C）は、今の規模には大げさと判断しました。マイグレーションは version 4。既存の行は `archived = 0`（使う）になり、古い DB を開く試験で確かめています。
3. **API は `PUT /api/routes/:id/archived` に `{ "archived": boolean }`。** 編集（PUT /api/routes/:id）とは分けました。編集でアーカイブの状態が変わらないようにするためです。
4. **`GET /api/routes` はアーカイブしたルートも返す。** 畳むのは画面の役目。そのため `Route.archived` は必須の項目にし、`RouteInput` からは外しました（編集で送らない）。
5. **記録の作成（`routeId` を送る API）は、アーカイブしたルートも今どおり受け付ける。** 選択肢に出さないことで画面からは選べなくなります。API を使う側を壊さないための判断です。
6. **選択肢からの除外は月次画面で行う。** `CalendarPage` がルートを読むときに、アーカイブしたものを外します。そのため出勤・追加の移動・一括設定の選択肢は、同じ一覧から作られます。アーカイブ済みのルートが今の日の選択だった場合は、既存の処理（記録のコピーの名前で出す）で表示されます。

## 変更の内容

- **shared**: `Route.archived: boolean`（必須）。`RouteInput` は `archived` を含まない
- **backend**
  - `migrations.ts`: version 4（`routes.archived INTEGER NOT NULL DEFAULT 0`）
  - `sqlite-route-repository.ts`: 読み書きに `archived` を足す。`setArchived` を追加。編集後は DB を読み直して返す
  - `parse-archived-input.ts`（新規）: `{ archived }` の受け口の検証（真偽値だけ受け付ける）
  - `route-router.ts`: `PUT /:id/archived`
- **frontend**
  - `route-archive.ts`（新規）: `usableRoutes`（選択肢用）・`splitByArchived`（画面用）の純粋関数
  - `RoutesPage.tsx` / `RouteTicket.tsx`: 使うルートとアーカイブ済みの欄に分ける。ボタン「アーカイブ」「使うルートに戻す」
  - `CalendarPage.tsx`: 読み込んだルートから、アーカイブしたものを外す
  - `styles.css`: アーカイブ済みの切符を薄く、畳む欄の見出しを整える
- **docs**: `openapi.yaml`（API と `Route` の項目）、`requirements.md`（F1・F2・U11）、`docs/adr/0004-route-archive.md`（提案）と ADR の一覧

## 確かめたこと

- `npm run typecheck`: 通る
- `npm run lint`: 通る
- `npm run test`: 36 ファイル・267 件が通る（前は 34 ファイル・250 件。新しい試験を含む）
  - アーカイブ・戻す・編集しても状態が変わらない・他ユーザーのルートや無いルートは 404・古い DB（version 3）でも使う状態で読める、など
- `openapi.test.ts`: API の数が 15 → 16 になり、`PUT /api/routes/{id}/archived` が仕様書と一致する
- フロントの本番ビルド（`vite build`）: 通る
- 実サーバー（一時の DB）で `curl` による確認: 作成 → アーカイブ → 不正な値は 400 → 一覧に残る → 戻す、の順に期待どおり

**まだ確かめていないこと**: ブラウザでの画面の見た目と操作（畳む欄・ボタンの並び・狭い画面での表示）。画面は目で確かめていないので、レビューのときに見てください。

## 注意

- この PR は push・作成していません（GitHub に接続できない環境のため）。ブランチ `feat/route-archive` にコミット 1 件（`68af78a`）があります
- 既存の DB は、起動時のマイグレーションで自動的に列が増えます。手作業は要りません
- ADR-0004 は「提案」です。`docs/GITHUB_WORKFLOW.md` の運用に従い、オーナーが読んでからマージしてください（この PR を自動マージしない）

🤖 Generated with [Claude Code](https://claude.com/claude-code)
