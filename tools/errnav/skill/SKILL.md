---
name: errnav
description: テストやアプリのエラー・スタックトレース・ログから不具合の原因を調べるときに使う。tools/errnav で、エラーの一覧・発生箇所のソース・呼び出し経路・AI 用のコンテキストをまとめて取れる。
---

# errnav で不具合を調べる

1. エラーを集める
   - テストなら: `npm test 2>&1 | tools/errnav/bin/errnav scan -`（`npm test` はプロジェクトのテストのコマンドに読み替える）
   - ログなら: `tools/errnav/bin/errnav scan`（ログを自動で探す）
2. いちばん上（件数の多い・新しい）エラーのまとめを読む: `tools/errnav/bin/errnav context latest`
   - 別のエラーを見るときは、一覧の ID で `tools/errnav/bin/errnav context <ID>`
3. 「発生箇所」はエラーが**投げられた**場所。原因はその呼び出し元や、渡された値を作った所にあることが多い。示されたソースの周りを読んで確かめる
4. errnav で取れないとき（知らない形のログ・例外の出ない不具合で、アサーションの行しか出ない）は、自分で grep などで調べてよい

再現の確認: `tools/errnav/bin/errnav repro --expect '<エラーの一部>' -- <コマンド>`（再現したら終了コード 0）。詳しくは `tools/errnav/README.md`。
