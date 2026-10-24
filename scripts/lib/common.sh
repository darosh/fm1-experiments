#!/bin/sh
# Shared by the per-firmware scripts: the repo root, the pinned revisions and the environment the
# builds read. Sourced, never executed — the callers all live in scripts/, so $0 names one of them.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/revisions.env"

export PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"
export JIELI_TOOLCHAIN="${JIELI_TOOLCHAIN:-$HOME/.jieli/toolchain}"
export AC79_SDK="${AC79_SDK:-$HOME/fw-AC79_AIoT_SDK}"
export JIELI_DOCKER_IMAGE

die() { printf '%s: %s\n' "$(basename "$0")" "$*" >&2; exit 1; }

need_clone() {  # NAME
    [ -d "$ROOT/clones/$1/.git" ] || die "no clones/$1: run scripts/setup.sh first"
}

need_venv() {
    [ -x "$ROOT/.venv/bin/python" ] || die "no .venv: run scripts/setup.sh first"
}

# fm1-base must carry our patch, or fm1.toml's usb_midi_last / usb_iad are silently ignored.
need_base_usb_patch() {
    need_clone fm1-base
    grep -q 'usb_midi_last' "$ROOT/clones/fm1-base/tools/build.py" \
        || die "clones/fm1-base is missing the USB patch: run scripts/setup.sh"
}

# The package a deploy uses: NAME.fwsc if it exists (a dev build), else the newest *.fwsc in DIR
# (a --release / --no-ble build). Prints nothing when there is none.
pick_package() {  # DIR NAME
    dir=$1; name=$2
    if [ -f "$dir/$name.fwsc" ]; then
        printf '%s\n' "$dir/$name.fwsc"
        return 0
    fi
    set -- "$dir"/*.fwsc
    [ -f "$1" ] || return 0
    ls -t "$dir"/*.fwsc 2>/dev/null | head -1 || true
}

# Run tests/run_tests.sh in a clone, teeing to .logs/verify-<slug>-<timestamp>.log.
run_tests() {  # REPO SLUG
    mkdir -p "$ROOT/.logs"
    log="$ROOT/.logs/verify-$2-$(date +%Y%m%d-%H%M%S).log"
    ( cd "$ROOT/clones/$1" && CC="${CC:-cc}" PYTHON="$PYTHON" sh tests/run_tests.sh ) 2>&1 | tee "$log"
    rc=$(grep -c '^  FAIL' "$log" || true)
    printf '\nlog: %s\n' "$log"
    [ "$rc" = 0 ] || die "$rc failing check(s)"
}

# Run a suite that reports through its exit status instead of fm1-base's "  FAIL" lines (Felucca's
# run_tests.sh prints "== <name>" and ends with ALL HOST TESTS PASSED / HOST TESTS FAILED). POSIX sh
# has no pipefail and `cmd | tee` reports tee, so the status travels through a file.
run_tests_exit() {  # REPO SLUG
    mkdir -p "$ROOT/.logs"
    log="$ROOT/.logs/verify-$2-$(date +%Y%m%d-%H%M%S).log"
    st="$ROOT/.logs/.verify-$2.$$"
    ( cd "$ROOT/clones/$1" && CC="${CC:-cc}" PYTHON="$PYTHON" sh tests/run_tests.sh; echo $? >"$st" ) 2>&1 | tee "$log"
    rc=$(cat "$st" 2>/dev/null || echo 1)
    rm -f "$st"
    printf '\nlog: %s\n' "$log"
    [ "$rc" = 0 ] && grep -Eq 'ALL HOST TESTS PASSED|all tests passed|^tests: ok$' "$log" \
        || die "the suite failed (exit $rc), see $log"
}

show_package() {  # PACKAGE (ignored when empty)
    [ -n "${1:-}" ] && [ -f "$1" ] || return 0
    printf '\npackage  %s  %s bytes\n' "$1" "$(wc -c <"$1" | tr -d ' ')"
}
