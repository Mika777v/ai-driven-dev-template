# errnav プラグイン: Go
errnav_register go

errnav_go_detect() { [ -f "$1/go.mod" ]; }

errnav_go_logs() { printf '%s\n' 'logs/*.log' '*.log'; }

errnav_go_hint() {
  printf '%s\n' '- Go: パスがビルドしたマシンのもの（-trimpath ならモジュール名から）でも、末尾で手元のファイルに結び付ける。`GOTRACEBACK=all` で全部の goroutine が出る'
}
