# errnav のベンチマーク

> **目的**: errnav で AI の不具合の調査が本当に安く・速くなるかを測る。同じ不具合を「errnav なし」と「errnav あり」で AI（Claude Code）に調べさせ、ツールの呼び出しの回数・トークン・料金・時間・正解したかを比べる。
> **いつ読むか**: errnav の効果を確かめたいとき・errnav を直した後に効果が落ちていないかを見るとき。

## 対象と不具合

対象は [routepense](https://github.com/Mika777v/routepense)（TypeScript・Node.js・Express・SQLite・vitest）。`bench/errnav-bugs` ブランチに、型チェックは通るがテストが落ちる不具合を3つ仕込んである（main には入れない）。

| ID | 種類 | 不具合 | テストの見え方 | errnav が示す場所 |
|---|---|---|---|---|
| B1 | 例外（落ちる場所と原因が離れている） | 記録を読む `get()` の SQL の引数の順番が逆 | `Error: 保存した記録が見つかりません` | 例外を投げた `saveWorkStyle`（原因はその上の `get()`） |
| B2 | ライブラリの奥のエラー | ルートの INSERT で運賃と交通手段の値が入れ違い | `CHECK constraint failed: transport IN (...)` | `.run()` の行（原因は数行下の引数の並び） |
| B3 | 例外なし（値だけが違う） | 一括設定の日付のループが `<` で、最後の日が抜ける | アサーションの失敗だけ | テストの行（原因の `bulk.ts` は示せない） |

正解の範囲は [`scenarios.tsv`](scenarios.tsv)。errnav が示す行をそのまま答えただけでは正解にならないようにしてある（B1・B2）。

## 条件

| | なし（without） | あり（with） |
|---|---|---|
| リポジトリ | routepense の main + 不具合 | 同じ + `tools/errnav`（テストの材料は除く）+ `CLAUDE.md` に errnav の1行 |
| 指示 | 「`npm test` が失敗している。原因の場所（ファイルと行）を特定し、理由を説明。直さない。最後の行は `原因: <ファイル>:<行>`」 | 同じ + 「まず `npm test 2>&1 \| errnav scan -`、`errnav context latest` から調べ始めて」 |

そろえていること:

- **毎回まっさらな作業場所。** git の履歴は1コミットだけにする（不具合を仕込んだコミットから答えが見えないように）
- 使えるツールは Bash・Read・Grep・Glob だけ。書き換え・サブエージェント（呼び出しの回数が数えられなくなる）・Web は使わせない
- ユーザーの設定（フック）と MCP は読まない（`--setting-sources project,local --strict-mcp-config`）
- モデルは `BENCH_MODEL` で固定する（比べるときは必ず固定）

## 使い方

必要なもの: git・jq・Node.js 22・Claude Code の CLI（ログイン済み）。

```bash
bash tools/errnav/bench/run.sh prepare
```

```bash
bash tools/errnav/bench/run.sh dry
```

```bash
BENCH_MODEL=<使うモデル> bash tools/errnav/bench/run.sh run
```

```bash
bash tools/errnav/bench/run.sh report
```

- `prepare`: routepense を取得し、依存を入れる（1回だけ）
- `dry`: **AI を動かさずに**、各シナリオでテストが落ちることと、errnav が何を示すかを確かめる
- `run`: AI を動かして測る。**料金がかかる**（3シナリオ × 2条件 × 3回 = 18回。1回の上限は `BENCH_MAX_BUDGET` ドル、既定 2）。途中で止めても、済んだ回は飛ばして続きから動く
- `report`: 結果の表

少しだけ試すとき:

```bash
BENCH_ONLY=B1 BENCH_RUNS=1 bash tools/errnav/bench/run.sh run
```

結果は `BENCH_OUT`（既定 `${TMPDIR:-/tmp}/errnav-bench`）に残る。

| ファイル | 内容 |
|---|---|
| `runs/<ID>-<条件>-<回>.jsonl` | AI のやりとりの全部（`--output-format stream-json`） |
| `runs/<ID>-<条件>-<回>.meta` | 終了コード・かかった秒・書き換えたファイルの数 |
| `results.tsv` | 1回ごとの結果（正解・ツールの回数と内訳・ターン・トークン・料金・秒・答え） |

## 結果の読み方

- **正解(行)**: 答えのファイルと行が正解の範囲に入った回数。**正解(file)**: ファイルだけ合った回数
- **ツール**: ツールの呼び出しの平均回数（内訳は `results.tsv` の bash・read・grep・glob）
- **トークン**: 入力・出力・キャッシュの作成・キャッシュの読み出しの合計の平均。料金は Claude Code が報告した値
- 1つの条件で3回だけなので、差が小さいときは「差が無い」と読む。はっきり決めたいときは `BENCH_RUNS` を増やす

見込み: B1・B2 は「あり」のほうがツールの回数が減る。B3 は errnav が原因の場所を示せないので、差が小さいか、errnav を動かした分だけ「あり」が高くなる。

## 不具合を足す・変える

1. routepense の `bench/errnav-bugs` ブランチに、件名が `bench: B4 ...` のコミットを1つ足す（1コミット = 1つの不具合。型チェックは通し、テストは落ちるようにする）
2. `scenarios.tsv` に1行足す（正解のファイルと行の範囲）
3. `run.sh prepare`（取り直す）→ `run.sh dry` で確かめる
