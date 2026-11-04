# agent-bench — テンプレートの効果を測るベンチマーク

> **目的**: このテンプレートの運用ルール（CLAUDE.md / AGENTS.md）が、AI の作業を本当に良くしているかを測る。同じ Task を「テンプレートあり」と「最小限の CLAUDE.md」で AI（Claude Code）に実装させ、**機能が正しいか**・**ルールを守ったか**・**使った量**を比べる。
> **いつ読むか**: テンプレートのルールを足す・削るときに、効果を確かめたいとき。

errnav だけの効果は [`tools/errnav/bench/`](../errnav/bench/README.md) で測る。こちらは運用のルール全体が対象。

## しくみ

| | 内容 |
|---|---|
| 対象 | [routepense](https://github.com/Mika777v/routepense) の `41ac314`（CLAUDE.md を短くした後の main。要点9項目 + 「いつ何を読むか」、全文は `docs/DEV_RULES.md`） |
| 条件 `template` | CLAUDE.md をそのまま使う |
| 条件 `minimal` | CLAUDE.md を、説明・技術スタック・コマンドだけにする（[fixtures/routepense-minimal-CLAUDE.md](fixtures/routepense-minimal-CLAUDE.md)）。ほかのファイル（`docs/DEV_RULES.md`・PR テンプレートなど）は同じだが、CLAUDE.md から案内されない |
| 指示 | 両方で同じ。「Task を実装して PR を出す直前まで。PR のタイトルと本文は `PR_TITLE.txt`・`PR_BODY.md` に。コミットまで。質問はできないので自分で決めて PR の本文に書く」+ Task の本文。**運用のルールのことは書かない** |
| ツール | Bash・Read・Grep・Glob・Edit・Write・Skill。サブエージェント・Web は使わせない。ユーザーの設定と MCP は読まない |
| 作業場所 | 毎回まっさら。git の履歴は1コミットだけ。GitHub にはつながらない |

## Task

| ID | 内容 | なぜこれか |
|---|---|---|
| [T1-daily-note](tasks/T1-daily-note/task.md) | 日次記録にメモを付ける（API・画面・CSV） | DB のスキーマが変わる（「確認が必要な項目」を申告するか）。DB・API・画面・CSV・文書と触る層が多い。正しさを受け入れテストで判定しやすい |

Task のディレクトリ:

| ファイル | 内容 |
|---|---|
| `task.md` | AI に渡す Task の本文 |
| `acceptance/` | **AI には見せない**受け入れテスト。作業の後に作業場所に置いて流す |
| `reference.patch` | 正解の実装の一例（backend と shared だけ）。受け入れテストと採点が正しいかを確かめるため（`dry`）。AI には見せない |
| `config.sh` | 採点の設定（受け入れテストの置き場所・申告すべきこと・変えてよい場所など） |

## 採点（[score.sh](score.sh)）

| 項目 | 意味 |
|---|---|
| `accept_passed` / `accept_total` | **受け入れテスト**の通った数 / 全部の数。何もしなくても 2 件は通る（壊していないかの確認） |
| `suite_ok`・`typecheck_ok`・`lint_ok` | 既存のテスト・型チェック・lint が通る（受け入れテストを置く前） |
| `branch_ok`・`branch_named` | main 以外のブランチで作業した・`feat/` などの名前 |
| `commits_conventional`・`uncommitted` | コミットのメッセージが Conventional Commits（決まった type・scope）・コミットしていない変更の数 |
| `pr_title_ok`・`pr_sections_ok` | PR のタイトルの形・本文が PR テンプレートの見出しに沿う |
| `pr_confirm_declared` | PR の本文の「確認が必要な項目」で、DB のスキーマの変更を申告した |
| `pr_links_issue` | `Closes #` / `Part of #` を書いた（この Task には Issue の番号が無いので、書かないのが正しいこともある。参考） |
| `touched_*` | 教科書・`openapi.yaml`・画面・手順書・PROGRESS・マイグレーションを変えた |
| `migration_rewritten` | 既にあるマイグレーションの SQL を書き換えた（してはいけない） |
| `out_of_scope` | 変えてよい場所の外のファイルを変えた数 |

**読み方**: ルールの項目の多くは `template` に有利（CLAUDE.md に書いてあることを守るか、を見ている）。主な指標は **受け入れテスト** と **使った量**（トークン・ターン・時間）。ルールの項目は「書いておけば守るか」「書いていないと、どれくらい自然に守るか」の確認として読む。

## 使い方

必要なもの: git・jq・Node.js 22・Claude Code の CLI（ログイン済み）。

```bash
bash tools/agent-bench/run.sh prepare
```

```bash
bash tools/agent-bench/run.sh dry
```

```bash
BENCH_MODEL=<使うモデル> bash tools/agent-bench/run.sh run
```

```bash
bash tools/agent-bench/run.sh report
```

- `dry`: **AI を動かさずに**、何もしない作業場所では受け入れテストが落ち、正解の実装（`reference.patch`）では全部通ることを確かめる
- `run`: 2条件 × 2回 = 4回。1回は 10〜20 分・20〜40 ターンくらいの見込み。**利用枠を多く使う**（errnav のベンチの1回の 10 倍くらい）。1回の上限は `BENCH_MAX_BUDGET` ドル（既定 5）・`BENCH_TIMEOUT` 秒（既定 1800）。済んだ回は飛ばすので、分けて動かせる
- 1回だけ試す: `BENCH_RUNS=1 BENCH_CONDITIONS=template bash tools/agent-bench/run.sh run`

結果は `BENCH_OUT`（既定 `${TMPDIR:-/tmp}/agent-bench`）の `runs/` に残る。

| ファイル | 内容 |
|---|---|
| `<Task>-<条件>-<回>.jsonl` | AI のやりとりの全部 |
| `.score` | 採点の結果（項目と値） |
| `.diff`・`.pr_title.txt`・`.pr_body.md` | AI が作った変更と PR の文面（人が読んで確かめる用） |
| `results.tsv` | 全部の回の表 |

## Task を足す

1. `tasks/<ID>/` に `task.md`・`acceptance/`・`config.sh` を置く（T1 をまねる）
2. 正解の実装を手で作り、受け入れテストが全部通ることを確かめて `reference.patch` にする（受け入れテストの誤りを見つけるため）
3. `BENCH_TASK=<ID> bash tools/agent-bench/run.sh dry`
