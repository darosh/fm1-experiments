#!/bin/sh
# Build Dinghy. Arguments go to Dinghy's tools/build.py:
#   --release X.Y  a release package (identity FM-1_99Y)   --board smk37  --model pro|elite|mke
#   --sdk DIR      another AC79 SDK checkout
#
# The build is the USB host-compat one: the plain descriptors put the MIDI function behind the audio
# streams and add the audio IAD (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD), and the device gets a serial
# number (FELUCCA_USB_SERIAL, default FELUCCA_ID: "FM-1_990" or the release identity). Export either
# flag as 0 to override. Dinghy compiles no CDC console, so the layout flags do not conflict.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone dinghy
need_venv

FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
export FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD

# the UI font generator needs Pillow, which the repo venv has (Homebrew's python3.15)
PATH="$ROOT/.venv/bin:$PATH"
export PATH

"$PYTHON" "$ROOT/clones/dinghy/tools/build.py" "$@"

BUILD="$ROOT/clones/dinghy/build"
show_package "$(pick_package "$BUILD" dinghy)"
