#!/bin/sh
# Build Melodee. Arguments go to Melodee's tools/build.py:
#   --release X.Y[.Z]  a release package (identity FM-1_9<version>)   --nightly  a git-commit build
#   --sdk DIR          another AC79 SDK checkout
#
# Melodee needs no patch here: its USB stack is its own (README section 7) and its duplex USB audio
# (stereo playback; stereo or four-track capture; 16/24 bit at 44.1 kHz) is on by default in
# firmware/src/melodee.c. Its build.py checks the SDK against AC79NN_SDK_V1.2.1 and only warns about
# another version, so the pinned V1.2.14 builds (with that warning) and packages its own
# cfg_tool.bin / eq_cfg_hw.bin.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone melodee
need_venv

# The UI font, icons and tables are generated at build time; build.sh points DYLD_FALLBACK_LIBRARY_PATH
# at Homebrew's lib for Pillow's Raqm, and the venv borrows Homebrew's Pillow/fontTools.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

"$ROOT/clones/melodee/build.sh" "$@"

BUILD="$ROOT/clones/melodee/build"
show_package "$(pick_package "$BUILD" melodee)"
