#!/bin/sh
# Run FRASIL's host checks (the instrument, its scenes and MIDI, backup/restore, the boot scenarios)
# and, when a firmware build exists, check its USB descriptors for the host-compat set.
# Build first: scripts/build-frasil.sh --host (the checks) and scripts/build-frasil.sh (the descriptors).
set -eu
. "$(dirname "$0")/lib/common.sh"

need_clone frasil
need_base_usb_patch
HOST="$ROOT/clones/frasil/app/build/host/frasil_host"
[ -x "$HOST" ] || die "no host simulator: run scripts/build-frasil.sh --host first"

mkdir -p "$ROOT/.logs"
log="$ROOT/.logs/verify-frasil-$(date +%Y%m%d-%H%M%S).log"
st="$ROOT/.logs/.verify-frasil.$$"
(
    cd "$ROOT/clones/frasil"
    rc=0
    for t in basic boot; do
        printf '\n== %s\n' "$t"
        "$HOST" "app/tests/$t.txt" app/build/host || rc=$((rc + 1))
    done
    echo "$rc" >"$st"
) 2>&1 | tee "$log"
rc=$(cat "$st" 2>/dev/null || echo 1)
rm -f "$st"
oks=$(grep -c '^  ok' "$log" || true)
fails=$(grep -c '^FAIL' "$log" || true)
printf '\n%d ok, %d FAIL\n' "$oks" "$fails"
[ "$rc" = 0 ] && [ "$fails" = 0 ] || die "host checks failed (see $log)"

BIN="$ROOT/clones/frasil/app/build/frasil.bin"
if [ -f "$BIN" ]; then
    printf '\n== USB descriptors\n' | tee -a "$log"
    "$PYTHON" "$ROOT/scripts/lib/usb_desc.py" "$BIN" 2>&1 | tee -a "$log" \
        || die "the USB descriptors are not the host-compat set (see $log)"
else
    printf '\nskipped: the USB descriptor check (no app/build/frasil.bin: run scripts/build-frasil.sh)\n' \
        | tee -a "$log"
fi

printf '\nlog: %s\n' "$log"
