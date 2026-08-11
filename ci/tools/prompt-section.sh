#!/bin/sh
# prompt-section.sh — read one phase of ci/PROMPT.md instead of the whole file.
#
# WHY THIS EXISTS
#   ci/PROMPT.md is ~2100 lines. A session that reads it whole spends ~30k tokens
#   per context, and re-reads it after every handoff. A worker only ever needs the
#   front matter plus the phase it is on. This extracts exactly that, by the
#   <!-- phase:N --> markers the file carries.
#
#   Splitting PROMPT.md into per-phase files would break the 149 in-file "step N"
#   cross-references, lint-docs-drift, and ci/feedback/'s step citations. Range
#   addressing keeps one file and one stable numbering.
#
# USAGE
#   prompt-section.sh 3            # phase 3, with the front matter
#   prompt-section.sh 3 --bare     # phase 3 alone, no front matter
#   prompt-section.sh rules        # front matter only (always-loaded part)
#   prompt-section.sh 3 --steps    # phase 3's step headings only
#   prompt-section.sh --list       # every phase with its step range and line count
#   prompt-section.sh --hash       # prompt_version for ci/.adopted (see below)
#
# THE HASH
#   --hash digests the STEP BODIES only (## <n> — ... headings and the lines under
#   them), never the front matter or the phase preambles. Phase 0 compares an
#   adopter's recorded prompt_version against this to decide whether a re-alignment
#   is needed. Hashing the whole file instead would invalidate every adopter's
#   stamp on any prose edit and force needless full re-runs.
#
# Exit: 0 ok, 1 bad usage, 2 PROMPT.md not found or phase absent.

set -eu

# CDPATH is unset rather than prefix-assigned: a prefix assignment on `cd` reads
# as SC1007 to shellcheck, and an inherited CDPATH would make `cd` resolve
# somewhere else entirely and print the destination.
unset CDPATH
SELF_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
PROMPT="$SELF_DIR/../PROMPT.md"

test -f "$PROMPT" || { echo "prompt-section: no PROMPT.md at $PROMPT" >&2; exit 2; }

usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

# Front matter = everything before the first phase marker.
front_matter() {
    awk '/^<!-- phase:[0-9]+ -->/ { exit } { print }' "$PROMPT"
}

# One phase = its marker through the line before the next marker (or EOF).
phase_body() {
    awk -v want="$1" '
        /^<!-- phase:[0-9]+ -->/ {
            match($0, /[0-9]+/)
            cur = substr($0, RSTART, RLENGTH)
            on = (cur == want)
            if (on) found = 1
            next
        }
        on { print }
        END { if (!found) exit 3 }
    ' "$PROMPT"
}

case "${1:-}" in
    ''|-h|--help)
        usage 0
        ;;

    --list)
        awk '
            /^<!-- phase:[0-9]+ -->/ {
                if (p != "") printf "phase %s  steps %-8s %d lines\n", p, rng, n
                match($0, /[0-9]+/); p = substr($0, RSTART, RLENGTH)
                n = 0; first = ""; last = ""
                next
            }
            p != "" {
                n++
                if ($0 ~ /^## [0-9]+ — /) {
                    match($0, /[0-9]+/); s = substr($0, RSTART, RLENGTH)
                    if (first == "") first = s
                    last = s
                    rng = (first == last) ? first : first "-" last
                }
            }
            END { if (p != "") printf "phase %s  steps %-8s %d lines\n", p, rng, n }
        ' "$PROMPT"
        ;;

    --hash)
        # Step bodies only: from each "## <n> — " heading to the line before the
        # next step heading, phase marker, or phase title. Front matter and phase
        # preambles are deliberately excluded — see THE HASH above.
        awk '
            /^## [0-9]+ — / { on = 1; print; next }
            /^<!-- phase:[0-9]+ -->/ { on = 0; next }
            /^# Phase /              { on = 0; next }
            on { print }
        ' "$PROMPT" | sha256sum | cut -d" " -f1
        ;;

    rules)
        front_matter
        ;;

    [0-9])
        phase=$1
        mode=${2:---full}
        case "$mode" in
            --full)
                front_matter
                phase_body "$phase" || {
                    echo "prompt-section: no phase $phase in PROMPT.md" >&2; exit 2; }
                ;;
            --bare)
                phase_body "$phase" || {
                    echo "prompt-section: no phase $phase in PROMPT.md" >&2; exit 2; }
                ;;
            --steps)
                phase_body "$phase" 2>/dev/null | grep '^## [0-9]\+ — ' || {
                    echo "prompt-section: no phase $phase in PROMPT.md" >&2; exit 2; }
                ;;
            *)
                echo "prompt-section: unknown mode $mode" >&2; usage 1
                ;;
        esac
        ;;

    *)
        echo "prompt-section: unknown argument $1" >&2
        usage 1
        ;;
esac
