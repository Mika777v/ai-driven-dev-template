## 概要
ルートの一覧に同じ名前（例: 「自宅↔本社」）が2つあり、出勤を選ぶときに見分けられなくなる問題への対応。`POST /api/routes` で、すでにあるルートと名前が同じなら登録せずに 409 を返す。

Closes #（Task の番号を入れる）

## 変更内容
- backend: `RouteRepository` に `existsByName(userId, name)` を追加（`SqliteRouteRepository` で実装）。`POST /api/routes` は、形式の検証（400）が通った後に重複を見て、同名なら `repo.create` を呼ばず 409 を返す
  - 本文: `{ "error": "入力に誤りがあります", "fieldErrors": [{ "field": "name", "message": "同じ名前のルートがあります" }] }`（型は `ApiError` のまま。文は `DUPLICATE_ROUTE_NAME_MESSAGE` の定数）
- 画面: コードの変更は無し。`RouteForm` はステータスを見ず `fieldErrors` を欄ごとに出すので、409 でもルート名の欄の下に出る（ほかの欄の入力も消えない）。テストで固定した
- `docs/api/openapi.yaml`: `POST /api/routes` に 409（`components/responses/DuplicateRouteName`）を追加
- `docs/troubleshooting.md`: API のステータスの表に 409、画面のメッセージの表に「同じ名前のルートがあります」を追加
- `docs/PROGRESS.md`: 続きの作業を追記
- テスト: `route-router.test.ts`（409・本文・件数が増えない／前後の空白／違う名前は 201／形式の誤りは 400／編集は変わらない）、`sqlite-route-repository.test.ts`（ある・無い・別ユーザー）、`routes-api.test.ts`（409 の応答が `toRouteFormErrors` で `name` の欄の文になる）

## 自分で決めたこと（SPEC のおすすめどおり）
- 比べ方は、前後の空白を除いた後の完全一致（`parseRouteInput` が空白を取るので、保存される名前どうしを比べる）。全角半角・大文字小文字は同じとみなさない
- 検証の順番は、形式の誤り（400）が先、通ったら重複（409）
- 409 の `error` は 400 と同じ「入力に誤りがあります」
- 画面のテストは、DOM を描画するテスト環境が無いため、API クライアント＋`toRouteFormErrors` の組み合わせで固定した（RouteForm 自体の描画テストは足していない）

## やらなかったこと
- 編集（`PUT /api/routes/:id`）の重複確認。**編集で同じ名前にできてしまうので、困りごとが完全には消えない。続きの Task を作ることを勧める**
- DB の UNIQUE インデックス・migration（すでに同名のルートがある DB では失敗するため）。すでにある同名のルートの自動整理もしない
- 要件定義 F1 への「ルート名は重複しない」の追記（オーナーが決めて、別 PR にする）

## 確認が必要な項目
なし（DB のスキーマ・ADR・要件定義の変更は無い）

## 動作確認の方法
- `npm run typecheck && npm run lint && npm run test`（すべて通過。257 テスト）
- `npm run dev` で画面を開き、同じ名前のルートを2回登録する → 2回目はルート名の欄の下に「同じ名前のルートがあります」が出て、一覧は増えない。名前を変えれば登録できる

## チェックリスト
- [x] テストを追加・更新した（ロジックを変えた場合）
- [ ] 要件定義（docs/requirements.md）と食い違っていない（F1 に重複の記述は無い。追記はオーナー判断）
- [x] 秘密情報・個人情報を含んでいない

🤖 Generated with [Claude Code](https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1)

https://claude.ai/code/session_01MePBtjqJRGTqj3Ge5Qw5o1
