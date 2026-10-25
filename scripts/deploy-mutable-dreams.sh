#!/bin/sh
# Flash Mutable Dreams to the FM-1 over USB-MIDI.
#   scripts/deploy-mutable-dreams.sh                  the last build (mutable-dreams.fwsc, else newest package)
#   scripts/deploy-mutable-dreams.sh path/to/x.fwsc   that package
#   scripts/deploy-mutable-dreams.sh --info           the connected FM-1's identity, writing nothing
# Other flags go to its base/tools/fm1_install.py (--port NAME, --yes, --force).
set -eu
. "$(dirname "$0")/lib/common.sh"

SRC="$ROOT/clones/mutable-dreams/src"
need_venv
BUILD="$SRC/app/build"
INSTALL="$SRC/base/tools/fm1_install.py"
[ -f "$INSTALL" ] || die "no $INSTALL: run scripts/setup.sh first"

case "${1:-}" in
    -*)     exec "$PYTHON" "$INSTALL" "$@" ;;   # --info and the other flags take no package
    *.fwsc) pkg=$1; shift ;;
    ?*)     die "not a .fwsc: $1" ;;
esac
[ -n "${pkg:-}" ] || pkg=$(pick_package "$BUILD" mutable-dreams)
[ -n "$pkg" ] || die "no package in $BUILD: run scripts/build-mutable-dreams.sh first"

echo "package: $pkg"
echo "Running firmware: the installer asks it to enter update mode."
echo "If it does not start: hold REC while powering on."
exec "$PYTHON" "$INSTALL" "$pkg" "$@"
