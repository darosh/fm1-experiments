#!/bin/sh
# Build TONITOR. Arguments go to TONITOR's tools/build.py:
#   --release X.Y    a release package (identity FM-1_7XY)   --sdk DIR  another AC79 SDK checkout
#
# The build is the USB host-compat one: the plain descriptors put the MIDI function behind the audio
# streams (AC, AS, MIDI), take MIDI out of the AC collection, add the audio IAD and give the device a
# serial (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD; the serial follows FELUCCA_ID, "FM-1_700" or the
# release identity). TONITOR has no serial console build here (its usb.c is the plain one; the CDC menu
# layout is not wired into its build). Export either flag as 0 to override.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone tonitor
need_venv

FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
export FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD

"$PYTHON" "$ROOT/clones/tonitor/tools/build.py" "$@"

BUILD="$ROOT/clones/tonitor/build"
show_package "$(pick_package "$BUILD" tonitor)"
