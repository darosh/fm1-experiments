#!/bin/sh
# Run fm1-base's host tests: the platform pieces, the installer against a simulated FM-1, the
# update path (it runs after scripts/build-template.sh) and the template in the simulator —
# including our USB descriptor matrix.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-base
need_base_usb_patch

# fm1-base's update-path test looks for template/build/template.fwsc. build-template.sh makes the
# USB-only template (template-usb.fwsc, see §2), so lend it the name the test expects for the run.
BUILD="$ROOT/clones/fm1-base/template/build"
if [ ! -f "$BUILD/template.fwsc" ] && [ -f "$BUILD/template-usb.fwsc" ]; then
    cp "$BUILD/template-usb.fwsc" "$BUILD/template.fwsc"
    trap 'rm -f "$BUILD/template.fwsc"' EXIT INT TERM
fi

run_tests fm1-base base
