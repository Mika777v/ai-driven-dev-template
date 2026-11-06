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

- 12回（Sonnet・Haiku × template・bare × 3回）の読み比べは [results/2026-11-06-T4/README.md](results/2026-11-06-T4/README.md)
- 要点: スキーマと要件定義を変えた回で「確認が必要な項目」に申告したのは、ルールあり 5/5・ルールなし 0/6。「ルールのある Sonnet が作らずに聞く」は 1/3 だけ。ルールなしの Haiku も 2/3 で ADR を書いた（`docs/adr/README.md` に書くときのルールがあり、ルールなしの条件でも消していないため）
- テンプレートの README「ルールの効果」に節を足す PR を出した（下の「開いている PR」）
- 追加: `docs/adr/README.md` も消した条件 `none`（Sonnet・Haiku × 3回）。ADR は 0/6、オーナーの確認に触れた PR も 0/6。bare の Haiku が ADR を書いたのは ADR の README のためと確かめた
- 採点の直しどころ: `diff_hides_in_selection` は「カレンダーの画面を変えたか」だけで見ているので、API の既定で除く作りを見落とす。Sonnet・template の `typecheck_ok=0` は原因が未確認

## T2（続きの Task）— 終わった

- 6回（from-template・from-bare、Opus、各3回）の読み比べは [results/2026-11-06-T2/README.md](results/2026-11-06-T2/README.md)
- 要点: 続きの AI はルールを知らなくても、前の作業が残した物（コミットのメッセージ = 前の PR の本文・PROGRESS.md・手順書）を真似た。前がルールありなら、形のそろったコミットと PR・要件定義の変更の申告・文書の更新まで引き継がれた。前がルールなしなら、どれも引き継がれなかった。正しさ（18/18）と費用（約1.06倍）はほぼ同じ
- 採点の直しどころ: `leftover_files` は決定の記録の「200 文字から 100 文字に」も数えるので差を見分けない。`SCOPE_RE` にルートの `README.md` が無い

## まだやっていないこと

- T2 の発展: 続きの AI もルールありの条件（from-template をルールありで続ける）と比べる
- T4 を Opus でも動かす
- 担当ごとにモデルを変える運用（実装 Sonnet・探索 Haiku・レビュー Opus）を、Sonnet だけの条件と T4・T3 で比べる（`.claude/agents/` に役の定義を置いた条件を足す）。オーナーが採用を考えている
- 「足した ADR のルールで、AI が実際に ADR を書くか」の確認（T3 を新しい土台 `d4d15fd` で動かす）。T4 では Haiku・template が書いた

## 道具の場所

- このブランチ `bench/agent-bench` の `tools/agent-bench/`（main には入れない。routepense 専用のため）
- 作業用の取り出し場所（このマシン）: `/tmp/claude-0/-home-user/8e150239-dfa7-5669-a74d-b4e8cb00ad0f/scratchpad/agent-bench-code`（`git worktree`。ここで直して `git push origin HEAD:refs/heads/bench/agent-bench`）
- 準備済みの土台:
  - `.../scratchpad/agent-bench`（routepense `41ac314`。T0〜T3 と T2 の結果もここ）
  - `.../scratchpad/agent-bench-v2`（routepense `d4d15fd`。T4）
- マシンが替わっていたら、`git worktree add` か clone でこのブランチを取り出し、`run.sh prepare` からやり直す

## 開いている PR

- #7・#8・#9 はマージ済み（#9 は T4 の1回目だけ）。T4 の3回分の直しと T2 の節は [Mika777v/ai-driven-dev-template#10](https://github.com/Mika777v/ai-driven-dev-template/pull/10)（オーナーの確認待ち）
