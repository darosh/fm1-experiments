#!/bin/sh
# Run Dinghy's host tests (the host app on the FM-1 and the SMK-37, the flash maps, the update path and
# the loader, the installer, and the USB descriptors — including the host-compat set). Build it first:
# scripts/build-dinghy.sh — the installer and OTA tests need build/dinghy.fwsc.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone dinghy
need_venv

# Dinghy's run_tests.sh calls python3 for the screens and the generated font, and the venv has Pillow.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

run_tests_exit dinghy dinghy
