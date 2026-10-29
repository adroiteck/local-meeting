#!/bin/bash
# Source-only, explicit allowlist: no meeting data, logs, models or machine-specific builds.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$ROOT/local-meeting-source.tar.gz}"
/usr/bin/tar --exclude=__pycache__ --exclude=*.pyc -czf "$DEST" -C "$ROOT" install.sh meeting.sh package.sh lock.json README.md PLAN.md VALIDATION.md src scripts tests .gitignore
printf 'Source package: %s\n' "$DEST"
