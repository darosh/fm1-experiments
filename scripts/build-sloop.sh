#!/bin/sh
# Build SLOOP. Arguments go to SLOOP's tools/build.py:
#   --release X.Y  a release package (identity FM-1_9XY)   --sdk DIR  another AC79 SDK checkout
#
# The build is the USB host-compat one: the serial console is compiled out (FELUCCA_CDC=0 — it is the
# CDC composite macOS 13-15 mis-attaches, and SLOOP 2.7 dropped it from the FM-1's build anyway), and
# the plain descriptors put the MIDI function behind the audio streams, add the audio IAD and give the
# device a serial (FELUCCA_UAC_MIDI_LAST / FELUCCA_UAC_IAD; the serial follows FELUCCA_ID, "FM-1_900"
# or the release identity). Export any of them yourself to override, e.g. FELUCCA_CDC=1 for the console
# layout (then clear MIDI_LAST/IAD: they are plain-build flags).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone sloop
need_venv

FELUCCA_CDC=${FELUCCA_CDC:-0}
if [ "$FELUCCA_CDC" = 0 ]; then
    FELUCCA_UAC_MIDI_LAST=${FELUCCA_UAC_MIDI_LAST:-1}
    FELUCCA_UAC_IAD=${FELUCCA_UAC_IAD:-1}
    export FELUCCA_UAC_MIDI_LAST FELUCCA_UAC_IAD
fi
export FELUCCA_CDC

# the UI font generator needs Pillow, which the repo venv has (Homebrew's python3.15)
PATH="$ROOT/.venv/bin:$PATH"
export PATH

"$PYTHON" "$ROOT/clones/sloop/tools/build.py" "$@"

BUILD="$ROOT/clones/sloop/build"
show_package "$(pick_package "$BUILD" felucca)"
