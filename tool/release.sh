#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OS="$(uname -s)"

flutter_build() {
  flutter build "$@"
}

# ---------- builders ----------

build_web()     { flutter_build web --release --base-href=/Cartoria/; }
build_apk()     { flutter_build apk --release --split-per-abi; }
build_aab()     { flutter_build appbundle --release; }
build_macos()   { flutter_build macos --release; }
build_ios()     { flutter_build ios --release; }
build_windows() { flutter_build windows --release; }
build_linux()   { flutter_build linux --release; }

build_all() {
  build_web
  build_apk
  case "$OS" in
    Darwin)
      build_macos
      build_ios
      ;;
    Linux)
      build_linux
      ;;
    MINGW*|MSYS*|CYGWIN*)
      build_windows
      ;;
  esac
}

# ---------- dispatch ----------

cmd="${1:-}"

# clean doesn't need dart-defines
if [[ "$cmd" == "clean" ]]; then
  flutter clean
  exit 0
fi

case "$cmd" in
  web)     build_web ;;
  apk)     build_apk ;;
  aab)     build_aab ;;
  macos)   build_macos ;;
  ios)     build_ios ;;
  windows) build_windows ;;
  linux)   build_linux ;;
  all)     build_all ;;
  *)
    echo "Usage: $0 {web|apk|aab|macos|ios|windows|linux|all|clean}"
    exit 1
    ;;
esac