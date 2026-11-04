# routepense

経費精算アプリ。出勤ルートを登録し、日ごとに在宅か出勤ルートを選んで、期間をまとめて登録できる一括入力を実現する。個人利用から始め、TypeScript の学習も兼ねる。

## 技術スタック
TypeScript（frontend: React + Vite / backend: Node.js + Express / shared: 共有の型）、DB は SQLite（node:sqlite）、テストは Vitest、パッケージ管理は npm。

## 設計方針
- 勤務区分は判別可能なユニオン型。型は `shared/` に置き、frontend と backend で共有する
- 日付は文字列（YYYY-MM-DD）で扱う
- 一括登録のロジックは純粋関数にしてテストを書く
- バリデーションは入力の境界（API の受け口）で行う

## コマンド
- 確認: `npm run typecheck && npm run lint && npm run test`

## 作業の決まり（必要なときに読む）
git の運用・PR と自動マージ・Issue・セッションの区切り方・教科書（docs/textbook/）の書き方は `docs/DEV_RULES.md`。ブランチを切る・PR を作る・Issue を扱う・教科書を書くときは、先にそこを読む。
