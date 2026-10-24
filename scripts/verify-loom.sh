#!/bin/sh
# Run LOOM-8's host tests (the synth, sequencer and FX units, the scenarios, the update path).
# Build it first: scripts/build-loom.sh — the update-path test needs app/build/loom.fwsc.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-loom
need_base_usb_patch
run_tests fm1-loom loom
