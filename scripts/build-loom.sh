#!/bin/sh
# Build LOOM-8 (fm1-loom). Arguments go to fm1-loom/build.sh:
#   --host  the host simulator      --web  the browser emulator      --demo  mirroring for demos
#   --release X.Y  a release package                                   --no-ble  without Bluetooth
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-loom
need_base_usb_patch

"$ROOT/clones/fm1-loom/build.sh" "$@"

case " $* " in
    *" --host "*|*" --web "*) exit 0 ;;   # a simulator/emulator build makes no package
esac

BUILD="$ROOT/clones/fm1-loom/app/build"
show_package "$(pick_package "$BUILD" loom)"
