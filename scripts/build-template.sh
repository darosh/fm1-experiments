#!/bin/sh
# Build fm1-base's template firmware (the base template, not a firmware of ours).
# Arguments go to fm1-base's build.py: --host, --web, --release X.Y, --no-ble, --sdk DIR.
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone fm1-base
need_base_usb_patch

# The template's fm1.toml has Bluetooth and Bluetooth-devices on. The pinned AC79 SDK (V1.2.14)
# needs usr_timeout_del from the BLE shim, which fm1-base defines only in its WiFi build, so a BLE
# template needs the V1.2.1 SDK its upstream README names. Without --host/--web, build the USB-only
# template (template-usb.fwsc): screen, keys, sound, USB-MIDI and USB audio, which is enough to
# flash and to exercise the platform.
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
