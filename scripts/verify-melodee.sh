#!/bin/sh
# Run Melodee's host tests (the sound goldens and DSP, the CPU and target budgets, the UI renders and
# lint, storage, MIDI, the USB audio descriptors / driver / four-track capture, the installer and the
# web pages). Build it first: scripts/build-melodee.sh — several need build/melodee.fwsc and build/gen.
# The web tests run when Node is installed and are skipped otherwise.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone melodee
need_venv

# tests/run_tests.sh calls python3 for the generated tables and the site/installer tests; the venv has
# Pillow (font generation) and the pinned packages.
PATH="$ROOT/.venv/bin:$PATH"
export PATH

# tools/fm1_recover.py accepts only the unmodified V1.2.1 wl82loader.bin (30,720 B, SHA-256 d9de9f1c…),
# which Melodee ships under assets/recovery/, and it prefers $AC79_SDK when that is set. Our pinned SDK
# is V1.2.14, whose helper has a different digest, so the suite's offline recovery check would fail on
# the version difference alone. Give the suite an SDK view whose helper is Melodee's shipped one and
# whose three package files (uboot.boot, cfg_tool.bin, cfg/eq_cfg_hw.bin) are the pinned SDK's.
SDK_VIEW=$(mktemp -d "${TMPDIR:-/tmp}/melodee-sdk.XXXXXX")
trap 'rm -rf "$SDK_VIEW"' EXIT INT TERM
mkdir -p "$SDK_VIEW/cpu/wl82/tools"
for f in uboot.boot cfg_tool.bin cfg; do
    [ -e "$AC79_SDK/cpu/wl82/tools/$f" ] || die "no $AC79_SDK/cpu/wl82/tools/$f (see README section 1)"
    ln -s "$AC79_SDK/cpu/wl82/tools/$f" "$SDK_VIEW/cpu/wl82/tools/$f"
done
ln -s "$ROOT/clones/melodee/assets/recovery/wl82loader.bin" "$SDK_VIEW/cpu/wl82/tools/wl82loader.bin"

AC79_SDK="$SDK_VIEW" run_tests_exit melodee melodee
