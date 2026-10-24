#!/bin/sh
# Run AMB-1's host tests (the instrument, the scenarios, the browser builds, the update path).
# Build it first: scripts/build-amb.sh — the update-path test needs app/build/amb.fwsc.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-amb
need_base_usb_patch
run_tests fm1-amb amb
