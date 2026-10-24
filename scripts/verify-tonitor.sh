#!/bin/sh
# Run TONITOR's host tests (the generated tables and fonts, the target-instruction check, the DSP and
# sound goldens, the screens, the backup protocol, and the USB host-compat descriptors). Build it
# first: scripts/build-tonitor.sh — the browser-installer test needs build/tonitor.fwsc.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone tonitor
need_venv

# TONITOR's run_tests.sh uses the clone's .venv if there is one, else python3; the generated font
# needs Pillow, which the repo's .venv has.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

run_tests_exit tonitor tonitor
