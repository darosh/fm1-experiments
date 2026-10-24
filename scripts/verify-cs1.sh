#!/bin/sh
# Run CS-1's host tests (the host build, the site and the browser emulator, and the USB descriptors —
# including the host-compat set). Build it first: scripts/build-cs1.sh — the site build needs
# build/cs1.fwsc's directory and the emulator its wasm; Emscripten and Node must be on the PATH
# (tools/get_emsdk.sh installs Emscripten).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone cs1
need_venv

# CS-1's run_tests.sh calls python3 for the generated tables and the screenshots; the venv has Pillow
# and the pinned packages.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

run_tests_exit cs1 cs1
