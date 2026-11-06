# 引き継ぎ（agent-bench）

> 2026-11-06 に、会話のコンテキストをリセットする前に書いた。次の作業は、このファイルから始める。

## これまでにわかったこと

結果の表はテンプレートの `README.md`「ルールの効果（測った結果）」にある（[#7](https://github.com/Mika777v/ai-driven-dev-template/pull/7) でマージ済み、影響度とモデルの節は [#8](https://github.com/Mika777v/ai-driven-dev-template/pull/8) でマージ済み、T4 の節は [#9](https://github.com/Mika777v/ai-driven-dev-template/pull/9) で確認待ち）。

- 仕様のはっきりした Task では、ルールの有無で**正しさは変わらない**（Opus・Sonnet・Haiku のどれでも。データが消える落とし穴もルール無しで避けた）
- ルールがあると、AI の作業は**約2倍**（影響度が高いほど大きい。1.3〜2.6倍）
- ルールで得られるのは**人のための成果物**: 「確認が必要な項目」の申告・形のそろった PR とコミット・文書の更新。ルールが無いと、テーブルの作り直しでも申告が無い
- CLAUDE.md で案内するかの差は小さい（強いモデルは、ルールの文書があれば自分で探す）。弱いモデルほど全部は守らない
- AI は ADR を一度も書かなかった → テンプレートと routepense に「後から変えにくいことを決めたら ADR を書く」を足した（テンプレート #7、routepense #105）

## T4（仕様の曖昧な Task）— 終わった

- 4回（Sonnet・Haiku × template・bare）の読み比べは [results/2026-11-06-T4/README.md](results/2026-11-06-T4/README.md)
- 要点: ルールが無いと、Sonnet も Haiku も黙って DB のスキーマと要件定義を変えた。ルールのある Sonnet は作らずに聞き、ルールのある Haiku は作ったうえで申告して ADR を書いた（AI が ADR を書いたのは初めて）
- テンプレートの README「ルールの効果」に節を足す PR を出した（下の「開いている PR」）
- 採点の直しどころ: `diff_hides_in_selection` は「カレンダーの画面を変えたか」だけで見ているので、API の既定で除く作りを見落とす。Sonnet・template の `typecheck_ok=0` は原因が未確認

## まだやっていないこと

- **T2（続きの Task）**: 前の作業が残した物（要件定義・教科書・手順書・コミットのメッセージ）が、後から作業する AI の役に立つか。道具は完成（`BENCH_TASK=T2-note-followup`、条件 `from-template`・`from-bare`）。土台は古い `41ac314` 側の結果なので、`BENCH_OUT` は `.../scratchpad/agent-bench`（v2 ではない）。**未実行**
- 各条件を複数回に増やして、ばらつきを見る（特に T4 の「ルールのある Sonnet が作らずに聞く」が毎回起きるか）。T4 を Opus でも動かす
- 「足した ADR のルールで、AI が実際に ADR を書くか」の確認（T3 を新しい土台 `d4d15fd` で動かす）。T4 では Haiku・template が書いた

## 道具の場所

- このブランチ `bench/agent-bench` の `tools/agent-bench/`（main には入れない。routepense 専用のため）
- 作業用の取り出し場所（このマシン）: `/tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-code`（`git worktree`。ここで直して `git push origin HEAD:refs/heads/bench/agent-bench`）
- 準備済みの土台:
  - `.../scratchpad/agent-bench`（routepense `41ac314`。T0〜T3 と T2 の結果もここ）
  - `.../scratchpad/agent-bench-v2`（routepense `d4d15fd`。T4）
- マシンが替わっていたら、`git worktree add` か clone でこのブランチを取り出し、`run.sh prepare` からやり直す

## 開いている PR

- [Mika777v/ai-driven-dev-template#9](https://github.com/Mika777v/ai-driven-dev-template/pull/9)（README に T4 の結果）— オーナーの確認待ち。#7・#8 はマージ済み
