# ai-driven-dev-template

生成 AI と一緒に開発するための、**プロジェクト運用の共通テンプレート集**です。
Claude Code・GitHub Copilot・Cursor・Gemini・Cline・Roo Code など、複数の AI エージェントで同じルールを使い回せるようにしています。

> **目的**: AI が読む指示ファイルと、git / GitHub（Issue・PR・Actions）の運用を、言語やフレームワークに依存しない形でまとめ、新しいプロジェクトにすぐ持ち込めるようにする。
> **いつ読むか**: このテンプレートを使い始めるとき（人が読む）。AI は `AGENTS.md` から読み始めるので、このファイルを毎回読む必要はない。
> **差し替え**: 導入が終わったら、このファイルは末尾の「テンプレート: 派生プロジェクトの README」で置き換える。

---

## 特徴

- **言語・フレームワークに依存しない** — 確認のコマンドは `scripts/check.sh` 1本にまとめ、CI もそれを呼ぶだけ
- **個人開発と小規模チームの両方で使える** — 違いは「承認数」と「区切りの単位」くらい。両方の記載例を付けた
- **AI が読みやすい** — 1ファイル1役割、要点は箇条書きと表、ファイル冒頭に「目的・いつ読むか」、記載例は折りたたんで末尾に
- **差し替え箇所が明確** — 差し替える値は `{{PROJECT_NAME}}` の形にそろえ、`scripts/find-placeholders.sh` で残りを探せる
- **IDE に依存しない障害解析ツールつき** — `tools/errnav` で、ログのエラーから発生箇所のソースへすぐに飛べる。再現の確認と、AI に渡すコンテキストの生成もできる（[使い方](tools/errnav/README.md)）
- **実際の開発で使った運用から作った** — 個人開発の 2 つのリポジトリ（経費精算アプリ・社内規程の検索ナビ）で、Issue・PR・Actions を使って AI と進めたときのルールを一般化した

## 構成

```
.
├── README.md                          このファイル（人向けの入口）
├── AGENTS.md                          ★ AI 向けの入口。全ツール共通のルールの正本
│
├── CLAUDE.md                          Claude Code   → AGENTS.md を読み込む
├── GEMINI.md                          Gemini CLI    → AGENTS.md を指す
├── .github/copilot-instructions.md    GitHub Copilot→ AGENTS.md を指す
├── .cursor/rules/agents.mdc           Cursor        → AGENTS.md を指す
├── .clinerules/00-agents.md           Cline         → AGENTS.md を指す
├── .roo/rules/00-agents.md            Roo Code      → AGENTS.md を指す
│
├── docs/
│   ├── AI_PROJECT_CONTEXT.md          何を作るか・やらないこと・前提（ほぼ全部差し替え）
│   ├── AI_WORKFLOW.md                 Issue → PR → 報告の進め方、止まって確認すること
│   ├── AI_CODING_STANDARDS.md         コードの書き方（共通の原則 + 言語ごとの欄）
│   ├── AI_GIT_WORKFLOW.md             ブランチ・Conventional Commits・PR・CI・リポジトリ設定
│   ├── AI_SESSION_GUIDE.md            セッションの区切り方・読む順番・引き継ぎ
│   ├── PROJECT_BOOTSTRAP_CHECKLIST.md 導入の手順（人と AI の分担つき）
│   ├── PROGRESS.md                    進み具合（セッションをまたぐ引き継ぎのメモ）
│   └── adr/                           設計判断の記録（README・テンプレート）
│
├── .github/
│   ├── pull_request_template.md       「確認が必要な項目」「確かめたこと/確かめられなかったこと」つき
│   ├── ISSUE_TEMPLATE/                epic / task / bug / spike / config
│   ├── labels.yml                     ラベルの正本（type・area・priority・needs-confirm）
│   ├── dependabot.yml                 公開から14日たった版だけ提案（cooldown）
│   └── workflows/
│       ├── ci.yml                     scripts/check.sh を実行 + ゲートジョブ ci-ok
│       ├── pr-title.yml               PR タイトルの Conventional Commits 検査
│       └── labels.yml                 labels.yml をリポジトリに同期
│
├── scripts/
│   ├── check.sh                       PR 前の確認（型・lint・テスト）を1本に
│   ├── find-placeholders.sh           差し替え漏れ {{...}} を探す
│   └── github/setup-repo.sh           スカッシュだけ・自動マージ・ルールセットを API で設定
│
└── tools/errnav/                      IDE に依存しない障害解析ツール（Bash）
    ├── bin/errnav                     ログ検出・エラー抽出・発生箇所・トレース・ソースジャンプ・
    │                                  呼び出し経路・AI 用コンテキスト・再現の確認
    ├── lib/  plugins/  tests/         plugins は php / node / python / java / go / ruby
    ├── README.md                      使い方
    └── ARCHITECTURE.md                設計
```

### ファイルの役割の分け方

| 種類 | ファイル | 変える頻度 | 変えるときの確認 |
|---|---|---|---|
| ルール（どう進めるか） | `AGENTS.md`・`docs/AI_*.md` | まれ | 人が確認する |
| 前提（何を作るか） | `docs/AI_PROJECT_CONTEXT.md` | ときどき | 人が確認する |
| 判断の理由 | `docs/adr/` | 判断のたび | 人が確認する |
| 状態（いまどこか） | `docs/PROGRESS.md`・Issue | セッションごと | AI が更新してよい |

**ルールの正本は `AGENTS.md` の1か所だけ**にし、ツールごとのファイル（`CLAUDE.md` など）は「`AGENTS.md` を読む」と書くだけにしています。ツールごとに書き分けると、ツールによって守るルールが食い違うためです。
（多くのツールは `AGENTS.md` を直接読めます。対応状況は変わるので、使うツールの公式の文書で確かめ、不要な入口ファイルは消してください。）

## 使い方（クイックスタート）

1. GitHub で「**Use this template**」→ 新しいリポジトリを作る
2. AI に次のように頼む:
   ```
   docs/PROJECT_BOOTSTRAP_CHECKLIST.md の §2 を進めて。作りたいものは次のとおり:
   <説明・技術スタック・やらないこと>
   ```
3. 差し替え漏れを確かめる:
   ```bash
   bash scripts/find-placeholders.sh
   ```
4. 最初の PR を**手でマージ**してから、リポジトリを設定する:
   ```bash
   REPO=<owner>/<repo> bash scripts/github/setup-repo.sh
   ```
5. 最初の Epic を作り、新しいセッションで始める:
   ```
   docs/PROGRESS.md の続きから。E01（Epic #<番号>）を #<Task番号> から始めて。
   ```

詳しい手順は [`docs/PROJECT_BOOTSTRAP_CHECKLIST.md`](docs/PROJECT_BOOTSTRAP_CHECKLIST.md)。

## 各ファイルの書式

`docs/` と `AGENTS.md` は、どれも同じ形にそろえています。

```markdown
# ファイル名 — 一言

> **目的**: このファイルが何のためにあるか
> **いつ読むか**: AI（と人）がこれを読む場面
> **差し替え**: どこを書き換えるか

## 1. 〜   ← テンプレート本体（{{...}} を埋める）
## 2. 〜

---
## 記載例  ← <details> で折りたたみ。書き終えたら消してよい
```

記載例を末尾の折りたたみに置いているのは、AI が毎回読む量を減らすためと、導入後に消しやすくするためです。

## 実際の開発から取り入れたこと

| 取り入れたこと | 理由 | 書いた場所 |
|---|---|---|
| 1つの作業 = 1ブランチ = 1 PR、スカッシュ + 自動マージ | 1件ずつ承認を待たずに AI が進められる。CI が守りになる | AI_GIT_WORKFLOW §1 |
| 「確認が必要な項目」だけは自動マージしない | ADR・DB スキーマ・要件・CI 設定など、戻しにくいものだけ人が見る | AI_WORKFLOW §5 |
| 必須チェックはゲートジョブ `ci-ok` 1つ | チェックを足してもリポジトリ設定を変えずに済む | ci.yml・AI_GIT_WORKFLOW §7 |
| PR タイトルを Conventional Commits で検査（日本語可） | スカッシュでタイトルが main のコミットになる | pr-title.yml |
| force push 禁止・マージ済み PR の続きは新しいブランチ | AI が履歴を壊す・マージ済み PR に積むのを防ぐ | AI_GIT_WORKFLOW §6 |
| Epic / Task / Spike と sub-issue、`Closes #` | 作業の単位と進み具合を会話の外に残す | AI_WORKFLOW §2 |
| 区切りで止まって報告、最後に「次のセッションの最初の文」 | 人が確認する点を絞る。次のセッションをすぐ始められる | AI_WORKFLOW §6・AI_SESSION_GUIDE §5 |
| 区切りごとに新しいセッション、続きは PROGRESS.md から | 長い会話は読み直しが増え、内容も薄れる | AI_SESSION_GUIDE §1 |
| 環境の設定を変えたら新しいセッション | 設定はセッション開始時に読まれ、会話を空にしても反映されない | AI_SESSION_GUIDE §1 |
| 確かめたこと / 確かめられなかったことを分けて報告 | 推測の「動きます」を防ぐ | AGENTS §2・PR テンプレート |
| 依存は公開から2週間以上たった版、Action はハッシュで固定 | 出たばかりの版の不具合・乗っ取りを避ける | AI_CODING_STANDARDS §6・dependabot.yml |
| 「気をつけること（過去につまずいた点）」を AGENTS に追記 | 同じ失敗を次のセッションでも繰り返さない | AGENTS §6 |
| CI のファイルを入れた最初の PR は手でマージしてから必須チェックを設定 | 先に必須にするとどの PR もマージできなくなる | BOOTSTRAP §3〜§4 |

## ルールの効果（測った結果）

2026-11-05 に、[routepense](https://github.com/Mika777v/routepense) で同じ Task（日次記録にメモを付ける。DB のスキーマ・API・画面・CSV・文書に手が入る）を Claude Code に実装させ、ルールの有り無しで比べた。各条件1回なので、傾向として読む。

| | ルールあり（CLAUDE.md で案内） | ルールの文書はあるが案内なし | ルールの文書なし |
|---|---|---|---|
| 受け入れテスト（AI に見せていない 13 件） | 13/13 | 13/13 | 13/13 |
| 既存のテスト・型・lint | 通る | 通る | 通る |
| ツール / ターン | 41 / 42 | 39 / 40 | 34 / 35 |
| トークン | 383万 | 367万 | 286万 |
| 時間 | 7分20秒 | 5分21秒 | 5分04秒 |
| ブランチ名・コミット・PR の形 | ○ | ○ | × |
| DB のスキーマの変更を「確認が必要な項目」に申告 | ○ | ○ | × |
| 教科書・手順書も直す | ○ | ○ | × |
| 引き継ぎのメモ（PROGRESS.md） | ○ | × | × |

わかったこと:

- **機能の正しさは、ルールがあっても無くても同じ。** Task の仕様がはっきりしていれば、ルールが無くても正しく作れた
- **ルールがあると、AI の作業は約3割多くかかる**（トークン 286万 → 383万）。増えた分は、教科書・手順書・引き継ぎのメモを書く作業と、ルールの文書を読む分
- **代わりに、人の側の手間が減る。** 戻しにくい変更（DB のスキーマ）を AI が自分から申告する、PR とコミットの形がそろう、文書がコードと一緒に最新になる。ルールが無い条件では、スキーマの変更が申告されず、自動マージならそのまま入っていた
- **CLAUDE.md で案内するかどうかの差は小さい。** 強いモデルは、ルールの文書がリポジトリにあれば自分で探して守った。ただし、PR テンプレートなどに無く CLAUDE.md の要点にだけ書いたルール（引き継ぎのメモ）は、案内しないと守られなかった

つまり、ルールは AI の作業を速くするものではなく、**人が後で確かめる・直す・引き継ぐ手間を減らす代わりに、AI に少し多く働かせるもの**。小さな使い捨ての作業なら、ルールを薄くしてよい。

まだわかっていないこと: 回によるばらつき（各1回だけ）、仕様の曖昧な Task での差（「確認が必要な項目」や「選択肢を示す」が正しさにも効くか）。測るのに使った道具は、ブランチ `bench/agent-bench` にある（routepense 専用なので main には入れていない）。

## 記載例

<details>
<summary>このテンプレートから作ったプロジェクトの README の例</summary>

```markdown
# routepense

出勤ルートを登録し、日ごとに在宅/出勤を選んで期間をまとめて登録できる経費精算アプリ。

## 動かし方
npm install
npm run dev   # http://localhost:5173

## 開発
- AI と開発するときのルール: AGENTS.md
- 何を作るか: docs/AI_PROJECT_CONTEXT.md
- 進み具合: docs/PROGRESS.md
- PR 前の確認: bash scripts/check.sh

## ライセンス
MIT
```

</details>

## テンプレート: 派生プロジェクトの README

導入が終わったら、このファイル全体を次の内容で置き換えます。

````markdown
# {{PROJECT_NAME}}

{{ONE_LINE_SUMMARY}}

## 動かし方

```bash
{{INSTALL_COMMAND}}
```

```bash
{{RUN_COMMAND}}
```

## 開発

| 知りたいこと | 読むもの |
|---|---|
| AI と開発するときのルール | [`AGENTS.md`](AGENTS.md) |
| 何を作るか・やらないこと | [`docs/AI_PROJECT_CONTEXT.md`](docs/AI_PROJECT_CONTEXT.md) |
| 進み具合 | [`docs/PROGRESS.md`](docs/PROGRESS.md) |
| ブランチ・PR・CI | [`docs/AI_GIT_WORKFLOW.md`](docs/AI_GIT_WORKFLOW.md) |
| 設計判断 | [`docs/adr/`](docs/adr/README.md) |

PR を出す前に:

```bash
bash scripts/check.sh
```

## ライセンス

{{LICENSE}}
````

## ライセンス

まだ決めていません（公開して配る場合は `LICENSE` を置く）。
