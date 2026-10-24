#!/bin/sh
# Build AMB-1 (fm1-amb). Arguments go to fm1-amb/build.sh:
#   --host  the host simulator      --web  the browser emulator      --release X.Y  a release package
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-amb
need_base_usb_patch

"$ROOT/clones/fm1-amb/build.sh" "$@"

case " $* " in
    *" --host "*|*" --web "*) exit 0 ;;   # a simulator/emulator build makes no package
esac

BUILD="$ROOT/clones/fm1-amb/app/build"
show_package "$(pick_package "$BUILD" amb)"
