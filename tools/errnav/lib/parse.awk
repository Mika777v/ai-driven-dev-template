# errnav: ログをエントリ（1件の記録）に分け、エラーのエントリだけを取り出して、スタックトレースを正規化する。
#
# POSIX awk だけで書く（macOS の awk・mawk・gawk のどれでも動かすため）。
#   - 正規表現の {n} の繰り返しは使わない（古い mawk が対応していない）
#   - match() の第3引数（gawk 専用）は使わない。RSTART / RLENGTH と substr で切り出す
#
# 入力の環境変数（正規表現は -v で渡さない。-v の値はエスケープが処理され、gawk では「\[」の「\」が消えるため）:
#   ERRNAV_AWK_ENTRY_RE   エントリの始まりの行の正規表現。空なら「字下げの無い行で始まる」とみなす（タイムスタンプの無い出力向け）
#   ERRNAV_AWK_ERROR_RE   エラーとみなす行の正規表現
# 入力の変数（-v で渡す）:
#   logname    出力に書くログの名前
#   id0        イベントの番号の開始（この値の次から振る）
#   lineoff    ログの行番号に足す値（ログの途中から読むとき）
#   rawdir     イベントの元のテキストを書き出すディレクトリ
#   events     イベントの一覧の出力先（TSV）
#   frames     フレームの一覧の出力先（TSV）
#   warn       1 なら WARN もエラーとして扱う
#
# 出力:
#   events: id  log  logline  time  level  summary  header  root
#   frames: id  idx  file  line  func        （idx 0 = 発生箇所。外側の呼び出しほど大きい。
#           例外が連鎖しているときは、根本の原因（Java の最後の Caused by・Python の最後の Traceback）を先にする）

function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function clean(s) { gsub(/[\t\r]/, " ", s); s = trim(s); if (length(s) > 400) s = substr(s, 1, 400) "…"; return s }
function indented(s) { return s ~ /^[ \t]/ }

function reset_entry() {
  n = 0; nf = 0; in_tb = 0; tb_expect_exc = 0; in_panic = 0; pyblock = 0; cblock = 0
  exc_first = ""; exc_last = ""; root = ""; prev = ""
}

# ---- フレームの追加 ----------------------------------------------------------
function addf(f, l, fn, blk,   key) {
  if (f == "" || l == "" || l !~ /^[0-9]+$/) return
  sub(/^file:\/\//, "", f)
  key = f ":" l
  if (nf > 0 && fk[nf] == key) { if (fu[nf] == "") fu[nf] = fn; return }
  nf++; ff[nf] = f; fl[nf] = l; fu[nf] = trim(fn); fk[nf] = key; fb[nf] = blk; fc[nf] = cblock
}

# 1行からフレームを読み取る。読み取れたら 1 を返す
function parse_frame(s,   seg, f, l, fn, p, q, rest, fq, pkg) {
  if (s ~ /^[ \t]*thrown in /) return 0          # PHP の「thrown in」は発生箇所の繰り返し
  # Python:   File "/app/x.py", line 10, in main
  if (match(s, /File "[^"]+", line [0-9]+/)) {
    seg = substr(s, RSTART, RLENGTH); rest = substr(s, RSTART + RLENGTH)
    p = index(seg, "\""); q = substr(seg, p + 1); f = substr(q, 1, index(q, "\"") - 1)
    l = seg; sub(/^.*line /, "", l)
    fn = ""; if (rest ~ /^, in /) { fn = rest; sub(/^, in /, "", fn) }
    addf(f, l, fn, pyblock); return 1
  }
  # PHP:   #0 /var/www/html/app/Foo.php(42): Foo->bar()
  if (match(s, /^#[0-9]+ [^ ]+\([0-9]+\)/)) {
    seg = substr(s, RSTART, RLENGTH); rest = substr(s, RSTART + RLENGTH)
    sub(/^#[0-9]+ /, "", seg)
    match(seg, /\([0-9]+\)$/)
    f = substr(seg, 1, RSTART - 1); l = substr(seg, RSTART + 1, RLENGTH - 2)
    fn = rest; sub(/^: /, "", fn)
    addf(f, l, fn, 0); return 1
  }
  # PHP:   ... in /var/www/html/app/Foo.php on line 42
  if (match(s, /in [^ ]+ on line [0-9]+/)) {
    seg = substr(s, RSTART + 3, RLENGTH - 3)
    f = seg; sub(/ on line [0-9]+$/, "", f)
    l = seg; sub(/^.* on line /, "", l)
    addf(f, l, "", 0); return 1
  }
  # Java / Kotlin:   at com.example.Foo.bar(Foo.java:42)
  if (match(s, /at [A-Za-z0-9_$.<>\/]+\([A-Za-z0-9_$]+\.(java|kt|scala|groovy):[0-9]+\)/)) {
    seg = substr(s, RSTART + 3, RLENGTH - 4)
    fq = substr(seg, 1, index(seg, "(") - 1); sub(/^.*\//, "", fq)   # java.base/... のモジュール名を外す
    rest = substr(seg, index(seg, "(") + 1)
    f = rest; sub(/:[0-9]+$/, "", f)
    l = rest; sub(/^.*:/, "", l)
    # パッケージ名からディレクトリを作る（com.example.Foo.bar → com/example/Foo.java）
    pkg = fq; sub(/\.[^.]+$/, "", pkg)          # メソッド名を外す
    sub(/\.[^.]+$/, "", pkg)                    # クラス名を外す
    if (pkg != "" && pkg != fq) { gsub(/\./, "/", pkg); f = pkg "/" f }
    addf(f, l, fq, 0); return 1
  }
  # Node.js:   at load (/srv/app/src/app.js:3:12)
  if (match(s, /at [^()]*\([^()]+:[0-9]+:[0-9]+\)/)) {
    seg = substr(s, RSTART + 3, RLENGTH - 4)
    fn = trim(substr(seg, 1, index(seg, "(") - 1))
    rest = substr(seg, index(seg, "(") + 1)
    sub(/:[0-9]+$/, "", rest)                   # 列を外す
    l = rest; sub(/^.*:/, "", l)
    f = rest; sub(/:[0-9]+$/, "", f)
    addf(f, l, fn, 0); return 1
  }
  # Node.js（無名関数）:   at /srv/app/src/app.js:3:12
  if (match(s, /at [^ ()]+:[0-9]+:[0-9]+$/)) {
    rest = substr(s, RSTART + 3); sub(/:[0-9]+$/, "", rest)
    l = rest; sub(/^.*:/, "", l)
    f = rest; sub(/:[0-9]+$/, "", f)
    addf(f, l, "", 0); return 1
  }
  # Ruby:   from /app/lib/x.rb:5:in `run'   /   /app/lib/x.rb:2:in 'Object#boom'
  if (match(s, /[^ \t:'"`]+\.rb:[0-9]+:in /)) {
    seg = substr(s, RSTART, RLENGTH); rest = substr(s, RSTART + RLENGTH)
    sub(/:in $/, "", seg)
    l = seg; sub(/^.*:/, "", l)
    f = seg; sub(/:[0-9]+$/, "", f)
    fn = rest; sub(/^[`']/, "", fn); sub(/'.*$/, "", fn)
    addf(f, l, fn, 0); return 1
  }
  # Go:   <TAB>/go/src/app/main.go:8 +0x18   （関数名は前の行）
  if (match(s, /^\t[^ ]+\.go:[0-9]+/)) {
    seg = substr(s, RSTART + 1, RLENGTH - 1)
    l = seg; sub(/^.*:/, "", l)
    f = seg; sub(/:[0-9]+$/, "", f)
    fn = trim(prev); sub(/\(.*$/, "", fn)
    addf(f, l, fn, 0); return 1
  }
  # そのほか:   path/to/file.ext:42   （/ を含むパスだけ。URL の host:port は除く）
  if (match(s, /[A-Za-z0-9_.~\/-]*\/[A-Za-z0-9_.-]+\.[A-Za-z0-9]+:[0-9]+/)) {
    if (RSTART > 1 && substr(s, RSTART - 1, 1) == ":") return 0
    seg = substr(s, RSTART, RLENGTH)
    if (seg ~ /^\/\//) return 0
    l = seg; sub(/^.*:/, "", l)
    f = seg; sub(/:[0-9]+$/, "", f)
    addf(f, l, "", 0); return 1
  }
  return 0
}

# ---- エントリの区切り ----------------------------------------------------------
# この行が、いまのエントリの続きかどうか
function is_continuation(s) {
  if (n == 0) return 0
  if (entry_re != "") return (s !~ entry_re)
  # タイムスタンプの無い出力: 字下げ・空行・既知の続きの行は続き
  if (s ~ /^[ \t]*$/ || indented(s)) return 1
  if (s ~ /^(Stack trace:|#[0-9]+ |Caused by: |Suppressed: |Traceback \(most recent call last\)|During handling of the above exception|The above exception was the direct cause)/) return 1
  if (in_tb && tb_expect_exc) return 1          # Python のトレースの最後の例外の行
  if (in_panic && s ~ /^(goroutine [0-9]+ |created by |\[signal |exit status |[A-Za-z_][^ ]*\(.*\)$)/) return 1
  return 0
}

function level_of(h,   u, m) {
  u = h
  if (match(u, /"(level|severity)" *: *"[A-Za-z]+"/)) { m = substr(u, RSTART, RLENGTH); sub(/^.*: *"/, "", m); sub(/"$/, "", m); return toupper(m) }
  if (match(u, /(level|lvl)=[A-Za-z]+/)) { m = substr(u, RSTART, RLENGTH); sub(/^.*=/, "", m); return toupper(m) }
  if (u ~ /^panic: / || u ~ /^fatal error: /) return "PANIC"
  if (u ~ /^PHP Fatal error/) return "FATAL"
  if (u ~ /^PHP (Warning|Deprecated|Notice)/) return "WARNING"
  if (match(u, /(^|[^A-Za-z])(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|ERR|CRITICAL|CRIT|ALERT|EMERGENCY|EMERG|FATAL|SEVERE|PANIC)([^A-Za-z]|$)/)) {
    m = substr(u, RSTART, RLENGTH); gsub(/[^A-Z]/, "", m); return m
  }
  return ""
}

function is_error_level(lv) { return lv ~ /^(ERR|ERROR|CRIT|CRITICAL|ALERT|EMERG|EMERGENCY|FATAL|SEVERE|PANIC)$/ || (warn && lv ~ /^WARN/) }
function is_quiet_level(lv) { return lv ~ /^(TRACE|DEBUG|INFO|NOTICE)$/ || (!warn && lv ~ /^WARN/) }

function summary_of(h,   s, p) {
  s = h
  sub(/^\[[^]]*\] */, "", s)
  sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ T][0-9][0-9]:[0-9][0-9]:[0-9][0-9][^ ]* */, "", s)
  # レベルの前置きを外す（Laravel の「local.ERROR: 」、「ERROR 」など）
  sub(/^[A-Za-z0-9_-]*\.?(ERROR|ERR|CRITICAL|CRIT|ALERT|EMERGENCY|EMERG|FATAL|SEVERE|WARNING|WARN)(:| -- :|:? +)/, "", s)
  s = trim(s)
  p = index(s, " {\""); if (p > 1) s = substr(s, 1, p - 1)     # 後ろの JSON のコンテキストは省く
  return s
}

function flush(   lv, iserr, i, b, k, sum, ts, f, out) {
  if (n == 0) return
  lv = level_of(L[1])
  iserr = 0
  if (is_error_level(lv)) iserr = 1
  else if (!is_quiet_level(lv) && L[1] ~ error_re) iserr = 1
  else if (lv == "" && nf > 0) { for (i = 1; i <= n; i++) if (L[i] ~ error_re) { iserr = 1; break } }
  if (!iserr) return

  id++
  ts = ""
  if (match(L[1], /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ T][0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) ts = substr(L[1], RSTART, RLENGTH)
  if (in_tb && exc_last != "") sum = exc_last
  else if (exc_first != "") sum = exc_first
  else sum = summary_of(L[1])
  if (lv == "") lv = "ERROR"
  printf "%d\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n", id, logname, start + lineoff, ts, lv, clean(sum), clean(L[1]), clean(root) >> events

  out = rawdir "/" id ".txt"
  for (i = 1; i <= n; i++) print L[i] > out
  close(out)

  # フレームを「0 = 発生箇所」の順にそろえる。Python のブロックは外側から内側へ書かれているので逆にする
  k = 0
  for (b = pyblock; b >= 1; b--)
    for (i = nf; i >= 1; i--) if (fb[i] == b) { printf "%d\t%d\t%s\t%s\t%s\n", id, k, ff[i], fl[i], clean(fu[i]) >> frames; k++ }
  # Java などの「Caused by:」は、最後（根本の原因）のブロックを先にする
  for (b = cblock; b >= 0; b--)
    for (i = 1; i <= nf; i++) if (fb[i] == 0 && fc[i] == b) { printf "%d\t%d\t%s\t%s\t%s\n", id, k, ff[i], fl[i], clean(fu[i]) >> frames; k++ }
  close(events); close(frames)
}

BEGIN {
  entry_re = ENVIRON["ERRNAV_AWK_ENTRY_RE"]; error_re = ENVIRON["ERRNAV_AWK_ERROR_RE"]
  id = id0 + 0; lineoff = lineoff + 0; reset_entry()
}

{
  s = $0; sub(/\r$/, "", s)
  if (!is_continuation(s)) {
    flush(); reset_entry(); start = NR
    if (s ~ /^(panic|fatal error): /) in_panic = 1
  }
  n++; L[n] = s

  if (s ~ /^Traceback \(most recent call last\)/) { in_tb = 1; tb_expect_exc = 1; pyblock++ }
  else if (in_tb && tb_expect_exc && !indented(s) && s !~ /^[ \t]*$/ && n > 1) { exc_last = trim(s); tb_expect_exc = 0 }

  if (s ~ /^(Exception in thread "[^"]*" |Caused by: )?[A-Za-z_$][A-Za-z0-9_$.]*(Error|Exception|Throwable|Fault)[A-Za-z]*(: |:$|$)/) {
    if (exc_first == "") { exc_first = s; sub(/^Exception in thread "[^"]*" /, "", exc_first) }
    if (s ~ /^Caused by: /) { root = s; sub(/^Caused by: /, "", root); cblock++ }
  }

  parse_frame(s)
  prev = s
}

END { flush() }
