#!/bin/sh
# Build FRASIL (frasil). Arguments go to frasil/build.sh:
#   --host  the host simulator      --web  the browser emulator      --release X.Y  a release package
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone frasil
need_base_usb_patch

"$ROOT/clones/frasil/build.sh" "$@"

case " $* " in
    *" --host "*|*" --web "*) exit 0 ;;   # a simulator/emulator build makes no package
esac

BUILD="$ROOT/clones/frasil/app/build"
show_package "$(pick_package "$BUILD" frasil)"
