#!/bin/sh
# Build Mutable Dreams. Arguments go to its base/tools/build.py:
#   --release X.Y[.Z]  a release package (identity FM-1_710<XY>ZZ: FM-1_710010100 for 1.1.0)
#   --sdk DIR          another AC79 SDK checkout
# (--host and --web build the simulator and the emulator instead of the firmware.)
#
# The build is the USB host-compat one: patches/mutable-dreams turns FELUCCA_UAC_MIDI_LAST and
# FELUCCA_UAC_IAD on for the plain build, so the MIDI function sits behind the audio streams, out
# of the AC header's collection, and the audio function has its IAD. The serial number follows
# FELUCCA_ID ("FM-1_71000", or the release identity); the update loader keeps iSerialNumber 0.
# (The CDC console is not part of this source snapshot: FM1B_CDC=1 does not link, console.c is
# absent; the flags are plain-build only and leave the CDC layouts' descriptors untouched.)
#
# Mutable Dreams vendors its platform under src/base (fm1-base bbfd461 with the app's own delta;
# base/bsp is felucca-bsp 33cac69), so there is no base symlink and no shared fm1-base patch.
set -eu
. "$(dirname "$0")/lib/common.sh"

SRC="$ROOT/clones/mutable-dreams/src"
[ -d "$ROOT/clones/mutable-dreams/.git" ] && [ -d "$SRC" ] \
    || die "no clones/mutable-dreams/src: run scripts/setup.sh first"
need_venv

# the UI font generator needs Pillow (with Raqm), which the repo venv has (Homebrew's python3.15);
# the generated font set "dreams" is Mutable Dreams' own
PATH="$ROOT/.venv/bin:$PATH"
export PATH

"$PYTHON" "$SRC/base/tools/build.py" "$SRC/app" "$@"

show_package "$(pick_package "$SRC/app/build" mutable-dreams)"
