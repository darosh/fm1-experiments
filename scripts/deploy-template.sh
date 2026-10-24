#!/bin/sh
# Flash fm1-base's template firmware to the FM-1 over USB-MIDI.
#   scripts/deploy-template.sh                the last build (template.fwsc, else the newest package)
#   scripts/deploy-template.sh path/to/x.fwsc that package
#   scripts/deploy-template.sh --info         the connected FM-1's identity, writing nothing
# Other flags go to fm1_install.py (--port NAME, --yes, --force).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_venv
BUILD="$ROOT/clones/fm1-base/template/build"
INSTALL="$ROOT/clones/fm1-base/tools/fm1_install.py"

case "${1:-}" in
    -*)     exec "$PYTHON" "$INSTALL" "$@" ;;   # --info and the other flags take no package
    *.fwsc) pkg=$1; shift ;;
    ?*)     die "not a .fwsc: $1" ;;
esac
[ -n "${pkg:-}" ] || pkg=$(pick_package "$BUILD" template)
[ -n "$pkg" ] || die "no package in $BUILD: run scripts/build-template.sh first"

echo "package: $pkg"
echo "Running firmware: the installer asks it to enter update mode."
echo "If it does not start: hold REC while powering on."
exec "$PYTHON" "$INSTALL" "$pkg" "$@"
