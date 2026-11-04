# errnav プラグイン: PHP（Laravel・Symfony・素の PHP）
errnav_register php

errnav_php_detect() { [ -f "$1/composer.json" ] || [ -f "$1/artisan" ] || [ -f "$1/index.php" ]; }

errnav_php_logs() {
  printf '%s\n' 'storage/logs/*.log' 'var/log/*.log' 'php_errors.log' 'error_log' 'logs/php*.log'
}

# Monolog の JSON 形式（Symfony の既定など）は1行に全部が入っているので、トレースを1フレーム1行に分ける
errnav_php_preprocess() {
  awk '
    /^\{/ {
      gsub(/\\\//, "/")
      gsub(/\\n/, "\n    ")
      gsub(/","\//, "\",\n    \"/")
    }
    { print }'
}

errnav_php_hint() {
  if [ -f "$ERRNAV_ROOT/artisan" ]; then
    printf '%s\n' '- Laravel: ログは storage/logs/laravel.log。.env の APP_DEBUG=true で画面にもトレースが出る。テストは `php artisan test --filter <名前>`'
  elif [ -f "$ERRNAV_ROOT/bin/console" ]; then
    printf '%s\n' '- Symfony: ログは var/log/<環境>.log。`bin/console debug:router` などで設定を確かめられる'
  fi
}
