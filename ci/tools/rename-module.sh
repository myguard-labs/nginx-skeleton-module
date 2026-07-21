#!/usr/bin/env bash
#
# Turn this skeleton into a real module.
#
#   tools/rename-module.sh <name>
#
# <name> is the bare module name, lowercase, no prefix/suffix:
#
#   tools/rename-module.sh ratelimit
#     -> ngx_http_ratelimit_module, directives `ratelimit`, `ratelimit_status`,
#        src/ngx_http_ratelimit_module.c, NGX_HTTP_RATELIMIT_* macros
#
# Renames files and rewrites every identifier, directive, macro and CI path.
# Run it in a FRESH clone, once, before the first commit -- it rewrites the
# working tree in place and does not un-rename.
#
# Afterwards, delete this script: it is skeleton scaffolding, not part of a
# real module.

set -euo pipefail

NAME="${1:-}"

if [ -z "$NAME" ]; then
    echo "usage: tools/rename-module.sh <name>   (e.g. ratelimit)" >&2
    exit 2
fi

if ! printf '%s' "$NAME" | grep -qE '^[a-z][a-z0-9_]*$'; then
    echo "error: name must be lowercase [a-z][a-z0-9_]* (got: $NAME)" >&2
    echo "       pass the bare name, not ngx_http_<name>_module" >&2
    exit 2
fi

if [ "$NAME" = "skel" ]; then
    echo "error: 'skel' is the placeholder name" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ ! -f src/ngx_http_skel_module.c ]; then
    echo "error: src/ngx_http_skel_module.c not found -- already renamed?" >&2
    exit 1
fi

UPPER="$(printf '%s' "$NAME" | tr '[:lower:]' '[:upper:]')"
export NAME UPPER   # visible to perl below as $ENV{NAME} / $ENV{UPPER}

echo "==> renaming skel -> $NAME"

# 1. Rewrite content BEFORE moving files, so the paths below still exist.
#    Order matters: SKEL (macros) before skel (identifiers) would be fine either
#    way since the patterns are case-distinct, but keep both explicit.
#    -I: skip binaries. Restrict to the trees that can contain the token.
#
#    In the documented flow (`rm -rf .git && git init`) `git ls-files` succeeds
#    but prints NOTHING -- the fresh index is empty. Falling back only on
#    command failure would silently rewrite zero files, so fall back on empty
#    output too.
files=$(git ls-files 2>/dev/null || true)
if [ -z "$files" ]; then
    files=$(find . -type f -not -path './.git/*' -not -path './.build/*')
fi

while IFS= read -r f; do
    [ -n "$f" ] || continue          # empty when git ls-files/find found nothing
    case "$f" in
        */corpus/*|*/regressions/*) continue ;;   # fuzz seeds are raw bytes
    esac
    [ -f "$f" ] || continue
    if grep -qI 'skel\|SKEL' "$f" 2>/dev/null; then
        # Shield the English word "skeleton" in ALL THREE cases before rewriting
        # the placeholder: a bare s/skel/name/g corrupts "skeleton"->"nameeton",
        # and s/SKEL/UPPER/g corrupts "SKELETON"->"UPPERETON". \x01-\x03 cannot
        # occur in a text file that just passed the grep -I binary check.
        #
        # perl, not `sed -i`: this is a template bootstrapped on arbitrary
        # machines. BSD sed (macOS) has no \xNN escape (it would inject the
        # literal "x01") and its -i needs a backup-suffix arg; perl's \xNN and
        # -i are identical on GNU/BSD. NAME/UPPER come via $ENV so nothing from
        # the argument is interpolated into the program text.
        perl -i -pe 's/SKELETON/\x01/g; s/Skeleton/\x02/g; s/skeleton/\x03/g; s/SKEL/$ENV{UPPER}/g; s/skel/$ENV{NAME}/g; s/\x03/skeleton/g; s/\x02/Skeleton/g; s/\x01/SKELETON/g' "$f"
        echo "    rewrote $f"
    fi
done <<< "$files"

# 2. Move the files whose NAMES carry the placeholder.
for f in src/ngx_http_skel_module.c \
         src/ngx_http_skel_scan.c \
         src/ngx_http_skel_scan.h; do
    new="${f//skel/$NAME}"
    if [ -f "$f" ]; then
        if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            git mv "$f" "$new"
        else
            mv "$f" "$new"
        fi
        echo "    moved $f -> $new"
    fi
done

echo
echo "done. ngx_http_${NAME}_module"
echo
echo "Next:"
echo "  1. rm tools/rename-module.sh          # scaffolding, not part of the module"
echo "  2. edit src/ngx_http_${NAME}_scan.c   # replace the rule table / matching logic"
echo "  3. edit ci/t/03-fp-negative.t            # a negative per rule, same commit"
echo "  4. bash tools/ci-build.sh nginx 1.31.2"
echo "  5. TEST_NGINX_TIMEOUT=20 prove -v ci/t/"
echo "  6. update README.md (name, directives, what it actually does)"
