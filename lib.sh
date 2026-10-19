# Copyright 2026 Dioide
# SPDX-License-Identifier: GPL-3.0-only

SCRIPT_DIR=$(realpath "$(dirname "$0")")
export SCRIPT_DIR

set_keys() {
    local dir="$SCRIPT_DIR/keys"
    mkdir -p "$dir"
    printf '%s' "$LOCAL_TEST_JKS" | base64 -d > "$dir/local.properties"
    printf '%s' "$STORE_TEST_JKS" | base64 -d > "$dir/test.jks"
    unset LOCAL_TEST_JKS STORE_TEST_JKS
}

sign_apk() {
    local signer
    signer=$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n1)
    if [ -z "$signer" ]; then
        echo "[aerium] FATAL: apksigner not found under $ANDROID_HOME/build-tools" >&2
        exit 1
    fi
    (
        set -a
        . "$SCRIPT_DIR/keys/local.properties"
        "$signer" sign --ks "$SCRIPT_DIR/keys/test.jks" --ks-key-alias "$keyAlias" \
            --ks-pass "pass:$storePassword" --key-pass "pass:$keyPassword" --out "$2" "$1"
    ) || exit 1
}
