## 概要
転勤で使わなくなったルートが一覧と出勤の選択肢に並んでごちゃごちゃする、という Task に対応する。
ルートの削除はすでにあるが、元に戻せず、過去の日を古いルートで直せなくなる。そこで **削除は残したまま、戻せる「使わない」（アーカイブ）を足した**。使わないルートは一覧の下に畳み、新しく選ぶ場面の選択肢から外す。

要件は SPEC（オーナー確認済み。Q1〜Q8 はすべておすすめ案）のとおり。経緯と理由は **ADR-0004** と 要件定義 **U11** に書いた。

Closes #（Task の番号。GitHub に接続できず、番号を確認できていない。push 時に付ける）

## 変更内容
- **shared**: `Route` に任意の `archivedAt?: string`。`RouteInput`・`RouteSnapshot` には入れない。純粋関数 `activeRoutes` / `archivedRoutes`（元の順を保つ）
- **DB**: migration version 4 `ALTER TABLE routes ADD COLUMN archived_at TEXT`（NULL = 使う。既存の行はそのまま「使う」）
- **backend**
  - `RouteRepository` に `archive` / `unarchive`。`archive` は、すでに使わないなら日時を変えない
  - `update`（PUT）は `archived_at` を変えず、返す `Route` に `archivedAt` を含める（読み直して返す）
  - `POST /api/routes/:id/archive`・`/unarchive`。200 で更新後の `Route`、無い id は 404「ルートが見つかりません」。2回送っても 200
  - 出勤の保存は変えない（使わないルートでも存在すれば 200）
  - `docs/api/openapi.yaml` に2つのパスと `archivedAt`。`openapi.test.ts` の件数を 15 → 17
- **画面（ルート）**: 使うルートに「使わない」ボタン（確認なし）。一覧の下に `<details>`「使わなくなったルート（N件）」（最初は閉じ、0件なら出さない）。使わないルートは「使うに戻す」「削除」（編集なし）。編集中のルートを使わないにしたら編集をやめる。使うルートが0件のときの案内文
- **画面（選択肢）**: 日の編集パネルの出勤・一括設定・追加の移動の「登録済みのルートから選ぶ」は使うルートだけ。`initialBulkForm` は使うルートの先頭。日の編集パネルは、記録（または当てはめ中）のルートが使わないルートなら今の選択として出す。`buildOptions` は `day-options.ts` に出してテストを書いた
- **文書**: `docs/requirements.md`（F1・§5・U11）、`docs/adr/0004-archive-routes.md` と README の表、`docs/troubleshooting.md`（新しいメッセージと「選択肢にルートが出ない」）、`docs/PROGRESS.md`

## 自分で決めたこと
SPEC に無い、または迷ったところ。
- **PR を1つにまとめた**: SPEC は T1（要件・ADR）→ T2（DB・API）→ T3・T4（画面）の4PRを案としていたが、GitHub に接続できず、順にマージされるのを待てない。互いに依存する変更なので1つにした。大きければ、この順でコミットを分けて出し直せる（ADR・要件 / shared・backend / 画面）
- **`RouteInput` を `Omit<Route, "id" | "userId" | "archivedAt">` にした**: `archivedAt` を入力に混ぜない（SPEC の「`RouteInput` は変えない」を保つ）ため。`PUT` に `archivedAt` を送られても、受け口が取り込まない
- **`activeRoutes` / `archivedRoutes` は `Pick<Route, "archivedAt">` を持つものなら何でも受ける**: テストと使う側が簡単になるため
- **`initialBulkForm` 自身も使うルートに絞る**: 呼び出し側（`CalendarPage`）でも絞っているが、先頭が使わないルートになる誤りをこの関数のテストで防げるようにした
- **`buildOptions` の引数を `record` から「今の選択（`WorkStyle`）」に変えた**: 一括設定の当てはめ中の内容（`draft.workStyle`）も「今の選択」として出すため
- **`update` を読み直して返すようにした**: 入力から組み立てると `archivedAt` が落ちるため
- ADR の状態は「提案」（ADR-0002・0003 と同じ）。マージで「決定」にする

## 確認が必要な項目
自動マージを予約しない。次に当てはまる。
- **DB のスキーマ**: `routes.archived_at`（migration 4）
- **ADR**: ADR-0004（列の形・API の形・「使わないルートでの出勤の保存も受け付ける」）
- **要件定義**: F1・§5 の Route・U11

オーナーに見てほしい点: 上の「自分で決めたこと」の PR のまとめ方。

## 動作確認の方法
```
npm run typecheck && npm run lint && npm run test   # 36ファイル・269テスト、すべて通った
npm run dev
```
1. 「ルート」でルートを2件登録し、片方の「使わない」を押す → 使うルートの一覧から消え、下に「使わなくなったルート（1件）」。画面を読み直しても同じ
2. カレンダーで日をクリック → 出勤のボタン、一括設定のルート、追加の移動の「登録済みのルートから選ぶ」に、使わないルートが出ない
3. 使わないにする前にそのルートで出勤にした日 → 表示と金額はそのまま。編集パネルでは今の選択としてボタンが出る
4. 「使うに戻す」→ 3か所にまた出る。名前・区間・運賃・URL は変わらない
5. `curl -X POST localhost:3000/api/routes/<id>/archive` を2回 → どちらも 200 で `archivedAt` は同じ
6. 古い DB（version 3）でも起動して migration 4 が当たることは、`sqlite-route-repository.test.ts` で確認済み。実際の `backend/data/routepense.db` では試していない（画面での操作確認もまだ。型・lint・テストのみ）

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [x] 要件定義（docs/requirements.md）と食い違っていない（要件定義を更新した）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
