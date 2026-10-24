#!/bin/sh
# Build CS-1. Arguments go to CS-1's tools/build.py:
#   --release X.Y  a release package (identity FM-1_95Y)   --sdk DIR  another AC79 SDK checkout
#
# The build is the USB host-compat one: the plain descriptors put the MIDI function behind the audio
# streams and add the audio IAD (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD), and the device gets a serial
# number (FELUCCA_USB_SERIAL, default FELUCCA_ID: "FM-1_950" or the release identity). Export either
# flag as 0 to override. DINGHY_DUAL_CORE=0 builds single-core.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone cs1
need_venv

FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
export FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD

PATH="$ROOT/.venv/bin:$PATH"
export PATH

"$PYTHON" "$ROOT/clones/cs1/tools/build.py" "$@"

BUILD="$ROOT/clones/cs1/build"
show_package "$(pick_package "$BUILD" cs1)"
