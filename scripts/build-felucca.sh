#!/bin/sh
# Build Felucca. Arguments go to Felucca's build.sh / tools/build.py:
#   --release X.Y  a release package (identity FM-1_9XY)   --sdk DIR  another AC79 SDK checkout
#
# The build is the USB host-compat one: the serial console is compiled out (FELUCCA_CDC=0 — it is the
# CDC composite macOS 13-15 mis-attaches, and it is a developer tool these scripts do not use), and the
# plain descriptors put the MIDI function behind the audio streams, add the audio IAD and give the
# device a serial (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD; the serial follows FELUCCA_ID). Export any
# of them yourself to override, e.g. FELUCCA_CDC=1 for the console layout (then clear MIDI_LAST/IAD:
# they are plain-build flags).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone felucca

FELUCCA_CDC=${FELUCCA_CDC:-0}
if [ "$FELUCCA_CDC" = 0 ]; then
    FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
    FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
    export FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD
fi
export FELUCCA_CDC

"$ROOT/clones/felucca/build.sh" "$@"

BUILD="$ROOT/clones/felucca/build"
show_package "$(pick_package "$BUILD" felucca)"
