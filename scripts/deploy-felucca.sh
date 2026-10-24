#!/bin/sh
# Flash Felucca to the FM-1 over USB-MIDI.
#   scripts/deploy-felucca.sh                  the last build (felucca.fwsc, else the newest package)
#   scripts/deploy-felucca.sh path/to/x.fwsc   that package
#   scripts/deploy-felucca.sh --info           the connected FM-1's identity, writing nothing
# Other flags go to Felucca's own fm1_install.py (--port NAME, --yes, --force).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_venv
BUILD="$ROOT/clones/felucca/build"
INSTALL="$ROOT/clones/felucca/tools/fm1_install.py"

case "${1:-}" in
    -*)     exec "$PYTHON" "$INSTALL" "$@" ;;   # --info and the other flags take no package
    *.fwsc) pkg=$1; shift ;;
    ?*)     die "not a .fwsc: $1" ;;
esac
[ -n "${pkg:-}" ] || pkg=$(pick_package "$BUILD" felucca)
[ -n "$pkg" ] || die "no package in $BUILD: run scripts/build-felucca.sh first"

echo "package: $pkg"
echo "Running firmware: the installer asks it to enter update mode."
echo "If it does not start: hold REC while powering on."
exec "$PYTHON" "$INSTALL" "$pkg" "$@"
