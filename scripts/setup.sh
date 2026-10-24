#!/bin/sh
# Clone the pinned upstream repos, link the submodule paths, apply our patches, make the venv.
# Safe to re-run: clones are kept, patches already applied are skipped, the venv is reused.
#   scripts/setup.sh               the normal run
#   scripts/setup.sh --no-patches  clone/link/venv only (use this when bumping a pin: README §6)
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/revisions.env"
CLONES="$ROOT/clones"
mkdir -p "$CLONES" "$ROOT/.logs"

NO_PATCHES=0
[ "${1:-}" = "--no-patches" ] && NO_PATCHES=1

say() { printf '%s\n' "$*"; }

# ---------------------------------------------------------------- clones ---
clone_repo() {  # NAME URL COMMIT
    name=$1; url=$2; commit=$3; dir="$CLONES/$name"
    if [ ! -d "$dir/.git" ]; then
        say "clone    $name"
        git clone --quiet "$url" "$dir"
        git -C "$dir" checkout --quiet -B experiments "$commit"
    else
        say "exists   $name"
        git -C "$dir" fetch --quiet --no-recurse-submodules origin \
            || say "warning: $name: fetch failed (offline?)"
        if ! git -C "$dir" merge-base --is-ancestor "$commit" HEAD 2>/dev/null; then
            say "ERROR: $name: HEAD does not contain the pinned commit $commit."
            say "       Move the clone away or reset it; see README 'Bumping a pin'."
            exit 1
        fi
    fi
}

clone_repo felucca-bsp "$FELUCCA_BSP_URL" "$FELUCCA_BSP_COMMIT"
clone_repo fm1-base    "$FM1_BASE_URL"    "$FM1_BASE_COMMIT"
clone_repo fm1-loom    "$FM1_LOOM_URL"    "$FM1_LOOM_COMMIT"
clone_repo fm1-amb     "$FM1_AMB_URL"     "$FM1_AMB_COMMIT"

# --------------------------------------------------------------- symlinks ---
# The build needs <firmware>/base -> fm1-base and fm1-base/bsp -> felucca-bsp. Symlinks (rather
# than real submodule checkouts) keep one copy of each repo; see README for the git caveat.
link() {  # LINK TARGET
    link=$1; target=$2
    if [ -L "$link" ]; then
        ln -sfn "$target" "$link"
    elif [ -e "$link" ]; then
        rmdir "$link" 2>/dev/null || { say "ERROR: $link exists and is not empty"; exit 1; }
        ln -s "$target" "$link"
    else
        ln -s "$target" "$link"
    fi
}
link "$CLONES/fm1-loom/base" "../fm1-base"
link "$CLONES/fm1-amb/base"  "../fm1-base"
link "$CLONES/fm1-base/bsp"  "../felucca-bsp"
say "linked   fm1-loom/base, fm1-amb/base -> ../fm1-base; fm1-base/bsp -> ../felucca-bsp"

# --------------------------------------------------------------- patches ---
# patches/<repo>/<NN-problem>/NNNN-*.patch, problem dirs in sorted order (the numeric prefix is
# what makes the order deterministic when two patches touch the same file).
apply_patches() {  # REPO
    repo=$1; dir="$CLONES/$repo"
    [ -d "$ROOT/patches/$repo" ] || return 0
    for pdir in $(find "$ROOT/patches/$repo" -mindepth 1 -maxdepth 1 -type d | sort); do
        for patch in $(find "$pdir" -maxdepth 1 -name '*.patch' | sort); do
            rel=${patch#"$ROOT"/}
            if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
                say "applied  $rel"
            elif git -C "$dir" apply --check "$patch" >/dev/null 2>&1; then
                git -C "$dir" am --quiet --3way "$patch"
                say "patched  $rel"
            else
                say "ERROR: $rel neither applies nor is already applied."
                say "       The pin probably moved; regenerate the patch (README 'Bumping a pin')."
                exit 1
            fi
        done
    done
}

if [ "$NO_PATCHES" = 1 ]; then
    say "patches  skipped (--no-patches)"
else
    apply_patches felucca-bsp
    apply_patches fm1-base
    apply_patches fm1-loom
    apply_patches fm1-amb
fi

# ------------------------------------------------------------------ venv ---
PYBIN=${PYTHON_HOST:-/opt/homebrew/bin/python3.15}
[ -x "$PYBIN" ] || PYBIN=$(command -v python3)
if [ ! -x "$ROOT/.venv/bin/python" ]; then
    say "venv     $PYBIN"
    "$PYBIN" -m venv --system-site-packages "$ROOT/.venv"
fi
"$ROOT/.venv/bin/pip" install --quiet --disable-pip-version-check \
    "mido==$PY_MIDO_VERSION" "python-rtmidi==$PY_RTMIDI_VERSION"
if ! "$ROOT/.venv/bin/python" -c 'import PIL.features as f,sys; sys.exit(0 if f.check("raqm") else 1)' 2>/dev/null; then
    say "warning: Pillow without libraqm in the venv; the fonts need it (brew install pillow)"
fi

# ----------------------------------------------------------------- checks ---
status() { printf '  %-10s %s\n' "$1" "$2"; }
say ""
say "prerequisites:"
TC=${JIELI_TOOLCHAIN:-$HOME/.jieli/toolchain}
if [ -x "$TC/pi32v2/bin/clang" ]; then
    status toolchain "$TC"
    TC_PKG=$(basename "$(readlink "$TC" 2>/dev/null || true)" 2>/dev/null || true)
    if [ -n "$TC_PKG" ] && [ "$TC_PKG" != "$JIELI_TOOLCHAIN_VERSION" ]; then
        say "  warning: toolchain package $TC_PKG; revisions.env pins $JIELI_TOOLCHAIN_VERSION"
        say "           (re-run clones/fm1-base/tools/get_toolchain.sh for the newest)"
    fi
else
    status toolchain "MISSING: $TC (see README)" ; MISS=1; fi
SDK=${AC79_SDK:-$HOME/fw-AC79_AIoT_SDK}
if [ -d "$SDK" ]; then
    status sdk "$SDK"
    SDK_TAG=$(git -C "$SDK" describe --tags --exact-match 2>/dev/null || true)
    if [ "$SDK_TAG" != "$AC79_SDK_TAG" ]; then
        say "  warning: SDK tag '${SDK_TAG:-unknown}'; revisions.env pins $AC79_SDK_TAG"
    fi
else status sdk "MISSING: $SDK (see README)"; MISS=1; fi
if command -v docker >/dev/null 2>&1; then status docker "$(docker --version)"; else
    status docker "MISSING (Docker Desktop; the JieLi toolchain is Linux x86-64)"; MISS=1; fi
if [ "$(uname -m)" = arm64 ] && [ "$(uname -s)" = Darwin ]; then
    if sysctl -n sysctl.proc_translated >/dev/null 2>&1 || pgrep -q oahd; then
        status rosetta "present"
    else status rosetta "MISSING: softwareupdate --install-rosetta"; MISS=1; fi
fi
status python "$ROOT/.venv/bin/python"
say ""
if [ "${MISS:-0}" = 1 ]; then
    say "Some prerequisites are missing; the build scripts will fail until they are installed."
    exit 2
fi
say "ready. Build/deploy one firmware at a time (README section 2):"
say "  scripts/build-loom.sh       scripts/deploy-loom.sh       scripts/verify-loom.sh"
say "  scripts/build-amb.sh        scripts/deploy-amb.sh        scripts/verify-amb.sh"
say "  scripts/build-template.sh   scripts/deploy-template.sh   scripts/verify-base.sh"
