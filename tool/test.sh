#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Static analysis first — catches type errors before tests run.
flutter analyze

# All pure-Dart + widget tests. No device required.
flutter test "$@"