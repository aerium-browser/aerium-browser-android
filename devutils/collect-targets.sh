#!/bin/bash
# Report every file that patch.sh and theme.sh write to, with the call site.
#
#   devutils/collect-targets.sh > targets.tsv
#
# Output is one TAB-separated row per (call site, target):
#
#   <script path>	<line number>	<target path>
#
# Nothing is modified: the scripts are sourced with `sed`, `sed_i` and `perl`
# replaced by stubs that record their arguments and return, over an empty
# scratch directory. That is deliberately the same trick devutils/verify-seds.sh
# uses for its first pass, and it works for the same reason - bash parses the
# invocations, so a multi-line sed script or a `'"'"'` escape cannot be
# misread the way a regex over the file would misread it.
#
# The line number is what makes the output useful beyond a file list:
# generate_patch_manifest.py attributes each target to the `# ---` section it
# was called from, so the chrome://aerium page counts what the build actually
# touches rather than what someone remembered to write down.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/harness.sh" <<'HARNESS'
set -u

# The call site, skipping our own stubs. BASH_LINENO[i] is the line in
# BASH_SOURCE[i+1] from which FUNCNAME[i] was called, so the first frame that
# is not a stub names the line the build script itself is on - which is what
# attributes a target to a section. Without this walk every sed_i target would
# be reported at the one line inside sed_i that calls sed.
_call_site() {
    local k=0
    while [ "$k" -lt "${#FUNCNAME[@]}" ]; do
        case "${FUNCNAME[$k]}" in
            _call_site|_report|sed|sed_i|perl) k=$((k + 1)); continue ;;
        esac
        break
    done
    printf '%s\t%s' "${BASH_SOURCE[$k]}" "${BASH_LINENO[$((k - 1))]}"
}

# Argument shape of every sed call in these scripts is
#   sed -i [flags] <one script> <file> [<file> ...]
# so: skip flags, the first non-flag argument is the script, the rest are
# targets. Derived positionally rather than by testing whether the argument
# looks like an existing path - the tree here is empty, so nothing would.
_report() {
    local site script_seen=0 a
    site="$(_call_site)"
    for a in "$@"; do
        case "$a" in -*) continue ;; esac
        if [ "$script_seen" = 0 ]; then script_seen=1; continue; fi
        printf '%s\t%s\n' "$site" "$a" >> "$TARGETS"
    done
}

sed() {
    # Only -i writes. A read-only sed in a pipeline is not a patch.
    if [ "${1:-}" != "-i" ]; then command sed "$@"; return $?; fi
    _report "$@"
    return 0
}
sed_i() { sed -i "$@"; }
perl() { _report "$@"; return 0; }

cd "$TREE"
set +e
source "$SCRIPT_DIR/patch.sh" >/dev/null 2>&1
source "$SCRIPT_DIR/theme.sh" >/dev/null 2>&1
exit 0
HARNESS

mkdir -p "$WORK/tree"
: > "$WORK/targets.tsv"
TARGETS="$WORK/targets.tsv" TREE="$WORK/tree" SCRIPT_DIR="$SCRIPT_DIR" \
    bash "$WORK/harness.sh"

# Whole files the scripts create outright. These arrive by shell redirection,
# which a `cat` stub cannot see - the redirect is applied by the shell, so the
# function is called with no arguments at all. Read straight out of the source
# instead; the form is fixed and unambiguous.
grep -nE "^cat > [^ ]+ <<" "$SCRIPT_DIR/patch.sh" "$SCRIPT_DIR/theme.sh" \
    | sed -E 's|^([^:]+):([0-9]+):cat > ([^ ]+) <<.*|\1\t\2\t\3|' \
    >> "$WORK/targets.tsv"

sort -u "$WORK/targets.tsv" | grep -v '^[[:space:]]*$'
