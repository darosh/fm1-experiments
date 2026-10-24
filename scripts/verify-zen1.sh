#!/bin/sh
# Run ZEN-1's host tests (the platform guard, the DSP and scene goldens, the USB host-compat
# descriptors, the simulator scenarios, the update path, the installer). Build it first:
# scripts/build-zen1.sh — several tests need build/zen1.fwsc and build/gen.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone zen-1
run_tests_exit zen-1 zen1
