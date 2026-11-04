# AGENTS.md — {{PROJECT_NAME}} で作業する AI エージェントへの指示

> **目的**: どの AI エージェント（Claude Code・GitHub Copilot・Cursor・Gemini・Cline・Roo Code など）にも共通する、このリポジトリでの作業のルールの**正本**。ツールごとの設定ファイル（`CLAUDE.md`・`GEMINI.md` など）は、このファイルを読むよう指すだけにする。
> **いつ読むか**: 毎回のセッションの最初（多くのツールは自動で読み込む）。ルールに迷ったとき。
> **差し替え**: `{{...}}` を埋める。末尾の「記載例」は書き終えたら消してよい。ルールを足すときは、理由が長くなるものは `docs/` に書き、ここには1行の要点とリンクだけを置く。

---

## 0. このファイルの読み方

- ここには「必ず守ること」の要点だけを置く。詳しい理由と手順は下の表の文書にある
- **ファイル全体を読み込まず、いまの作業に要る箇所だけを読む**（読む量が増えるほど、前の内容が薄れる）

| 知りたいこと | 読むもの |
|---|---|
| 何を作るか・前提・やらないこと | [`docs/AI_PROJECT_CONTEXT.md`](docs/AI_PROJECT_CONTEXT.md) |
| 作業の進め方（Issue → PR → 報告） | [`docs/AI_WORKFLOW.md`](docs/AI_WORKFLOW.md) |
| コードの書き方 | [`docs/AI_CODING_STANDARDS.md`](docs/AI_CODING_STANDARDS.md) |
| ブランチ・コミット・PR・CI | [`docs/AI_GIT_WORKFLOW.md`](docs/AI_GIT_WORKFLOW.md) |
| セッションの始め方・終わり方・引き継ぎ | [`docs/AI_SESSION_GUIDE.md`](docs/AI_SESSION_GUIDE.md) |
| いまの進み具合・次にやること | [`docs/PROGRESS.md`](docs/PROGRESS.md) |
| 過去の設計判断 | [`docs/adr/`](docs/adr/README.md) |

## 1. プロジェクトの要約（3行）

- **何**: {{ONE_LINE_SUMMARY}}
- **誰のため**: {{TARGET_USERS}}
- **いまの段階**: {{CURRENT_PHASE}}（例: MVP を作っている / 運用中）

## 2. やりとり

- 説明は **{{LANGUAGE}}** で書く。専門用語は初めて出たときに一言で説明する
- **確かめたことと、確かめられなかったことを分けて報告する。** 推測で「動きます」と言わない
- 決めるのがオーナーのこと（要件・優先度・お金がかかること・外部への公開）は、選択肢とおすすめを示して聞く。聞くときは、答えだけで次に進めるように書く
- {{COMMUNICATION_EXTRA}}（例: オーナーは git に詳しくないので、画面の操作まで具体的に書く）

## 3. 必ず守ること（要点）

1. **1つの作業 = 1ブランチ = 1 PR。** 最新の `{{DEFAULT_BRANCH}}` からブランチを切る。ツールやセッションがブランチを指定しているときはそれに従う → [AI_GIT_WORKFLOW §2](docs/AI_GIT_WORKFLOW.md)
2. **PR のタイトルは Conventional Commits**（`feat(scope): 内容`）。本文は `.github/pull_request_template.md` の見出しに沿う
3. **force push しない。** push 済みの履歴を書き換えない。マージ済みの PR の続きは新しいブランチで別の PR にする。`{{DEFAULT_BRANCH}}` の取り込みは rebase ではなく merge
4. **「確認が必要な項目」に当てはまる PR は、自動マージせずオーナーに確認する**（ADR・DB スキーマ・要件・運用ルール/CI・依存のメジャー更新・認証/権限・リリース）→ [AI_GIT_WORKFLOW §5](docs/AI_GIT_WORKFLOW.md)
5. **PR を出す前に、手元で `{{CHECK_COMMAND}}` を通す。** CI が落ちたら原因を直す。テストを消す・飛ばす・弱めることで通さない
6. **秘密情報（API キー・パスワード・個人情報）をコミットしない。** 見つけたら作業を止めて報告する
7. **やらないこと（スコープ外）に手を広げない。** 必要そうなら Issue にして提案する → [AI_PROJECT_CONTEXT §4](docs/AI_PROJECT_CONTEXT.md)
8. **区切りで止まって報告する。** 区切りの単位: {{CHECKPOINT_UNIT}}（例: Epic 1つ / マージ 10 件 / リリース1つ）→ [AI_WORKFLOW §6](docs/AI_WORKFLOW.md)
9. **セッションを終える前に `docs/PROGRESS.md` を更新する。** 会話の中で決めたことは会話の外（docs）に残す → [AI_SESSION_GUIDE](docs/AI_SESSION_GUIDE.md)

## 4. コマンド

| 用途 | コマンド |
|---|---|
| 依存の導入 | `{{INSTALL_COMMAND}}` |
| 起動 | `{{RUN_COMMAND}}` |
| PR 前の確認（型・lint・テストをまとめて） | `{{CHECK_COMMAND}}` |
| 個別のテスト | `{{TEST_COMMAND}}` |

- 確認のコマンドは、まとめて1回で実行する
- 出力は必要な行だけを見る（`grep`・`tail`・行範囲の指定）

## 5. ディレクトリ

```
{{DIRECTORY_TREE}}
```

## 6. 気をつけること（過去につまずいた点）

<!-- つまずいたら1行ずつ足す。「何をすると・どうなる・どうする」の形で書く -->
- {{PITFALL_1}}

---

## 記載例

<details>
<summary>例: 経費精算アプリ（TypeScript・個人開発）の §1〜§6</summary>

```markdown
## 1. プロジェクトの要約（3行）
- **何**: 出勤ルートを登録し、期間をまとめて在宅/出勤を入力できる経費精算アプリ
- **誰のため**: 自分（個人利用）。TypeScript の学習も兼ねる
- **いまの段階**: MVP を作っている（ステップ 4/6）

## 2. やりとり
- 説明は **日本語** で書く。専門用語は初めて出たときに一言で説明する
- オーナーは Java 経験者。TypeScript の書き方は Java と対比して説明する

## 3. 必ず守ること（要点）
8. **区切りで止まって報告する。** 区切りの単位: Epic 1つ（AI_PROJECT_CONTEXT の「進め方」の1ステップ）

## 4. コマンド
| 依存の導入 | `npm install` |
| 起動 | `npm run dev` |
| PR 前の確認 | `npm run typecheck && npm run lint && npm run test` |
| 個別のテスト | `npm run test -- bulk` |

## 5. ディレクトリ
frontend/   React + Vite
backend/    Node.js + Express
shared/     フロントとバックで共有する型
docs/       設計・運用の文書

## 6. 気をつけること
- `npx prettier` を既定の幅で掛けると関係ない行まで折り返す。整形ツールは入れていないので使わない
- 新しいセッションには `node_modules` も手元の DB も無い。最初に `npm install` する
```

</details>
