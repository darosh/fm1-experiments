#!/bin/sh
# Run SLOOP's host tests (the sound goldens, the DSP and CPU budgets, the sequencer, the FM6 engine,
# the installer and the site, and the USB descriptors — including the host-compat set). Build it first:
# scripts/build-sloop.sh — the installer and OTA tests need build/felucca.fwsc.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone sloop
need_venv

# SLOOP's run_tests.sh calls python3 for the generated tables and the site/installer tests; the venv
# has Pillow (font generation) and the pinned packages.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

run_tests_exit sloop sloop
