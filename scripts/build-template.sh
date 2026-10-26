#!/bin/sh
# Build fm1-base's template firmware (the base template, not a firmware of ours).
# Arguments go to fm1-base's build.py: --host, --web, --release X.Y, --no-ble, --sdk DIR.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-base
need_base_usb_patch

# The template's fm1.toml has Bluetooth and Bluetooth-devices on. patches/fm1-base/08-ble-timer-shim
# gives the pinned AC79 SDK (V1.2.14) the usr_timeout_del its btctrler.a wants, so the BLE template
# links now too. Without --host/--web, still build the USB-only template (template-usb.fwsc) by
# default: the smaller package, enough to flash and to exercise the platform and the update path.
case " $* " in
    *" --host "*|*" --web "*|*" --no-ble "*) ;;
    *) set -- --no-ble "$@" ;;
esac

"$PYTHON" "$ROOT/clones/fm1-base/tools/build.py" "$ROOT/clones/fm1-base/template" "$@"

case " $* " in
    *" --host "*|*" --web "*) exit 0 ;;   # a simulator/emulator build makes no package
esac

BUILD="$ROOT/clones/fm1-base/template/build"
show_package "$(pick_package "$BUILD" template)"
