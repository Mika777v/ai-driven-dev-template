## 何を変えたか

転勤で使わなくなったルートを片付けられるようにした。ルートの一覧と、出勤を選ぶときの選択肢が増えて見づらくなっていた問題への対応。

片付けは**削除ではなく、いつでも戻せる**状態にした（下の「決めたこと」を参照）。

- ルートの画面: 「片付ける」ボタンで、そのルートを「使うルート」の一覧から外す。一覧の下の「片付けたルート」（たたんである）から「戻す」ができる
- 出勤・追加の移動の選択肢には、使うルートだけを出す
- 片付けても、過去の日次記録の金額と区間は変わらない（記録のときの値のコピーを表示する）
- 片付けたルートは、新しい記録には選べない（API も 400 で止める）
- 日の編集で、記録のルートが片付け済みのときは、今の選択として「今は選べません」と押せない形で出す

## 決めたこと（質問できなかったため、自分で決めた）

- **削除ではなく「片付ける」にした。** 既存の「削除」は、ルートそのものを消す。片付けは、使わなくなっても履歴として見たい・あとで戻したい場合に備えた。既存の削除はそのまま残した
- **API の一覧（`GET /api/routes`）は片付けたルートも返す。** 選択肢から外すのは画面側（`activeRoutes`）で行う。ルートの画面に「片付けたルート」を出すため
- **片付けの API は `PUT /api/routes/{id}/archived`（`{ archived: boolean }`）。** 冪等にするため、「片付ける」と「戻す」を 1 本にまとめた。編集（PUT `/api/routes/{id}`）では片付けの状態は変えない
- **DB は migration 4 で `archived_at` 列（NULL = 使うルート）を足す。** 既存の DB は、開き直すと自動で移る（テストで確かめている）
- **Route の型に `archived: boolean` を足す。** 入力の型（RouteInput）からは外した。片付けは入力のフォームではなく、専用の操作として扱うため

## 変更の範囲

| 場所 | 内容 |
|---|---|
| `shared/src/route.ts` | `Route.archived` を追加。`RouteInput` からは除外 |
| `backend/src/db/migrations.ts` | migration 4（`routes.archived_at`） |
| `backend/src/routes/*` | 片付け・戻しの repository メソッド、API、本文の確認 |
| `backend/src/daily-records/resolve-work-style.ts` | 片付けたルートを新しい記録に選ぶと、ルートが見つからない扱い（400） |
| `frontend/src/routes/*` | 「片付ける／戻す」ボタン、一覧の分割、`activeRoutes`（選択肢用の絞り込み） |
| `frontend/src/calendar/*` | 選択肢に `activeRoutes` を使う。片付け済みの記録のルートは押せない項目で出す |
| `docs/requirements.md` | F1 に片付けの説明、データ項目、決定 U11 |
| `docs/api/openapi.yaml` | 新しい API（`PUT /api/routes/{id}/archived`）、`archived` 項目 |

## テスト

- `npm run typecheck`: 通る
- `npm run lint`: 通る
- `npm run test`: 257 件すべて通る（前は 250 件）
  - 追加: リポジトリの片付け・戻し・編集との組み合わせ・他ユーザーのルートは片付けられない、API の片付け（200 / 400 / 404）、片付けたルートは新しい記録に選べず過去の記録は残る、`activeRoutes`
  - 変更: 既存のテストの `Route` の形に `archived: false` を足した。OpenAPI の一覧の件数を 15 → 16 にした（新しい API 1 件）

## 確かめていないこと

- ブラウザでの見た目と操作は確かめていない（テストと型チェックだけ）。「片付けたルート」の畳みと、片付け済みの選択肢の押せない表示は、実際の画面で一度見てほしい
- GitHub への push と PR の作成はしていない（この環境では接続できないため）

🤖 Generated with [Claude Code](https://claude.com/claude-code)
