#!/bin/sh
# Build the LOOM-8 firmware. Arguments are passed to fm1-loom/build.sh (--host, --web, --demo,
# --release X.Y, --no-ble).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PYTHON="$ROOT/.venv/bin/python"
export JIELI_TOOLCHAIN="${JIELI_TOOLCHAIN:-$HOME/.jieli/toolchain}"
export AC79_SDK="${AC79_SDK:-$HOME/fw-AC79_AIoT_SDK}"

[ -d "$ROOT/clones/fm1-loom" ] || { echo "build: run scripts/setup.sh first"; exit 1; }
"$ROOT/clones/fm1-loom/build.sh" "$@"

FWSC="$ROOT/clones/fm1-loom/app/build/loom.fwsc"
if [ -f "$FWSC" ]; then
    printf '\npackage  %s  %s bytes\n' "$FWSC" "$(wc -c <"$FWSC" | tr -d ' ')"
fi