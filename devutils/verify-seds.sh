#!/bin/bash
# Verify every `sed -i` / `sed_i` in patch.sh and theme.sh against real
# Chromium sources, without doing a checkout or a build.
#
#   devutils/verify-seds.sh [chromium-version]
#
# Defaults to the version pinned in vanadium/args.gn.
#
# Why this exists: `sed -i` exits 0 and changes nothing when its pattern stops
# matching. A Chromium bump that renames or reflows a targeted line therefore
# drops an Aerium change silently - green build, missing behaviour. This script
# runs the real scripts (so bash does the parsing, not a regex approximation)
# against a sparse tree of files fetched from chromium.googlesource.com and
# reports every substitution that did nothing.
#
# Reading the output:
#
#   OK       the substitution applied
#   NOOP     the pattern did not match. Either the code moved upstream (fix the
#            pattern), the change landed upstream (delete the substitution), or
#            the line is added by a Vanadium patch rather than being present in
#            pristine Chromium (expected - cross-check with
#            `grep -r '<pattern>' vanadium/patches`)
#   MISSING  the target file does not exist in pristine Chromium. Expected for
#            aerium/... paths, which Vanadium's patches create (after build.sh
#            rewrites vanadium/ -> aerium/). Cross-check the same way.
#
# A NOOP is not automatically a bug, and a clean run is not proof the build
# works - it only proves each pattern still matches something.
#
# Known-expected results as of Chromium 152.0.7977.54:
#   NOOP  build/config/android/rules.gni  - `if (!_omit_dex) {` is inserted by
#         vanadium patch 0187, so it is absent from pristine Chromium. Correct.
#   MISSING  every aerium/... path - created by vanadium patches. Correct.
# Anything beyond those needs investigating.
#
# Targets inside a DEPS submodule (third_party/search_engines_data/resources)
# are fetched from that submodule's own repo at the commit src pins, so they
# get checked like any other file instead of being reported MISSING forever.
#
# History, kept because both were mistaken for broken patterns at first:
# the .137 bump surfaced a second NOOP on
# components/autofill/core/common/autofill_prefs.cc. That one was not a moved
# anchor: the same substitution had been added to both patch.sh and theme.sh in
# separate commits, and since build.sh sources patch.sh first, theme.sh's copy
# always found the work already done. The duplicate in patch.sh is gone and
# theme.sh owns it now, so this should not reappear - if it does, it means the
# pattern really has moved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SCRIPT_DIR
VERSION="${1:-$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' "$SCRIPT_DIR/vanadium/args.gn")}"
WORK="${WORK:-$(mktemp -d)}"
TREE="$WORK/tree"
REPORT="$WORK/report.tsv"
BASE="https://chromium.googlesource.com/chromium/src/+/refs/tags/$VERSION"

echo "[verify-seds] chromium $VERSION"
echo "[verify-seds] workdir $WORK"
mkdir -p "$TREE"

# --- the sed interceptor, shared by both passes -------------------------------
_harness() {
    local log_only="$1"
    cat > "$WORK/harness.sh" <<'HARNESS'
_idx=0
# Argument shape of every sed call in these scripts is:
#   sed -i [flags] <one script> <file> [<file> ...]
# so: skip flags, the first non-flag argument is the script, everything after
# it is a target. Deriving targets positionally avoids both guessing from
# path-shaped text inside the script and depending on the files existing yet.
_sed_targets() {
    local a script_seen=0
    for a in "$@"; do
        case "$a" in -*) continue ;; esac
        if [ "$script_seen" = 0 ]; then script_seen=1; continue; fi
        printf '%s\n' "$a"
    done
}
sed() {
    _idx=$((_idx + 1))
    local -a files=()
    mapfile -t files < <(_sed_targets "$@")
    if [ "$LOG_ONLY" = 1 ]; then
        local f
        for f in "${files[@]}"; do printf 'TARGET\t%s\n' "$f" >> "$REPORT"; done
        return 0
    fi
    if [ "$1" != "-i" ]; then command sed "$@"; return $?; fi
    local -a present=() sums=()
    local f
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then present+=("$f"); else
            printf 'MISSING\t%s\t%s\n' "$_idx" "$f" >> "$REPORT"
        fi
    done
    [ "${#present[@]}" = 0 ] && return 0
    for f in "${present[@]}"; do sums+=("$(cksum < "$f")"); done
    command sed "$@" 2>/dev/null || {
        printf 'ERROR\t%s\t%s\n' "$_idx" "${present[0]}" >> "$REPORT"; return 0; }
    local i=0
    for f in "${present[@]}"; do
        if [ "${sums[$i]}" = "$(cksum < "$f")" ]; then
            printf 'NOOP\t%s\t%s\n' "$_idx" "$f" >> "$REPORT"
        else
            printf 'OK\t%s\t%s\n' "$_idx" "$f" >> "$REPORT"
        fi
        i=$((i + 1))
    done
    return 0
}
# Fallback only: theme.sh defines its own sed_i and that definition wins from
# the moment it is sourced. This one covers any script that calls sed_i
# without defining it, and routes it in WITH the -i flag so the override above
# takes its measuring branch rather than its passthrough branch.
#
# What actually used to exempt every sed_i from this check lived in theme.sh:
# its sed_i split script-from-files by testing `-e "$arg"`, and pass 1 below
# runs against a still-empty tree, so nothing looked like a file, files[] came
# back empty and it returned before calling sed. The targets were never
# collected here, so they were never fetched and never evaluated in pass 2 -
# and sed_i is reserved for substitutions whose absence is a behaviour
# regression, so those were the only ones with no safety net. Chromium 152
# added kSecGPC to ipc_utils.cc itself and this script still reported a clean
# run while the build died on that exact sed. theme.sh derives its targets
# positionally now.
sed_i() { sed -i "$@"; }
cd "$TREE"
set +e
source "$SCRIPT_DIR/patch.sh" >/dev/null 2>&1
source "$SCRIPT_DIR/theme.sh" >/dev/null 2>&1
exit 0
HARNESS
    LOG_ONLY="$log_only" REPORT="$REPORT" TREE="$TREE" SCRIPT_DIR="$SCRIPT_DIR" \
        bash "$WORK/harness.sh"
}

# --- pass 1: collect target paths --------------------------------------------
: > "$REPORT"
_harness 1
cut -f2 "$REPORT" | sort -u | grep -v '^$' > "$WORK/targets.txt"
echo "[verify-seds] $(wc -l < "$WORK/targets.txt") distinct sed targets"

# --- map DEPS submodules -----------------------------------------------------
# Some sed targets live in repositories DEPS pulls in rather than in
# chromium/src itself. third_party/search_engines_data/resources is one: it is
# a submodule, so definitions/*.json 404s against src at every version and the
# four search-engine substitutions pointed at it would look permanently
# MISSING. Map each submodule prefix to its own repo and the commit src pins,
# longest prefix first so a nested submodule wins over its parent.
SUBMAP="$WORK/submodules.tsv"
curl -sSf "$BASE/DEPS?format=TEXT" 2>/dev/null | base64 -d > "$WORK/DEPS" \
    || : > "$WORK/DEPS"
python3 - "$WORK/DEPS" > "$SUBMAP" <<'DEPSPY'
import re, sys

text = open(sys.argv[1]).read()
gitvars = dict(re.findall(r"'(\w+)':\s*'(https://[^']+)'", text))
entry = re.compile(
    r"'src/([^']+)':\s*(?:\{\s*'url':\s*)?"
    r"Var\('(\w+)'\)\s*\+\s*'([^']+)'\s*\+\s*'@'\s*\+\s*'([0-9a-f]{40})'")
rows = []
for path, var, repo, sha in entry.findall(text):
    base = gitvars.get(var)
    if base:
        rows.append((path, base + repo.removesuffix('.git'), sha))
for path, repo, sha in sorted(rows, key=lambda r: -len(r[0])):
    print('%s\t%s\t%s' % (path, repo, sha))
DEPSPY
echo "[verify-seds] $(wc -l < "$SUBMAP") DEPS submodules mapped"

# --- fetch them --------------------------------------------------------------
fetched=0
while read -r p; do
    case "$p" in aerium/*|\$*) continue ;; esac
    dest="$TREE/$p"
    [ -f "$dest" ] && continue
    mkdir -p "$(dirname "$dest")"
    url="$BASE/$p?format=TEXT"
    while IFS=$'\t' read -r sub repo sha; do
        case "$p" in "$sub"/*)
            url="$repo/+/$sha/${p#"$sub"/}?format=TEXT"; break ;;
        esac
    done < "$SUBMAP"
    for attempt in 1 2 3 4; do
        if curl -sSf "$url" 2>/dev/null | base64 -d > "$dest" \
           && [ -s "$dest" ]; then
            fetched=$((fetched + 1)); break
        fi
        rm -f "$dest"
        [ "$attempt" = 4 ] || sleep $((attempt * 2))
    done
done < "$WORK/targets.txt"
echo "[verify-seds] fetched $fetched files"

# --- pass 2: evaluate --------------------------------------------------------
: > "$REPORT"
_harness 0

echo
awk -F'\t' '/^(OK|NOOP|ERROR|MISSING)/ {c[$1]++} END {for (k in c) printf "%-8s %s\n", k, c[k]}' "$REPORT"
echo
if grep -qP '^(NOOP|ERROR)' "$REPORT"; then
    echo "Substitutions that did nothing on Chromium $VERSION:"
    grep -P '^(NOOP|ERROR)' "$REPORT" | awk -F'\t' '{printf "  %-7s #%-4s %s\n", $1, $2, $3}'
    echo
fi
if grep -qP '^MISSING' "$REPORT"; then
    echo "Targets absent from pristine Chromium (expect aerium/... here):"
    grep -P '^MISSING' "$REPORT" | cut -f3 | sort -u | sed 's/^/  /'
fi
