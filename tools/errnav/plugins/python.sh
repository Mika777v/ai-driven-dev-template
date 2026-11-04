# errnav プラグイン: Python（Django・Flask・FastAPI など）
errnav_register python

errnav_python_detect() {
  [ -f "$1/pyproject.toml" ] || [ -f "$1/requirements.txt" ] || [ -f "$1/setup.py" ] || [ -f "$1/manage.py" ]
}

errnav_python_logs() {
  printf '%s\n' 'logs/*.log' '*.log' 'log/*.log'
}

errnav_python_src_roots() { printf '%s\n' src; }

errnav_python_hint() {
  [ -f "$ERRNAV_ROOT/manage.py" ] && printf '%s\n' '- Django: settings の DEBUG=True で画面にトレースが出る。テストは `python manage.py test <名前>`'
  printf '%s\n' '- Python: 例外が連鎖しているときは、最後の Traceback が実際に投げられたもの（このツールのフレーム 0 はその発生箇所）'
}
