# 引き継ぎ（agent-bench）

> 2026-11-06 に、会話のコンテキストをリセットする前に書いた。次の作業は、このファイルから始める。

## これまでにわかったこと

結果の表はテンプレートの `README.md`「ルールの効果（測った結果）」にある（[#7](https://github.com/Mika777v/ai-driven-dev-template/pull/7) でマージ済み、影響度とモデルの節は [#8](https://github.com/Mika777v/ai-driven-dev-template/pull/8) で確認待ち）。

- 仕様のはっきりした Task では、ルールの有無で**正しさは変わらない**（Opus・Sonnet・Haiku のどれでも。データが消える落とし穴もルール無しで避けた）
- ルールがあると、AI の作業は**約2倍**（影響度が高いほど大きい。1.3〜2.6倍）
- ルールで得られるのは**人のための成果物**: 「確認が必要な項目」の申告・形のそろった PR とコミット・文書の更新。ルールが無いと、テーブルの作り直しでも申告が無い
- CLAUDE.md で案内するかの差は小さい（強いモデルは、ルールの文書があれば自分で探す）。弱いモデルほど全部は守らない
- AI は ADR を一度も書かなかった → テンプレートと routepense に「後から変えにくいことを決めたら ADR を書く」を足した（テンプレート #7、routepense #105）

## 実行中だったもの: T4（仕様の曖昧な Task）

- Task: [tasks/T4-tidy-routes/task.md](tasks/T4-tidy-routes/task.md)「使わなくなったルートを片付けたい」（わざと曖昧）
- 土台: routepense の `d4d15fd`（ADR のルールが入り、教科書のルールが外れた main）
- 条件: Sonnet・Haiku × template・bare（各1回、計4回）
- 結果の置き場所: `/tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-v2/runs/`（このマシンの一時的な場所。マシンが替わると消える）
  - 3回は終わっていた（template-sonnet・bare-sonnet・template-haiku）。bare-haiku は動いている途中だった
  - 終わっているかは `ls .../runs/*.score` で、4つあれば全部終わり

### 次にやること

1. 4回が終わっていることを確かめ、表を出す:
   ```bash
   cd /tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-code
   BENCH_OUT=/tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-v2 BENCH_TASK=T4-tidy-routes bash tools/agent-bench/run.sh report
   ```
2. 4つの PR の本文（`runs/*.pr_body.md`）と差分（`runs/*.diff`）を読み比べる。見ること:
   - 「片付ける」をどう読んだか（消す / 隠す・アーカイブ / 一覧だけから外す）
   - データを残す作りにしたか（`diff_keeps_data`）、出勤の選択肢からも外したか（`diff_hides_in_selection`）
   - 要件の変更・スキーマの変更を申告したか（`pr_confirm_declared`）、ADR を書いたか（`touched_adr`）、要件定義を直したか
   - 決めたことと選択肢を PR に書いたか
3. 結果を残す: `runs/` の `*.score`・`*.pr_body.md`・`*.pr_title.txt`・`*.diff` と `results.tsv` を、このブランチの `tools/agent-bench/results/2026-11-06-T4/` にコミットする（`*.jsonl` は大きいので入れない）。わかったことを README の「ルールの効果」に足す PR をテンプレートに作る（#8 がマージ済みなら新しい PR）

## まだやっていないこと

- **T2（続きの Task）**: 前の作業が残した物（要件定義・教科書・手順書・コミットのメッセージ）が、後から作業する AI の役に立つか。道具は完成（`BENCH_TASK=T2-note-followup`、条件 `from-template`・`from-bare`）。土台は古い `41ac314` 側の結果なので、`BENCH_OUT` は `.../scratchpad/agent-bench`（v2 ではない）。**未実行**
- 各条件を複数回に増やして、ばらつきを見る
- 「足した ADR のルールで、AI が実際に ADR を書くか」の確認（T3 を新しい土台 `d4d15fd` で動かす）

## 道具の場所

- このブランチ `bench/agent-bench` の `tools/agent-bench/`（main には入れない。routepense 専用のため）
- 作業用の取り出し場所（このマシン）: `/tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-code`（`git worktree`。ここで直して `git push origin HEAD:refs/heads/bench/agent-bench`）
- 準備済みの土台:
  - `.../scratchpad/agent-bench`（routepense `41ac314`。T0〜T3 と T2 の結果もここ）
  - `.../scratchpad/agent-bench-v2`（routepense `d4d15fd`。T4）
- マシンが替わっていたら、`git worktree add` か clone でこのブランチを取り出し、`run.sh prepare` からやり直す

## 開いている PR

- [Mika777v/ai-driven-dev-template#8](https://github.com/Mika777v/ai-driven-dev-template/pull/8)（README に影響度とモデルの結果）— オーナーの確認待ち
