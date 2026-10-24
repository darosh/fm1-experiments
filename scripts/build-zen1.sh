#!/bin/sh
# Build ZEN-1. Arguments go to ZEN-1's build.sh / tools/build.py:
#   --release X.Y.Z  a release package (identity FM-1_6XXYYZZ)   --sdk DIR  another AC79 SDK checkout
#
# The build is the USB host-compat one: the serial console is compiled out (OM_CDC=0 — the CDC
# composite macOS 13-15 mis-attaches, and it is a developer tool these scripts do not use), the USB
# audio input is compiled in (OM_UAC=1; main.c maps these onto FELUCCA_CDC / FELUCCA_UAC), and the
# plain descriptors put the MIDI function behind the audio streams, add the audio IAD and give the
# device a serial (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD; the serial follows FELUCCA_ID,
# "FM-1_600"). Export any of them yourself to override, e.g. OM_CDC=1 for the console layout (then
# clear MIDI_LAST/IAD: they are plain-build flags).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone zen-1

OM_CDC=${OM_CDC:-0}
if [ "$OM_CDC" = 0 ]; then
    OM_UAC=${OM_UAC:-1}
    FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
    FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
    export OM_UAC FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD
fi
export OM_CDC

"$ROOT/clones/zen-1/build.sh" "$@"

BUILD="$ROOT/clones/zen-1/build"
show_package "$(pick_package "$BUILD" zen1)"
