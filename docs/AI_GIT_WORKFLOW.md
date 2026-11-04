# AI_GIT_WORKFLOW — ブランチ・コミット・PR・CI

> **目的**: AI が git と GitHub を安全に使えるよう、操作の決まりと理由をまとめる。履歴を壊さない・CI を守りにする・人が見るべき PR だけを人が見る、の3つを仕組みで支える。
> **いつ読むか**: ブランチを切る・PR を作る・CI が落ちた・main の変更を取り込むとき。リポジトリを最初に設定するとき（§8）。
> **差し替え**: `{{...}}`（既定ブランチ・scope の一覧・必須チェック）を合わせる。scope を変えたら `.github/workflows/pr-title.yml` も同じにする。末尾の「記載例」は消してよい。

---

## 1. 全体の流れ（GitHub Flow + スカッシュマージ + 自動マージ）

```
{{DEFAULT_BRANCH}} ──●──────────●──────────●──   （常に動く状態）
          \        /  \        /
           feat/...     fix/...         ← 1つの作業 = 1ブランチ = 1 PR
```

1. 最新の `{{DEFAULT_BRANCH}}` からブランチを切る
2. コミットして push し、PR を作る
3. PR を作ったら**自動マージ（スカッシュ）を予約**する。必須チェック（`ci-ok` と `conventional-commits`）が通ると GitHub がマージする
4. 「確認が必要な項目」（§5）に当てはまる PR だけは予約せず、人が見てからマージする

用語:
- **GitHub Flow**: main と、作業ごとの短いブランチだけで回すやり方。develop ブランチなどは作らない
- **スカッシュマージ**: PR の中のコミットを1つにまとめて main に入れる。main の履歴が「1 PR = 1 コミット」になる
- **自動マージ（auto-merge）**: 「チェックが通ったらマージする」と予約しておく GitHub の機能

## 2. ブランチ名

| 種類 | 命名 | 例 |
|---|---|---|
| 機能追加 | `feat/<内容>` | `feat/route-api` |
| バグ修正 | `fix/<内容>` | `fix/weekday-filter` |
| ドキュメント | `docs/<内容>` | `docs/adr-database` |
| その他 | `chore/` `refactor/` `test/` `ci/` | `ci/add-lint` |
| 技術検証 | `spike/<内容>`（マージしない） | `spike/search-engine` |

- Issue 番号を入れてもよい（`feat/12-route-api`）
- **AI ツールやクラウドのセッションがブランチ名を指定しているとき（例: `claude/...`・`copilot/...`）は、それに従う**
- ブランチの寿命は数日まで。長くなる機能は小さな PR に分ける

## 3. コミットと PR のタイトル（Conventional Commits）

スカッシュマージでは **PR のタイトルがそのまま main のコミットメッセージになる**。CI（`pr-title.yml`）で形式を確かめる。

```
<type>(<scope>): <内容>
例: feat(api): ルート登録 API を追加
    fix(ui)!: 日付の形式を YYYY-MM-DD に変更   ← ! は破壊的変更
```

| type | 用途 |
|---|---|
| `feat` | 機能追加 |
| `fix` | バグ修正 |
| `docs` | ドキュメント |
| `refactor` | 振る舞いを変えない書き直し |
| `perf` | 性能改善 |
| `test` | テストだけ |
| `build` / `ci` | ビルド・CI |
| `chore` | 雑務 |
| `revert` | 取り消し |

scope（省略可）: {{SCOPES}}（例: `api` `ui` `db` `docs` `ci` `deps`）。**`pr-title.yml` に書いた scope だけを使う。**

- 内容は日本語でよい（CI は大文字小文字を問わない設定にしてある）
- ブランチの中の途中のコミットは自由でよい（スカッシュでまとまる）。ただし秘密情報を一度でもコミットしたら、消しても履歴に残るので報告する

## 4. PR の本文

`.github/pull_request_template.md` の見出しに沿って書く。

- `Closes #<Task番号>` を書く（マージで Issue が閉じる）。Task が無い小さな作業は `Part of #<Epic番号>`
- 「確認が必要な項目」は、当てはまらなければ「なし」と書く
- 「動作確認の方法」は、人が手元で再現できるコマンドと見る場所を書く
- 本文は見出しと要点を保ったまま短く書く

## 5. 自動マージしない「確認が必要な項目」

一覧と理由は [`AI_WORKFLOW.md` §5](AI_WORKFLOW.md) が正本。ここでは操作だけ:

- 当てはまる PR は**自動マージを予約しない**。本文の「確認が必要な項目」に、決めてほしいことと、おすすめと理由を書く
- Issue には `needs-confirm` ラベルを付ける
- 人がマージしたら、続きの作業に進む

## 6. 守ること（履歴を壊さない）

- **force push しない。** push 済みのブランチの履歴を書き換えない（rebase・amend・reset してからの push をしない）
- **マージ済みの PR を直す・続ける**ときは、最新の `{{DEFAULT_BRANCH}}` から新しいブランチを切り、別の PR にする
- **まだマージされていない PR を直す**ときは、同じブランチにコミットを足して push する
- `{{DEFAULT_BRANCH}}` の変更を取り込むときは、rebase ではなく merge する
- 同時に開いている PR どうしで、同じファイルの同じ箇所を触らない。重ねてマージできるか不安なら、手元で `git checkout --detach {{DEFAULT_BRANCH}}` してから順に `git merge` して確かめる
- `{{DEFAULT_BRANCH}}` に直接 push しない（ルールセットで禁止する。§8）

## 7. CI

| ワークフロー | ジョブ | 内容 |
|---|---|---|
| `.github/workflows/ci.yml` | `checks` | `scripts/check.sh` を実行（型・lint・テストをまとめたもの） |
| | `ci-ok` | **必須チェック。** ほかのジョブの結果をまとめ、失敗があれば落ちる |
| `.github/workflows/pr-title.yml` | `conventional-commits` | **必須チェック。** PR タイトルの形式を確かめる |
| `.github/workflows/labels.yml` | `sync` | `.github/labels.yml` の内容でラベルをそろえる |

- **ゲートジョブ（`ci-ok`）**: いくつものチェックの結果を1つにまとめるジョブ。必須チェックを `ci-ok` 1つにしておけば、チェックを足してもリポジトリの設定を変えずに済む。また、変更されたパスで動きを変えるジョブ（例: frontend が変わったときだけ動く）を必須にすると、関係ない PR で「待機中」のまま止まるが、ゲートを挟めば止まらない
- チェックを足すときは `checks` に足すか、新しいジョブを作って `ci-ok` の `needs` に加える
- CI が落ちたら、ログの該当箇所を読んで原因を直し、push し直す。**テストを消す・飛ばす・弱めて通さない**
- 待つときは何度も見に行かず、通知（PR の購読・バックグラウンドの待機）を使う

## 8. リポジトリの設定（最初に1回だけ）

`scripts/github/setup-repo.sh` で設定できる（GitHub CLI と管理者の権限が要る）。画面で設定する手順は [`PROJECT_BOOTSTRAP_CHECKLIST.md`](PROJECT_BOOTSTRAP_CHECKLIST.md) §4。

**順番に注意**: まだ `{{DEFAULT_BRANCH}}` に無いチェックを必須にすると、どの PR もマージできなくなる。CI のファイルを入れる最初の PR は手でマージし、その後に設定する。

| 設定 | 値 |
|---|---|
| マージの方式 | スカッシュだけ（merge commit・rebase は無効） |
| スカッシュのメッセージ | PR のタイトルと本文 |
| 自動マージ | 有効 |
| マージ後のブランチ | 自動で消す |
| ルールセット（既定ブランチ） | PR 必須（承認数 {{REQUIRED_APPROVALS}}）・必須チェック `ci-ok` `conventional-commits`・force push 禁止・削除禁止・直線の履歴 |

## 9. リリース（任意）

- タグ・リリースは人が決める（§5）。SemVer（`vX.Y.Z`）を使い、`0.x` の間は minor をマイルストーンの到達に合わせると読みやすい
- 自動化するなら release-please（Conventional Commits から次の版を決め、リリースの準備の PR を作る）が使える。GitHub Actions が作った PR には CI が動かないため、人が管理者の権限でマージする
- AI の作業環境からタグの push・リリースの作成ができないことがある。その場合は、リリースノートを用意して人に渡す

---

## 記載例

<details>
<summary>例: 個人開発（承認 0・自動マージ）</summary>

```markdown
scope（省略可）: `frontend` `backend` `shared` `db` `docs` `ci` `deps`
| ルールセット | PR 必須（承認数 0）・必須チェック `ci-ok` `conventional-commits` ... |
```

1人開発でも PR を必ず作る。CI の結果と PR の本文が、判断の記録になる。

</details>

<details>
<summary>例: 小規模チーム（承認 1・CODEOWNERS）</summary>

```markdown
| ルールセット | PR 必須（承認数 1・CODEOWNERS のレビュー必須）・会話の解決必須 ... |

- AI が作った PR も、人のレビューの承認が1件あるまでマージされない。自動マージは予約してよい（承認とチェックがそろった時点でマージされる）
- `.github/CODEOWNERS` で `/db/` `/.github/` は担当者のレビューを必須にする
```

</details>
