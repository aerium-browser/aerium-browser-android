# Copyright 2026 Dioide
# SPDX-License-Identifier: GPL-3.0-only

AERIUM_CORE_DIR="$SCRIPT_DIR"
mkdir -p aerium
for part in api bridge defaults; do
    [ -d "$AERIUM_CORE_DIR/$part" ] && cp -r "$AERIUM_CORE_DIR/$part" aerium/
done
aerium_patches=("$AERIUM_CORE_DIR"/patches/*.patch)
if [ -e "${aerium_patches[0]}" ]; then
    for patch in "${aerium_patches[@]}"; do
        if ! git am -3 --whitespace=nowarn "$patch"; then
            echo "[aerium] FATAL: core patch $(basename "$patch") did not apply" >&2
            git am --abort || true
            exit 1
        fi
    done
    echo "[aerium] core patches applied: ${#aerium_patches[@]}"
else
    echo "[aerium] core patches applied: 0"
fi
while IFS= read -r aerium_dir; do
    aerium_repo=${aerium_dir#"$AERIUM_CORE_DIR/patches/"}
    aerium_count=0
    for patch in "$aerium_dir"/*.patch; do
        if ! git -C "$aerium_repo" am -3 --whitespace=nowarn "$patch"; then
            echo "[aerium] FATAL: core patch $aerium_repo/$(basename "$patch") did not apply" >&2
            git -C "$aerium_repo" am --abort || true
            exit 1
        fi
        aerium_count=$((aerium_count + 1))
    done
    echo "[aerium] core patches applied in $aerium_repo: $aerium_count"
done < <(find "$AERIUM_CORE_DIR/patches" -mindepth 2 -name '*.patch' -printf '%h\n' | sort -u)
unset aerium_patches aerium_dir aerium_repo aerium_count part
