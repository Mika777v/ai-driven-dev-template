# errnav プラグイン: Java / Kotlin（Spring Boot など）
errnav_register java

errnav_java_detect() {
  [ -f "$1/pom.xml" ] || [ -f "$1/build.gradle" ] || [ -f "$1/build.gradle.kts" ]
}

errnav_java_logs() {
  printf '%s\n' 'logs/*.log' 'log/*.log' '*.log'
}

# トレースには「パッケージ/クラス名.java」しか出ないので、ソースの置き場所を足して探す
errnav_java_src_roots() {
  printf '%s\n' src/main/java src/main/kotlin src/test/java src/test/kotlin
  # マルチモジュール（*/src/main/java）
  (cd "$ERRNAV_ROOT" 2>/dev/null && for d in */src/main/java */src/main/kotlin; do [ -d "$d" ] && printf '%s\n' "$d"; done)
}

errnav_java_hint() {
  printf '%s\n' '- Java: 「Caused by:」の最後が根本の原因。「... N more」は上と同じフレームの省略'
}
