#!/bin/sh
# Report how far each pinned upstream has moved: for every repo in revisions.env, fetch its default
# branch and count the commits it has that the pin does not (README section 6, step 1).
# Exit 0 when every pin is current, 1 when a pin can move (or could not be checked).
#   scripts/check-upstream.sh          all repos
#   scripts/check-upstream.sh -q       only the repos that have moved
# Uses clones/<repo> when setup.sh has made it, otherwise a bare clone in .cache/upstream-check/.
set -eu
. "$(dirname "$0")/lib/common.sh"

CACHE="$ROOT/.cache/upstream-check"
CLONES="$ROOT/clones"
only_moved=0
[ "${1:-}" = "-q" ] && only_moved=1

# newest tag reachable from COMMIT (empty when there is none)
newest_tag() {  # DIR COMMIT
    git -C "$1" tag --merged "$2" --sort=-creatordate 2>/dev/null | head -1 || true
}

total=0
moved=0
failed=0

if [ "$only_moved" = 0 ]; then
    say ""
    say "repos that have moved (commits in upstream's default branch that the pin does not have):"
    say ""
    printf '%-16s %8s  %s\n' "repo" "ahead" "upstream tip"
fi

# name:revisions.env prefix -- setup.sh's clone list, in its order (POSIX sh has no arrays).
for spec in \
    fm1-loom:FM1_LOOM \
    fm1-amb:FM1_AMB \
    frasil:FRASIL \
    fm1-base:FM1_BASE \
    felucca-bsp:FELUCCA_BSP \
    felucca:FELUCCA \
    felucca-engines:FELUCCA_ENGINES \
    zen-1:ZEN1 \
    tonitor:TONITOR \
    sloop:SLOOP \
    dinghy:DINGHY \
    cs1:CS1 \
    melodee:MELODEE \
    mutable-dreams:MUTABLE_DREAMS \
    elixir:ELIXIR
do
    name=${spec%%:*}
    var=${spec#*:}
    eval "url=\$${var}_URL"
    eval "pin=\$${var}_COMMIT"
    total=$((total + 1))

    dir="$CLONES/$name"
    if [ -d "$dir/.git" ]; then
        repo_dir=$dir
    else
        repo_dir="$CACHE/$name.git"
        if [ ! -d "$repo_dir" ]; then
            mkdir -p "$CACHE"
            say "cache    $name (no clones/$name: bare clone in .cache/upstream-check)"
            if ! git clone --quiet --bare "$url" "$repo_dir" </dev/null 2>/dev/null; then
                printf '%-16s %8s  %s\n' "$name" "no-repo" "cannot clone $url"
                failed=1
                continue
            fi
        fi
    fi

    # Fetch every head into refs/remotes/origin/*, which works the same in a normal clone and a bare
    # one. A failed fetch (offline) is not fatal: the refs already there still answer the question.
    if ! git -C "$repo_dir" fetch --quiet --prune --no-recurse-submodules origin \
        '+refs/heads/*:refs/remotes/origin/*' </dev/null 2>/dev/null; then
        say "warning: $name: fetch failed (offline?); comparing the refs already there"
    fi

    tip_ref=$(git -C "$repo_dir" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null || true)
    if [ -z "$tip_ref" ]; then
        # A bare clone has no origin/HEAD: ask the remote which branch its HEAD names.
        branch=$(git -C "$repo_dir" ls-remote --symref origin HEAD </dev/null 2>/dev/null \
            | sed -n 's|^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$|\1|p' | head -1)
        [ -n "$branch" ] && tip_ref="refs/remotes/origin/$branch"
    fi
    tip=$(git -C "$repo_dir" rev-parse --verify -q "$tip_ref^{commit}" 2>/dev/null || true)

    if [ -z "$tip" ]; then
        printf '%-16s %8s  %s\n' "$name" "unknown" "cannot resolve the default branch"
        failed=1
        continue
    fi

    if ! git -C "$repo_dir" cat-file -e "$pin^{commit}" 2>/dev/null; then
        printf '%-16s %8s  %s\n' "$name" "missing" \
            "the pin is not in any fetched branch (force-pushed?)"
        failed=1
        continue
    fi

    ahead=$(git -C "$repo_dir" rev-list --count "$pin..$tip" 2>/dev/null || echo 0)
    behind=$(git -C "$repo_dir" rev-list --count "$tip..$pin" 2>/dev/null || echo 0)
    tip_info=$(git -C "$repo_dir" log -1 --format='%h %cs %s' "$tip" 2>/dev/null | cut -c1-80)

    # "ahead" is the count of commits in upstream's default branch that the pin lacks. A pin that
    # contains the tip and adds commits (our fm1-base and felucca-bsp own-bt branch pins) is current,
    # not moved: report its extra commits beside the tip instead of calling it diverged.
    is_moved=0
    if [ "$ahead" = 0 ] && [ "$behind" = 0 ]; then
        state=$ahead
        tip_info="up to date ($tip_info)"
    elif [ "$ahead" = 0 ]; then
        state=$ahead
        tip_info="pin is $behind commits ahead ($tip_info)"
    elif [ "$behind" = 0 ]; then
        state=$ahead
        is_moved=1
    else
        state="diverged"
        is_moved=1
    fi
    # A tag on the new tip (or between it and the pin) is the actionable "new release".
    tip_tag=$(newest_tag "$repo_dir" "$tip")
    pin_tag=$(newest_tag "$repo_dir" "$pin")
    if [ -n "$tip_tag" ] && [ "$tip_tag" != "$pin_tag" ]; then
        tip_info="$tip_info  [$tip_tag]"
    fi

    if [ "$is_moved" = 1 ]; then
        moved=$((moved + 1))
        printf '%-16s %8s  %s\n' "$name" "$state" "$tip_info"
    elif [ "$only_moved" = 0 ]; then
        printf '%-16s %8s  %s\n' "$name" "$state" "$tip_info"
    fi
done

say ""
if [ "$moved" = 0 ] && [ "$failed" = 0 ]; then
    say "all $total pins are current."
    exit 0
fi
[ "$moved" = 0 ] || say "$moved of $total pins can move."
[ "$failed" = 0 ] || say "some repos could not be checked (see above)."
say "Bump them together with their patches: README 'Bumping a pin'."
exit 1
