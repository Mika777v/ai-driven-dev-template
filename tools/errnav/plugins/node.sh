# errnav プラグイン: Node.js（Express・Next.js・NestJS など）
errnav_register node

errnav_node_detect() { [ -f "$1/package.json" ]; }

errnav_node_logs() {
  printf '%s\n' 'logs/*.log' 'npm-debug.log*' 'yarn-error.log' 'pnpm-debug.log' '.next/trace'
}

errnav_node_hint() {
  printf '%s\n' '- Node.js: ビルドした後の dist/ や .next/ のパスがトレースに出るときは、`node --enable-source-maps` で元のソースの行になる'
}
