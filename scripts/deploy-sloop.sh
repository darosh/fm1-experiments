#!/bin/sh
# Flash SLOOP to the FM-1 over USB-MIDI.
#   scripts/deploy-sloop.sh                     the last build (felucca.fwsc, else the newest package)
#   scripts/deploy-sloop.sh path/to/x.fwsc      that package
#   scripts/deploy-sloop.sh --info              the connected FM-1's identity, writing nothing
# Other flags go to SLOOP's fm1_install.py (--port NAME, --yes, --force).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_venv
BUILD="$ROOT/clones/sloop/build"
INSTALL="$ROOT/clones/sloop/tools/fm1_install.py"

case "${1:-}" in
    -*)     exec "$PYTHON" "$INSTALL" "$@" ;;   # --info and the other flags take no package
    *.fwsc) pkg=$1; shift ;;
    ?*)     die "not a .fwsc: $1" ;;
esac
[ -n "${pkg:-}" ] || pkg=$(pick_package "$BUILD" felucca)
[ -n "$pkg" ] || die "no package in $BUILD: run scripts/build-sloop.sh first"

echo "package: $pkg"
echo "Running firmware: the installer asks it to enter update mode."
echo "If it does not start: hold REC while powering on."
exec "$PYTHON" "$INSTALL" "$pkg" "$@"
