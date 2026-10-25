#!/bin/sh
# Run Mutable Dreams' host tests (the sanitized editor/transfer and storage-map tests, the DSP and
# next-feature suites, the audio-quality measurements, the browser range-control tests when Node is
# installed) and check the built firmware's USB descriptors for the host-compat set.
# Build it first: scripts/build-mutable-dreams.sh — the descriptor check needs app/build/mutable-dreams.bin.
# The WASM suite (tests/web_engine.mjs) runs only when WASI_SDK points at a clang (see the README).
set -eu
. "$(dirname "$0")/lib/common.sh"

SRC="$ROOT/clones/mutable-dreams/src"
[ -d "$ROOT/clones/mutable-dreams/.git" ] && [ -d "$SRC" ] \
    || die "no clones/mutable-dreams/src: run scripts/setup.sh first"
need_venv

PATH="$ROOT/.venv/bin:$PATH"
export PATH

mkdir -p "$ROOT/.logs"
log="$ROOT/.logs/verify-mutable-dreams-$(date +%Y%m%d-%H%M%S).log"
step() { printf '\n== %s\n' "$*" | tee -a "$log"; }
run() {  # CMD...
    printf '$ %s\n' "$*" >>"$log"
    "$@" >>"$log" 2>&1 || { tail -40 "$log"; die "failed: $* (see $log)"; }
}
in_src() { ( cd "$SRC" && "$@" ); }

step "host build (sanitized)"
run in_src "$PYTHON" tools/build_local.py host --sanitize

step "editor transfer, bank slots and the 22-object storage map"
run in_src "$PYTHON" tools/test_transfer.py

step "DSP suite"
run in_src "$PYTHON" tools/build_local.py dsp
run "$SRC/app/build/native/dsp-tests"

step "audio quality"
run in_src "$PYTHON" tools/build_local.py quality
run "$SRC/app/build/native/audio-quality-tests"

step "next-feature suite"
run in_src "$PYTHON" tools/build_local.py next
run "$SRC/app/build/native/next-tests"

if command -v node >/dev/null 2>&1; then
    step "browser range controls"
    run in_src node tests/range_controls.mjs
    if [ -n "${WASI_SDK:-}" ] && [ -x "$WASI_SDK/bin/clang" ]; then
        step "browser engine (same app/DSP source)"
        run in_src "$PYTHON" tools/build_local.py web
        run in_src node tests/web_engine.mjs
    else
        printf 'skipped: tests/web_engine.mjs (no WASI_SDK)\n' | tee -a "$log"
    fi
else
    printf 'skipped: the browser tests (no node)\n' | tee -a "$log"
fi

step "USB descriptors (host-compat set)"
[ -f "$SRC/app/build/mutable-dreams.bin" ] \
    || die "no app/build/mutable-dreams.bin: run scripts/build-mutable-dreams.sh first"
run "$PYTHON" "$ROOT/scripts/lib/usb_desc.py" "$SRC/app/build/mutable-dreams.bin"

printf '\nlog: %s\n' "$log"
