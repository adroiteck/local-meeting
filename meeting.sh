#!/bin/bash
set -euo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/sandbox-exec -f "$ROOT/src/offline.sb" /usr/bin/python3 "$ROOT/src/pipeline.py" "$@"
