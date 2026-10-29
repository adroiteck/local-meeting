#!/bin/bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then echo 'macOS 15 or later required.' >&2; exit 1; fi
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo 'Complete the Apple Command Line Tools installation, then rerun ./install.sh.' >&2
  exit 1
fi
exec /usr/bin/python3 "$ROOT/scripts/install.py" "$@"
