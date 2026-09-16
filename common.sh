export SCRIPT_DIR=$(realpath $(dirname $0))

sed_i() {
    # A sed invocation can name several trailing files (theme.sh has one that
    # patches both worker fetch-context implementations at once), so the
    # targets are derived positionally: skip flags, the first non-flag
    # argument is the script, everything after it is a file.
    #
    # Splitting them by testing `-e "$arg"` instead - which this used to do -
    # is wrong twice over. A target whose path upstream renamed gets
    # reclassified as part of the script, so the failure reads "no existing
    # sed target" instead of naming the file that moved. Worse, it made every
    # sed_i invisible to devutils/verify-seds.sh: that script collects targets
    # in a first pass over an *empty* tree, so nothing existed, files[] came
    # back empty, and sed_i returned before calling sed at all. The targets
    # were never collected, never fetched, and never evaluated - leaving the
    # substitutions reserved for behaviour regressions as the only ones with
    # no version-bump safety net.
    local -a files=() expr=()
    local arg script_seen=0
    for arg in "$@"; do
        case "$arg" in
            -*) expr+=("$arg"); continue ;;
        esac
        if [ "$script_seen" = 0 ]; then
            script_seen=1
            expr+=("$arg")
            continue
        fi
        files+=("$arg")
    done
    if [ "${#files[@]}" -eq 0 ]; then
        echo "[aerium] FATAL: no sed target in: $*" >&2
        return 1
    fi

    # A missing target is reported but does not short-circuit the sed call:
    # verify-seds learns which paths a substitution wants by intercepting that
    # call, and it needs to hear about the missing ones most of all.
    local f rc=0
    local -a before_sums=()
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then
            before_sums+=("$(cksum < "$f")")
        else
            echo "[aerium] FATAL: sed target does not exist: $f" >&2
            echo "[aerium]        upstream probably moved this file - see theme.sh" >&2
            before_sums+=("")
            rc=1
        fi
    done
    sed -i "$@" || rc=1
    local i=0
    for f in "${files[@]}"; do
        if [ -e "$f" ] && [ -n "${before_sums[$i]}" ] \
           && [ "${before_sums[$i]}" = "$(cksum < "$f")" ]; then
            echo "[aerium] FATAL: sed changed nothing in $f" >&2
            echo "[aerium]        expression: ${expr[*]}" >&2
            echo "[aerium]        upstream probably moved this code - see theme.sh" >&2
            rc=1
        fi
        i=$((i + 1))
    done
    return $rc
}

replace() {
    export org=$2 new=$3
    find $1 -type f -exec sed -i 's@'$org'@'$new'@g' {} \;
}

set_keys() {
    mkdir -p $SCRIPT_DIR/keys
    echo $LOCAL_TEST_JKS | base64 -d > $SCRIPT_DIR/keys/local.properties
    echo $STORE_TEST_JKS | base64 -d > $SCRIPT_DIR/keys/test.jks
    unset LOCAL_TEST_JKS
    unset STORE_TEST_JKS
}

sign_apk() {
    export apksigner=$(find $ANDROID_HOME/build-tools -name apksigner | sort | tail -n 1)
    source $SCRIPT_DIR/keys/local.properties
    $apksigner sign -verbose -ks $SCRIPT_DIR/keys/test.jks --ks-pass pass:$storePassword --key-pass pass:$keyPassword --ks-key-alias $keyAlias --out $2 $1 || exit 1
}

sign_aab() {
    source $SCRIPT_DIR/keys/local.properties
    jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore $SCRIPT_DIR/keys/test.jks -storepass $storePassword -keypass $keyPassword -signedjar $2 $1 $keyAlias || exit 1
}

version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}
