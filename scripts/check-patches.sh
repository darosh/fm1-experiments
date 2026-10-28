#!/bin/sh
# Is patches/ still the whole truth about clones/? Compares, per repo, the commits only the clone has
# (not reachable from any remote branch: ours, on `experiments`) with the patch files, by patch-id
# (so subject lines and [PATCH n/m] numbering do not matter). Reports commits missing from patches/,
# patch files no commit matches, and uncommitted changes in the clone (the symlinked submodule paths
# are ignored). Exit status 1 when anything differs.
#   scripts/check-patches.sh            every repo that has a patches/ directory
#   scripts/check-patches.sh fm1-loom   one repo
set -eu
. "$(dirname "$0")/lib/common.sh"

ids() {  # prints "patch-id<TAB>label" for each of FILES... on stdin
    while IFS= read -r f; do
        id=$(git patch-id --stable <"$f" | cut -d' ' -f1)
        printf '%s\t%s\n' "$id" "${f#"$ROOT"/}"
    done
}

check() {  # REPO
    repo=$1; dir="$ROOT/clones/$repo"
    [ -d "$dir/.git" ] || { echo "skip     $repo (no clone)"; return 0; }
    tmp=$(mktemp -d); bad=0
    find "$ROOT/patches/$repo" -name '*.patch' 2>/dev/null | sort | ids >"$tmp/patches"
    # (setup.sh's own "source: <archive>" commit, the base of an archive-only clone, is not a patch)
    for c in $(git -C "$dir" rev-list --reverse --invert-grep --grep='^source: ' HEAD --not --remotes); do
        id=$(git -C "$dir" show --format=email "$c" | git patch-id --stable | cut -d' ' -f1)
        printf '%s\t%s\n' "$id" "$(git -C "$dir" log -1 --format='%h %s' "$c" | cut -c1-72)"
    done >"$tmp/commits"
    while IFS="$(printf '\t')" read -r id label; do
        grep -q "^$id	" "$tmp/patches" || { echo "MISSING  $repo: commit $label is in no patch"; bad=1; }
    done <"$tmp/commits"
    while IFS="$(printf '\t')" read -r id label; do
        grep -q "^$id	" "$tmp/commits" || { echo "STALE    $repo: $label matches no commit"; bad=1; }
    done <"$tmp/patches"
    if [ -n "$(git -C "$dir" -c diff.ignoreSubmodules=all status --porcelain --ignore-submodules=all)" ]; then
        echo "DIRTY    $repo: uncommitted changes in clones/$repo"; bad=1
    fi
    rm -rf "$tmp"
    [ $bad = 0 ] && echo "in sync  $repo"
    return $bad
}

rc=0
if [ $# -gt 0 ]; then
    check "$1" || rc=1
else
    for d in "$ROOT"/patches/*/; do
        check "$(basename "$d")" || rc=1
    done
fi
exit $rc
