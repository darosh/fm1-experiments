#!/bin/sh
# Flash a .fwsc package to the FM-1 over USB-MIDI.
#   scripts/deploy.sh                  the last build
#   scripts/deploy.sh path/to/x.fwsc
# Put the FM-1 in update mode first: hold OCT- and OCT+ together for ~5 s.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FWSC=${1:-"$ROOT/clones/fm1-loom/app/build/loom.fwsc"}

[ -f "$FWSC" ] || { echo "deploy: no package at $FWSC (run scripts/build.sh)"; exit 1; }
[ -x "$ROOT/.venv/bin/python" ] || { echo "deploy: run scripts/setup.sh first"; exit 1; }

echo "package: $FWSC"
echo "If the FM-1 is not in update mode: hold OCT- and OCT+ together for ~5 s."
echo
exec "$ROOT/.venv/bin/python" "$ROOT/clones/fm1-base/tools/fm1_install.py" "$FWSC"