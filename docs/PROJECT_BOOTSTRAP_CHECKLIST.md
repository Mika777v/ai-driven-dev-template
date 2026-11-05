# PROJECT_BOOTSTRAP_CHECKLIST — 新しいプロジェクトへの導入手順

> **目的**: このテンプレートから新しいプロジェクトを始めるときに、やることを漏れなく順番に進める。人がやること（GitHub の画面の設定）と、AI に任せられること（文書の穴埋め）を分けて書く。
> **いつ読むか**: テンプレートからリポジトリを作った直後に1回。既存のプロジェクトにテンプレートを足すとき。
> **差し替え**: 使わない手順は消す。終わった項目にチェックを付けて、最初の PR に含めるとよい（何を済ませたかの記録になる）。導入が終わったら、このファイルは消すか `docs/archive/` に移してよい。末尾の「記載例」は消してよい。

---

## 0. 差し替える値の一覧

先にこれを決めておくと、§2 を AI に任せるとき1回で済む。

| 値 | 意味 | 例 |
|---|---|---|
| `{{PROJECT_NAME}}` | プロジェクト名 | `routepense` |
| `{{OWNER}}` / `{{REPO}}` | GitHub のオーナーとリポジトリ名 | `your-name` / `routepense` |
| `{{DEFAULT_BRANCH}}` | 既定のブランチ | `main` |
| `{{LANGUAGE}}` | AI とのやりとりの言語 | 日本語 |
| `{{CHECK_COMMAND}}` | PR 前にまとめて流す確認 | `bash scripts/check.sh` |
| `{{CHECKPOINT_UNIT}}` | 止まって報告する区切り | Epic 1つ |
| `{{SCOPES}}` | PR タイトルの scope | `api` `ui` `db` `docs` `ci` `deps` |

残っている値は次のコマンドで探せる:

```bash
bash scripts/find-placeholders.sh
```

## 1. リポジトリを作る（人）

- [ ] GitHub でこのリポジトリを開き、「Use this template」→「Create a new repository」
- [ ] 既存のプロジェクトに足すときは、必要なファイルだけをコピーする（最低限: `AGENTS.md`・`docs/AI_*.md`・`docs/PROGRESS.md`・`.github/`）
- [ ] 使わない AI ツールの入口ファイルを消す（`CLAUDE.md`・`GEMINI.md`・`.github/copilot-instructions.md`・`.cursor/`・`.clinerules/`・`.roo/`）
- [ ] 障害解析ツール（`tools/errnav/`）を使わないなら消す。使うなら `.errnav/config` にログの場所とエディタを書く（`tools/errnav/README.md`「設定」）

## 2. 文書を埋める（AI に任せてよい）

AI に次のように頼む（`{{...}}` の値は §0 の表を貼る）:

```
docs/PROJECT_BOOTSTRAP_CHECKLIST.md の §2 を進めて。プロジェクトの説明は次のとおり:
<作りたいものの説明・技術スタック・やらないこと>
差し替える値:
<§0 の表>
```

- [ ] `docs/AI_PROJECT_CONTEXT.md` — 概要・技術スタック・機能・**やらないこと**・進め方
- [ ] `AGENTS.md` — 要約・コマンド・ディレクトリ
- [ ] `docs/AI_CODING_STANDARDS.md` §7 — 言語ごとの決まり
- [ ] `docs/AI_WORKFLOW.md` — 区切りの単位・確認が必要な項目の追加分
- [ ] `docs/AI_GIT_WORKFLOW.md` — 既定ブランチ・scope
- [ ] `docs/AI_SESSION_GUIDE.md` — 環境の準備・使うツールの行
- [ ] `docs/PROGRESS.md` — 最初の「次にやること」
- [ ] `docs/TROUBLESHOOTING.md` — 節（起動・画面・API など）をプロジェクトの作りに合わせる
- [ ] `.github/workflows/pr-title.yml` の `scopes` を `{{SCOPES}}` と同じにする
- [ ] `.github/labels.yml` の `area:*` をプロジェクトのディレクトリに合わせる
- [ ] `.github/ISSUE_TEMPLATE/config.yml` の URL を直す
- [ ] `scripts/check.sh` に型チェック・lint・テストのコマンドを書く
- [ ] `README.md` を「派生プロジェクトの README」のテンプレートで置き換える
- [ ] 各ファイルの「記載例」を消す
- [ ] `bash scripts/find-placeholders.sh` で残りが無いことを確かめる

## 3. 最初の PR（人がマージ）

- [ ] §2 の変更を1つの PR にする（タイトル例: `docs: AI 駆動開発のテンプレートを導入`）
- [ ] CI（`ci-ok`・`conventional-commits`）が動いて通ることを確かめる
- [ ] **この PR は手でマージする**（まだ必須チェックを設定していないため。先に必須にするとどの PR もマージできなくなる）

## 4. リポジトリの設定（人・最初の PR のマージ後）

スクリプトで設定する場合（GitHub CLI と管理者の権限が要る）:

```bash
gh auth login
```

```bash
REPO={{OWNER}}/{{REPO}} bash scripts/github/setup-repo.sh
```

画面で設定する場合:

- [ ] **Settings → General → Pull Requests**
  - [ ] 「Allow merge commits」と「Allow rebase merging」を外し、「Allow squash merging」だけを残す
  - [ ] squash のメッセージは「Pull request title and description」
  - [ ] 「Allow auto-merge」にチェック
  - [ ] 「Automatically delete head branches」にチェック
- [ ] **Settings → Rules → Rulesets → New ruleset → New branch ruleset**
  - [ ] 名前 `main-protection`、Enforcement status `Active`、Target は「Include default branch」
  - [ ] Restrict deletions / Require linear history / Block force pushes
  - [ ] Require a pull request before merging（承認数: 個人なら `0`、チームなら `1`。Allowed merge methods は `Squash` だけ）
  - [ ] Require status checks to pass → `ci-ok` と `conventional-commits` を追加
- [ ] **Settings → Actions → General → Workflow permissions**
  - [ ] ラベルの同期に書き込みが要る（`labels.yml` は `issues: write` を指定済み）
  - [ ] release-please を使うなら「Allow GitHub Actions to create and approve pull requests」にチェック
- [ ] **Settings → Code security**: Dependabot alerts・Secret scanning・Push protection を有効にする
- [ ] Actions の画面で `labels` ワークフローを手動で1回動かし、ラベルをそろえる

確かめ方:

- [ ] Rulesets に `main-protection` があり Active になっている
- [ ] 次の PR の画面に「Enable auto-merge」のボタンが出る

## 5. AI ツールの設定（人）

- [ ] 使う AI ツールに、このリポジトリへのアクセスを与える（GitHub App・連携の設定）
- [ ] クラウドの作業環境を使うなら、ネットワークの許可・環境変数・最初に動かすコマンドを設定する
- [ ] 秘密情報（API キー）は AI ツールの秘密の設定か GitHub の Secrets に置く。リポジトリには置かない

## 6. 最初の作業を始める

- [ ] `docs/AI_PROJECT_CONTEXT.md` §7 の各ステップを Epic にする（`.github/ISSUE_TEMPLATE/epic.yml`）
- [ ] 最初の Epic を Task に分け、sub-issue にする（AI に「E01 を Task に分けて Issue にして」と頼んでよい）
- [ ] 新しいセッションで次の文から始める:

```
docs/PROGRESS.md の続きから。E01（Epic #<番号>）を #<Task番号> から始めて。
```

---

## 記載例

<details>
<summary>例: 個人開発で済ませた状態</summary>

```markdown
## 1. リポジトリを作る
- [x] 「Use this template」で作成
- [x] 使わない入口ファイルを消した（Claude Code だけ使うので CLAUDE.md だけ残した）

## 3. 最初の PR
- [x] #1 docs: AI 駆動開発のテンプレートを導入（手でマージ）

## 4. リポジトリの設定
- [x] `scripts/github/setup-repo.sh` で設定（承認数 0）
- [x] #2 で「Enable auto-merge」が出ることを確かめた
```

</details>
