#!/bin/sh
# Run Felucca's host tests (the engines' goldens, USB audio and descriptors, the UI renders, the
# update path, the installer). Build it first: scripts/build-felucca.sh — several tests need
# build/felucca.fwsc and build/gen.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone felucca
run_tests_exit felucca felucca
