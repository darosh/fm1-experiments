#!/bin/sh
# Run fm1-base's host test suite, including the USB descriptor matrix our patches add
# (audio, audio-collect, audio-midi-last, audio-both, audio-out, audio-out-both, midi-only, iad,
# serial). No hardware needed. The log goes to .logs/.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
[ -d "$ROOT/clones/fm1-base" ] || { echo "verify: run scripts/setup.sh first"; exit 1; }
mkdir -p "$ROOT/.logs"
LOG="$ROOT/.logs/verify-$(date +%Y%m%d-%H%M%S).log"

cd "$ROOT/clones/fm1-base"
PYTHON="$ROOT/.venv/bin/python" CC="${CC:-cc}" sh tests/run_tests.sh 2>&1 | tee "$LOG"
rc=$(grep -c '^  FAIL' "$LOG" || true)
echo
echo "log: $LOG"
[ "$rc" = 0 ] || { echo "verify: $rc failing check(s)"; exit 1; }