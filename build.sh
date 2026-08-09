#!/bin/bash
# Aerium for Android — staged/resumable build.
#
# Usage:
#   ./build.sh          one-shot build (needs a beefy machine)
#   ./build.sh --ci     time-boxed CI stage: builds for at most
#                       $BUILD_TIMEOUT_MIN minutes, then stops gracefully so
#                       the next stage can resume from the build tree.
#
# On success writes release/aerium-<version>-arm64-v8a.apk and release/finished.marker
set -e
source common.sh

MODE_CI=0
[ "$1" = "--ci" ] && MODE_CI=1

# Time budget for this stage, expressed as "job timeout minus what the
# checkpoint round-trip needs", and measured from when the STAGE started - not
# from when this script started.
#
# The distinction matters: restoring the saved tree happens in the workflow
# before build.sh is even invoked, and the checkpoint is currently ~20 GB
# compressed, so download+unpack can easily eat 30-45 min. Budgeting 250 min
# from build.sh's own start therefore allowed restore + 250 + pack + upload to
# exceed the 350-min job timeout, at which point GitHub kills the runner
# mid-step: the job shows a step stuck "in_progress", the log upload never
# happens (HTTP 404 when you go looking for it), and the stage's progress is
# lost. That is the failure signature on runs 42/43/45.
#
# The stage action exports STAGE_START_TS before the restore step, so the
# elapsed calculation below covers restore too and self-corrects as the
# checkpoint grows.
JOB_TIMEOUT_MIN=${JOB_TIMEOUT_MIN:-350}
# Measured over a 15-stage run: pack averages 5.7 min and upload 2.2 min,
# so ~8 min of the reserve is actually used. At 80 every stage stopped
# compiling at ~279 of its 350 minutes and threw away ~71 min (20%) of the
# budget. 25 keeps a wide margin over the observed 8 while returning most
# of that time to the compile window.
CHECKPOINT_RESERVE_MIN=${CHECKPOINT_RESERVE_MIN:-25}
TOTAL_BUDGET_MIN=${TOTAL_BUDGET_MIN:-$((JOB_TIMEOUT_MIN - CHECKPOINT_RESERVE_MIN))}
START_TS=${STAGE_START_TS:-$(date +%s)}

export VERSION=$(grep -m1 -o '[0-9]\+\(\.[0-9]\+\)\{3\}' vanadium/args.gn)
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive
echo "[aerium] chromium version: $VERSION  ci: $MODE_CI"

# Keep the big tool caches on the large build mount (chromium/) instead of the
# small root filesystem: vpython venvs alone are multiple GB and overflow the
# CI runner's root disk otherwise. Not part of the stage artifact; they are
# recreated cheaply on each stage.
mkdir -p chromium/.vpython-root chromium/.cipd-cache chromium/.tmp
export VPYTHON_VIRTUALENV_ROOT="$SCRIPT_DIR/chromium/.vpython-root"
export CIPD_CACHE_DIR="$SCRIPT_DIR/chromium/.cipd-cache"
export TMPDIR="$SCRIPT_DIR/chromium/.tmp"

# --- system dependencies: needed on every (fresh) CI runner -----------------
sudo apt-get update
sudo apt-get install -y sudo lsb-release file nano git curl python3 python3-pillow imagemagick librsvg2-bin zstd
# Every stage runs on a fresh runner, so this install repeats each time and
# each time it leaves the downloaded .debs and package lists on the ROOT
# filesystem - which maximize-build-space has already shrunk to a ~10 GB
# reserve, minus the 6 GB swap file carved out of it. Root filling up kills the
# runner agent itself, which is why the dead stages have no log at all. Clean
# up immediately instead of only at the end of first-stage setup.
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# depot_tools must live on the big build mount, not next to the checkout: it
# plus its bootstrapped python3/cipd payload is well over a GB, and
# $SCRIPT_DIR is on the root filesystem. It is deliberately outside
# chromium/src so the checkpoint tar never picks it up; each stage re-clones
# it, which is cheap.
DEPOT_TOOLS_DIR="$SCRIPT_DIR/chromium/depot_tools"
if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git \
        "$DEPOT_TOOLS_DIR"
fi
export PATH="$DEPOT_TOOLS_DIR:$PATH"

# depot_tools normally self-bootstraps (fetches its pinned python3/cipd
# tooling) the first time gclient/gn runs. On resumed stages the entire
# fresh-setup block below - the only place that calls gclient/gn - is
# skipped, so a freshly cloned depot_tools here never gets bootstrapped and
# autoninja fails with "python3_bin_reldir.txt not found". Run the
# dedicated bootstrap-only script unconditionally so every stage has a
# working depot_tools regardless of whether source setup runs.
"$DEPOT_TOOLS_DIR/ensure_bootstrap"

# --- source setup: only on the first stage ----------------------------------
if [ ! -f chromium/src/BUILD.gn ]; then
    # git am needs a committer identity on fresh CI runners
    git config --global user.name  >/dev/null 2>&1 || git config --global user.name 'github-actions[bot]'
    git config --global user.email >/dev/null 2>&1 || git config --global user.email 'github-actions[bot]@users.noreply.github.com'
    mkdir -p chromium/src/out/Default
    cd chromium
    gclient root
    cd src
    git init
    git remote add origin $CHROMIUM_SOURCE
    git fetch --depth 1 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION
    git checkout $VERSION
    export COMMIT=$(git show-ref -s $VERSION | head -n1)
    cat > ../.gclient <<EOF
solutions = [
  {
    "name": "src",
    "url": "$CHROMIUM_SOURCE@$COMMIT",
    "deps_file": "DEPS",
    "managed": False,
    "custom_vars": {
      "checkout_android_prebuilts_build_tools": True,
      # chrome_pgo_phase=2 (args.gn) consumes real profile data - it needs
      # this checked out, or gn gen fails outright looking for a .profdata
      # file that was never downloaded.
      "checkout_pgo_profiles": True,
      "checkout_telemetry_dependencies": False,
      "codesearch": "Debug",
    },
  },
]
target_os = ["android"]
EOF
    git submodule foreach git config -f ./.git/config submodule.$name.ignore all
    git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'

    # https://grapheneos.org/build#browser-and-webview
    rm -rf $SCRIPT_DIR/vanadium/patches/*trichrome-{apk-build-targets,browser-apk-targets}.patch
    rm -rf $SCRIPT_DIR/vanadium/patches/*{detailed,supported}-language*.patch
    rm -rf $SCRIPT_DIR/vanadium/patches/*component-updates.patch
    rm -rf $SCRIPT_DIR/vanadium/patches/*{pdf,PDF,for-content-public}*.patch
    replace "$SCRIPT_DIR/vanadium/patches" "VANADIUM" "AERIUM"
    replace "$SCRIPT_DIR/vanadium/patches" "Vanadium" "Aerium"
    replace "$SCRIPT_DIR/vanadium/patches" "vanadium" "aerium"
    git am --whitespace=nowarn --keep-non-patch $SCRIPT_DIR/vanadium/patches/*.patch

    gclient sync -D --no-history --nohooks
    gclient runhooks
    rm -rf third_party/angle/third_party/VK-GL-CTS/

    ./build/install-build-deps.sh --no-prompt
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*

    source $SCRIPT_DIR/patch.sh
    source $SCRIPT_DIR/theme.sh

    # Some Vanadium patches modify .grd string files without updating the
    # checked-in .gritdeps snapshots (e.g. 0272 touches
    # components_strings.grd), which fails the *_check_gritdeps build
    # targets. Regenerate every snapshot with the official command.
    find . -name '*.grd.gritdeps' -not -path './out/*' | while read -r deps; do
        grd="${deps%.gritdeps}"
        [ -f "$grd" ] || continue
        if python3 tools/grit/grit_info.py --all-inputs "$grd" > "$deps.new" 2>/dev/null; then
            if ! cmp -s "$deps" "$deps.new"; then
                echo "[aerium] regenerated $deps"
            fi
            mv "$deps.new" "$deps"
        else
            echo "[aerium] warning: could not regenerate $deps; keeping original"
            rm -f "$deps.new"
        fi
    done

    cp $SCRIPT_DIR/args.gn out/Default/args.gn
    gn gen out/Default

    # Nothing past this point runs git against chromium/src (no later stage
    # calls gclient/git - only ninja), so its history is dead weight. This
    # is a modest, low-risk reclaim; it does not touch out/Default or any
    # third_party checkout the build actually depends on.
    rm -rf .git

    cd $SCRIPT_DIR
fi

cd chromium/src

# --- Resume hotfix (removable once a build that STARTED after 2026-07-20
# goes green): theme.sh only runs during source setup, so a tree saved by an
# earlier stage never re-runs it. Trees saved before the unsafe-buffers
# pragma landed in theme.sh fail compiling static_bitmap_image.cc under
# -Werror,-Wunsafe-buffer-usage; patch them in place on resume. Idempotent:
# no-ops on fresh trees (theme.sh already added the pragma) and on already
# patched resumed trees.
SBI=third_party/blink/renderer/platform/graphics/static_bitmap_image.cc
if [ -f "$SBI" ] && grep -q ShuffleSubchannelColorData "$SBI" && ! grep -q allow_unsafe_buffers "$SBI"; then
    sed -i '/^#include "third_party\/blink\/renderer\/platform\/graphics\/static_bitmap_image.h"$/i\
#ifdef UNSAFE_BUFFERS_BUILD\
// The Bromite canvas shuffler below does raw per-pixel pointer arithmetic.\
#pragma allow_unsafe_buffers\
#endif\
' "$SBI"
    echo "[aerium] resume hotfix: allow_unsafe_buffers pragma applied to $SBI"
fi

# compile prerequisites must exist on every fresh runner
./build/install-build-deps.sh --no-prompt || true
# ...and its .debs must not be left sitting on the small root filesystem.
sudo apt-get clean || true
sudo rm -rf /var/lib/apt/lists/* || true
df -h / "$SCRIPT_DIR/chromium" || true

# --- build (time-boxed in CI mode) -------------------------------------------
if [ $MODE_CI = 1 ]; then
    ELAPSED_MIN=$(( ($(date +%s) - START_TS) / 60 ))
    REMAINING_MIN=$(( TOTAL_BUDGET_MIN - ELAPSED_MIN ))
    if [ $REMAINING_MIN -lt 15 ]; then
        echo "[aerium] no time left for compiling this stage; resuming next stage"
        exit 0
    fi
    echo "[aerium] compiling for at most $REMAINING_MIN minutes"
    # -j 2: the free runners have 4 vCPUs but only 16 GB RAM; even -j 3 got
    # the compiler OOM-killed (exit 137) on heavy TU clusters. Two jobs peak
    # at ~14 GB worst case, which fits without relying on swap.
    #
    # NOTE on the timeout invocation: do NOT pass --foreground here. Per GNU
    # coreutils docs, --foreground means "children of command will not be
    # timed out" - i.e. the SIGINT would only reach the `autoninja` wrapper,
    # not ninja's actual compiler subprocesses, which could then keep
    # compiling (and writing object files) for the full -k grace period
    # regardless of the intended cutoff. Every previous timed-out stage
    # failed with exit 137 at almost exactly the REMAINING_MIN mark - the
    # signature of the -k grace period's SIGKILL, not a graceful stop.
    # Without --foreground, timeout puts autoninja/ninja in their own
    # process group and signals the whole group, so SIGINT reaches the
    # in-flight compiler jobs directly. -k is still generous (10m) as a
    # backstop for any single translation unit that's slow to unwind.
    set +e
    timeout -s INT -k 10m ${REMAINING_MIN}m autoninja -j "${NINJA_JOBS:-2}" -C out/Default chrome_public_apk
    RET=$?
    set -e
    # Kill any straggler build processes so nothing keeps writing to the
    # tree while the stage action packs it into the resume artifact.
    pkill -9 -f 'siso' 2>/dev/null || true
    sleep 3
    if [ $RET = 124 ]; then
        echo "[aerium] time budget reached; build will resume on the next stage"
        exit 0
    elif [ $RET != 0 ]; then
        echo "[aerium] build failed with exit code $RET"
        # siso (the build backend modern Chromium/Vanadium uses in place of
        # plain ninja) does not echo a failing command's own output to
        # stdout - it only prints "see ./out/Default/siso_output for full
        # command line and output" and leaves it at that. Without this dump,
        # every CI failure was a black box that could only be diagnosed by
        # downloading the multi-GB resume artifact and looking inside it.
        if [ -f out/Default/siso_output ]; then
            echo "[aerium] --- tail of out/Default/siso_output (last 200 lines) ---"
            tail -n 200 out/Default/siso_output || true
            echo "[aerium] --- end of siso_output tail ---"
        fi
        exit $RET
    fi
else
    autoninja -j "${NINJA_JOBS:-2}" -C out/Default chrome_public_apk
fi

# --- sign & finish ------------------------------------------------------------
export PATH=$PWD/third_party/jdk/current/bin/:$PATH
export ANDROID_HOME=$PWD/third_party/android_sdk/public

mkdir -p $SCRIPT_DIR/release
set_keys
sign_apk "$(find out/Default/apks -name 'Chrome*.apk' | head -n1)" "$SCRIPT_DIR/release/aerium-$VERSION-arm64-v8a.apk"
rm -rf $SCRIPT_DIR/keys
echo "$VERSION" > $SCRIPT_DIR/release/version.txt
touch $SCRIPT_DIR/release/finished.marker
echo "[aerium] build finished: release/aerium-$VERSION-arm64-v8a.apk"
