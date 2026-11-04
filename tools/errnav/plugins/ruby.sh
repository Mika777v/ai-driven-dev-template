# errnav プラグイン: Ruby（Rails など）
errnav_register ruby

errnav_ruby_detect() { [ -f "$1/Gemfile" ]; }

errnav_ruby_logs() { printf '%s\n' 'log/*.log'; }

# Rails の開発のログは、トレースの行が字下げされずに並ぶ。続きの行として読めるように字下げする
errnav_ruby_preprocess() {
  awk '/^[^ \t]+\.rb:[0-9]+:in / { print "  " $0; next } { print }'
}

errnav_ruby_hint() {
  [ -f "$ERRNAV_ROOT/bin/rails" ] && printf '%s\n' '- Rails: ログは log/development.log。`bin/rails test <ファイル>:<行>` で1件だけテストできる'
  return 0
}
