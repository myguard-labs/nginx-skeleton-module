#!/usr/bin/env bash
#
# Check nginx.org/angie.software for newer releases than what's pinned in this
# repo, and rewrite every pin in place. Called by .github/workflows/bump.yml on
# a schedule; also runnable locally to preview a bump before it lands.
#
#   ci/tools/bump-versions.sh [--dry-run]
#
# What gets bumped, and why each one has to move together:
#   - NGINX_VERSION (mainline pin)  -- .github/workflows/{build-test,ci-deep,codeql,valgrind,asan,fuzzing,security-scanners}.yml
#                                      (EVERY workflow with an NGINX_VERSION env
#                                      -- miss one and its gate silently tests a
#                                      stale nginx after a bump)
#   - nginx stable + angie pins     -- ci-deep.yml's build-flavors matrix
#   - NGINX_SHA256 / ANGIE_SHA256   -- ci/tools/ci-build.sh (this script computes
#                                      the digest itself from the same tarball
#                                      ci-build.sh will later verify against)
#   - ci/vendor/nginx-tests submodule  -- `git submodule update --remote`
#
# A version bump with a stale sha256 pin is worse than no pin (ci-build.sh
# treats a missing pin as "print a warning", but a WRONG pin is a hard FATAL --
# so every version edit here is paired with a digest computed from the exact
# tarball that version resolves to, never carried over from a previous entry.

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(dirname "$0")/../.."

# --- discover latest versions -------------------------------------------

# nginx.org/en/download.html lists Mainline then Stable then Legacy, each as
# its own section header followed by a table whose first tarball link is that
# section's current release -- no JSON feed exists, so parse the one page
# nginx itself treats as authoritative.
latest_nginx() {
    local branch="$1"  # mainline | stable
    local page section
    page="$(curl -fsSL https://nginx.org/en/download.html)"
    case "$branch" in
        mainline) section="Mainline version" ;;
        stable)   section="Stable version" ;;
    esac
    # The page is one long line; cut everything before the section header, then
    # take the first tarball link after it -- that link is that section's
    # current release, per nginx.org's own page layout.
    echo "${page#*"$section"}" \
        | grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | head -1 \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

latest_angie() {
    local json
    # The runners share an egress IP, so the unauthenticated API allowance
    # (60/hr) is routinely exhausted and this call 403s. Send GH_TOKEN when
    # one is present -- authenticated requests get their own, far larger quota.
    local -a auth=()
    [ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GH_TOKEN")
    if ! json="$(curl -fsSL "${auth[@]}" https://api.github.com/repos/webserver-llc/angie/releases/latest)"; then
        echo "error: could not query the angie release API (rate limit? set GH_TOKEN)" >&2
        return 1
    fi
    echo "$json" | grep -m1 '"tag_name"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

NEW_MAINLINE="$(latest_nginx mainline)"
NEW_STABLE="$(latest_nginx stable)"
NEW_ANGIE="$(latest_angie)"

for v in NEW_MAINLINE NEW_STABLE NEW_ANGIE; do
    if [ -z "${!v}" ]; then
        echo "FATAL: could not determine $v -- refusing to bump with a blank version" >&2
        exit 1
    fi
done

echo "latest: nginx mainline=$NEW_MAINLINE stable=$NEW_STABLE angie=$NEW_ANGIE"

# Each matrix entry is "version:" immediately followed by "label:" (see
# ci-deep.yml's build-flavors job) -- pair them up rather than assuming
# ordering, so a future reordering of the matrix can't silently swap pins.
matrix_version_for_label() {
    awk -v want="$1" '
        /version:/ { match($0, /"[0-9.]+"/); v = substr($0, RSTART+1, RLENGTH-2); next }
        /label:/   { split($0, a, ":"); l = a[2]; gsub(/[ \t]/, "", l); if (l == want) { print v; exit } }
    ' .github/workflows/ci-deep.yml
}

CUR_MAINLINE="$(grep -m1 'NGINX_VERSION:' .github/workflows/build-test.yml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
CUR_STABLE="$(matrix_version_for_label stable)"
CUR_ANGIE="$(matrix_version_for_label angie)"

echo "pinned: nginx mainline=$CUR_MAINLINE stable=$CUR_STABLE angie=$CUR_ANGIE"

CHANGED=0

# --- sha256 helper --------------------------------------------------------
sha256_for() {
    local flavor="$1" version="$2" url tmp digest
    case "$flavor" in
        nginx) url="https://nginx.org/download/nginx-${version}.tar.gz" ;;
        angie) url="https://download.angie.software/files/angie-${version}.tar.gz" ;;
    esac
    tmp="$(mktemp)"
    curl -fsSL "$url" -o "$tmp"
    digest="$(sha256sum "$tmp" | awk '{print $1}')"
    rm -f "$tmp"
    echo "$digest"
}

# --- bump a version everywhere it's pinned --------------------------------
bump_nginx_workflow_pin() {
    local old="$1" new="$2"
    [ "$old" = "$new" ] && return 0
    # Every workflow that pins NGINX_VERSION -- keep this list == the set that
    # `grep -l 'NGINX_VERSION:' .github/workflows/*.yml` returns, or a bumped
    # mainline leaves the omitted gate testing a stale nginx (silent + green).
    for f in .github/workflows/build-test.yml .github/workflows/ci-deep.yml \
             .github/workflows/codeql.yml .github/workflows/valgrind.yml \
             .github/workflows/asan.yml .github/workflows/fuzzing.yml \
             .github/workflows/security-scanners.yml; do
        sed -i "s/NGINX_VERSION: \"${old}\"/NGINX_VERSION: \"${new}\"/" "$f"
    done
    CHANGED=1
}

bump_matrix_pin() {
    local label="$1" old="$2" new="$3"
    [ "$old" = "$new" ] && return 0
    # Matrix entries are unique per label (mainline/stable/angie) in ci-deep.yml.
    python3 - "$label" "$old" "$new" <<'PYEOF'
import re, sys
label, old, new = sys.argv[1:4]
path = ".github/workflows/ci-deep.yml"
text = open(path).read()
pattern = re.compile(
    r'(version:\s*"' + re.escape(old) + r'"\n\s*label:\s*' + re.escape(label) + r')'
)
replaced = pattern.sub(lambda m: m.group(1).replace(old, new), text)
if replaced == text:
    print(f"WARNING: no matrix entry matched for label={label} old={old}", file=sys.stderr)
open(path, "w").write(replaced)
PYEOF
    CHANGED=1
}

bump_sha256_pin() {
    local table="$1" old="$2" new="$3" digest="$4"
    grep -q "\[\"${new}\"\]" ci/tools/ci-build.sh && return 0  # already pinned
    # Insert the new pin right after the table's opening line; leave old
    # entries in place (ci-build.sh keys by version, older callers still work).
    sed -i "/declare -A ${table}=(/a\\    [\"${new}\"]=\"${digest}\"" ci/tools/ci-build.sh
    CHANGED=1
}

if [ "$NEW_MAINLINE" != "$CUR_MAINLINE" ]; then
    echo "bump nginx mainline: $CUR_MAINLINE -> $NEW_MAINLINE"
    if [ "$DRY_RUN" = 0 ]; then
        DIGEST="$(sha256_for nginx "$NEW_MAINLINE")"
        echo "  sha256 $DIGEST"
        bump_nginx_workflow_pin "$CUR_MAINLINE" "$NEW_MAINLINE"
        bump_matrix_pin mainline "$CUR_MAINLINE" "$NEW_MAINLINE"
        bump_sha256_pin NGINX_SHA256 "$CUR_MAINLINE" "$NEW_MAINLINE" "$DIGEST"
    else
        CHANGED=1
    fi
fi

if [ "$NEW_STABLE" != "$CUR_STABLE" ]; then
    echo "bump nginx stable: $CUR_STABLE -> $NEW_STABLE"
    if [ "$DRY_RUN" = 0 ]; then
        DIGEST="$(sha256_for nginx "$NEW_STABLE")"
        echo "  sha256 $DIGEST"
        bump_matrix_pin stable "$CUR_STABLE" "$NEW_STABLE"
        bump_sha256_pin NGINX_SHA256 "$CUR_STABLE" "$NEW_STABLE" "$DIGEST"
    else
        CHANGED=1
    fi
fi

if [ "$NEW_ANGIE" != "$CUR_ANGIE" ]; then
    echo "bump angie: $CUR_ANGIE -> $NEW_ANGIE"
    if [ "$DRY_RUN" = 0 ]; then
        DIGEST="$(sha256_for angie "$NEW_ANGIE")"
        echo "  sha256 $DIGEST"
        bump_matrix_pin angie "$CUR_ANGIE" "$NEW_ANGIE"
        bump_sha256_pin ANGIE_SHA256 "$CUR_ANGIE" "$NEW_ANGIE" "$DIGEST"
    else
        CHANGED=1
    fi
fi

# --- vendored nginx-tests submodule ---------------------------------------
if [ "$DRY_RUN" = 0 ]; then
    OLD_SUB_SHA="$(git -C ci/vendor/nginx-tests rev-parse HEAD)"
    git submodule update --remote --quiet ci/vendor/nginx-tests
    NEW_SUB_SHA="$(git -C ci/vendor/nginx-tests rev-parse HEAD)"
    if [ "$OLD_SUB_SHA" != "$NEW_SUB_SHA" ]; then
        echo "bump ci/vendor/nginx-tests: ${OLD_SUB_SHA:0:12} -> ${NEW_SUB_SHA:0:12}"
        CHANGED=1
    fi
else
    echo "(dry-run: skipping submodule update)"
fi

if [ "$CHANGED" = 0 ]; then
    echo "everything up to date, nothing to bump"
fi

echo "CHANGED=$CHANGED"
