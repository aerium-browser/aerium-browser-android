#!/bin/bash
# Copyright 2026 Dioide
# SPDX-License-Identifier: GPL-3.0-only

set -e
source lib.sh

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
CHECKPOINT_RESERVE_MIN=${CHECKPOINT_RESERVE_MIN:-60}
TOTAL_BUDGET_MIN=${TOTAL_BUDGET_MIN:-$((JOB_TIMEOUT_MIN - CHECKPOINT_RESERVE_MIN))}
START_TS=${STAGE_START_TS:-$(date +%s)}

export VERSION=$(tr -d '[:space:]' < chromium.pin)

# --- target architecture ------------------------------------------------------
# arm64 unless the workflow says otherwise. Everything that varies with the
# architecture is derived here, in one place, so a second workflow only has to
# set AERIUM_TARGET_CPU and nothing downstream needs a second opinion:
#
#   target_cpu    what args.gn is rewritten to say
#   ABI           what Android calls the same thing, and what goes in the APK
#                 filename - it is the name people match against their device,
#                 not the GN spelling
#
# x86 (32-bit) is deliberately absent. Android dropped it for new devices years
# ago and the only things left running it are old emulator images; adding a
# third build to the queue for those is not a trade worth making.
export AERIUM_TARGET_CPU="${AERIUM_TARGET_CPU:-arm64}"
case "$AERIUM_TARGET_CPU" in
    arm64) export AERIUM_ABI=arm64-v8a ;;
    x64)   export AERIUM_ABI=x86_64 ;;
    *)
        echo "[aerium] FATAL: AERIUM_TARGET_CPU=$AERIUM_TARGET_CPU is not one of arm64, x64" >&2
        exit 1
        ;;
esac
echo "[aerium] target cpu: $AERIUM_TARGET_CPU  abi: $AERIUM_ABI"
export CHROMIUM_SOURCE=https://chromium.googlesource.com/chromium/src.git
export DEBIAN_FRONTEND=noninteractive
echo "[aerium] chromium version: $VERSION  ci: $MODE_CI"

# --- stage diagnostics --------------------------------------------------------
# The CI job log can only be read from its tail (~400 KB, i.e. the last couple
# of minutes of a five-hour job), so anything printed near the START of a stage
# is unreadable in practice. Everything worth knowing is therefore appended to
# this file as it happens and dumped by a step at the very END of the job.
# The stage action seeds the same path before the build starts.
STAGE_DIAG="${STAGE_DIAG:-$SCRIPT_DIR/stage-diag.txt}"
# Full build output, kept so the end-of-job dump can show its FIRST lines -
# that is where the backend says whether it loaded the restored incremental
# state. Deliberately named without "siso" in it: the straggler kill below
# matches processes on that string and must not shoot this file's writer.
BUILD_LOG="${BUILD_LOG:-$SCRIPT_DIR/chromium/build_stdout.log}"

# Keep the big tool caches on the large build mount (chromium/) instead of the
# small root filesystem: vpython venvs alone are multiple GB and overflow the
# CI runner's root disk otherwise. Not part of the stage artifact; they are
# recreated cheaply on each stage.
mkdir -p chromium/.vpython-root chromium/.cipd-cache chromium/.tmp chromium/.cache
export VPYTHON_VIRTUALENV_ROOT="$SCRIPT_DIR/chromium/.vpython-root"
export CIPD_CACHE_DIR="$SCRIPT_DIR/chromium/.cipd-cache"
export TMPDIR="$SCRIPT_DIR/chromium/.tmp"
export XDG_CACHE_HOME="$SCRIPT_DIR/chromium/.cache"

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
    for attempt in 1 2 3 4 5; do
        git fetch --depth 1 $CHROMIUM_SOURCE +refs/tags/$VERSION:chromium_$VERSION && break
        [ "$attempt" = 5 ] && exit 1
        echo "[aerium] chromium fetch failed (attempt $attempt), retrying in $((attempt * 30))s"
        sleep $((attempt * 30))
    done
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

    gclient sync -D --no-history --nohooks
    gclient runhooks
    rm -rf third_party/angle/third_party/VK-GL-CTS/

    ./build/install-build-deps.sh --no-prompt
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*

    source $SCRIPT_DIR/apply.sh
    if [ -n "${AERIUM_UI_DIR:-}" ]; then
        source "$AERIUM_UI_DIR/engine/apply.sh"
    fi

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
    # The checked-in args.gn names arm64. Rewritten rather than kept in two
    # files so that every other argument - and there are thirty of them - stays
    # in one place and cannot drift between architectures.
    sed -i "s|^target_cpu = .*|target_cpu = \"$AERIUM_TARGET_CPU\"|" out/Default/args.gn
    grep -q "^target_cpu = \"$AERIUM_TARGET_CPU\"$" out/Default/args.gn || {
        echo "[aerium] FATAL: target_cpu was not set in out/Default/args.gn" >&2
        exit 1
    }
    if [ -n "${AERIUM_UI_DIR:-}" ] && [ -f "$AERIUM_UI_DIR/engine/args.gn" ]; then
        while IFS= read -r aerium_arg; do
            case "$aerium_arg" in ''|'#'*) continue ;; esac
            sed -i "/^${aerium_arg%% =*} = /d" out/Default/args.gn
            echo "$aerium_arg" >> out/Default/args.gn
        done < "$AERIUM_UI_DIR/engine/args.gn"
    fi
    if [ -n "${AERIUM_UI_DIR:-}" ]; then
        gn gen out/Default > "$SCRIPT_DIR/gn_gen.log" 2>&1 || {
            echo "[aerium] FATAL: gn gen failed, the log is in the encrypted failure marker" >&2
            exit 1
        }
        echo "[aerium] gn gen done"
    else
        gn gen out/Default
    fi

    # Nothing past this point runs git against chromium/src (no later stage
    # calls gclient/git - only ninja), so its history is dead weight. This
    # is a modest, low-risk reclaim; it does not touch out/Default or any
    # third_party checkout the build actually depends on.
    rm -rf .git

    cd $SCRIPT_DIR
fi

cd chromium/src


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
    # in-flight compiler jobs directly. -k is a backstop for any single
    # translation unit that's slow to unwind; it was 10m, which together
    # with the graceful wait below could push the stage past its 350-min
    # job timeout, and 5m is already far more than an interrupted compile
    # needs.
    # The `|| true` is not decoration: this runs under `set -e`, and a
    # pipeline's status is tee's, so an unwritable diagnostics file would
    # otherwise abort the stage before it compiled anything.
    { set +e
      echo "=== [$(date -u '+%H:%M:%SZ')] PRE-BUILD incremental state ==="
      ls -la out/Default/.siso_fs_state out/Default/.siso_fs_state.journal 2>&1
      if [ -f out/Default/.aerium_low_disk ]; then
          echo "=== LOW DISK REPORT CARRIED OVER FROM THE PREVIOUS STAGE ==="
          cat out/Default/.aerium_low_disk
          echo "=== end carried-over report ==="
          rm -f out/Default/.aerium_low_disk
      fi
    } 2>&1 | tee -a "$STAGE_DIAG" || true

    # If the log is not creatable, send it to /dev/null rather than leaving
    # tee to die on its first write: tee holds the read end of autoninja's
    # stdout pipe, so a dead tee means SIGPIPE straight into the compiler.
    : > "$BUILD_LOG" 2>/dev/null || BUILD_LOG=/dev/null

    AERIUM_BUILD_SHELL_PID=$$

    aerium_root_avail_mb() {
        _v=$(df -BM --output=avail / 2>/dev/null | tail -1 | tr -d ' ')
        _v=${_v%M}
        case "$_v" in
            ''|*[!0-9]*) echo -1 ;;
            *) echo "$_v" ;;
        esac
    }

    aerium_reclaim_root() {
        sudo apt-get clean >/dev/null 2>&1 || true
        sudo rm -rf /var/cache/apt/archives/*.deb >/dev/null 2>&1 || true
        sudo journalctl --vacuum-size=10M >/dev/null 2>&1 || true
        sudo rm -rf /opt/hostedtoolcache >/dev/null 2>&1 || true
    }

    aerium_sample_resources() {
        _reclaimed=0
        _stopped=0
        while :; do
            _root_m=$(aerium_root_avail_mb)
            _root_avail="${_root_m}M"

            if [ "$_root_m" -ge 0 ] && [ "$_root_m" -lt 4096 ] \
               && [ "$_reclaimed" = 0 ]; then
                _reclaimed=1
                printf '[aerium] root down to %s - reclaiming\n' "$_root_avail" || true
                aerium_reclaim_root
                _root_m=$(aerium_root_avail_mb)
                _root_avail="${_root_m}M"
                printf '[aerium] root after reclaim: %s\n' "$_root_avail" || true
            fi

            if [ "$_root_m" -ge 0 ] && [ "$_root_m" -lt 2048 ] \
               && [ "$_stopped" = 0 ]; then
                _stopped=1
                mkdir -p out/Default >/dev/null 2>&1 || true
                {
                    printf 'The previous stage stopped itself early.\n'
                    printf 'Root filesystem was down to %s at %s.\n' \
                        "$_root_avail" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
                    printf 'The runner agent is killed when root reaches zero, and\n'
                    printf 'a killed runner uploads no log, so the build was\n'
                    printf 'interrupted to force a checkpoint while that was still\n'
                    printf 'possible. Largest consumers of / at that moment:\n'
                    du -xhd1 / 2>/dev/null | sort -rh | head -12
                } > out/Default/.aerium_low_disk 2>/dev/null || true
                printf '[aerium] WARNING root at %s - interrupting the build so this stage checkpoints instead of being killed\n' \
                    "$_root_avail" || true
                pkill -INT -P "$AERIUM_BUILD_SHELL_PID" -x timeout >/dev/null 2>&1 || true
            fi

            if [ -n "${AERIUM_UI_DIR:-}" ]; then
                printf '[aerium] progress %s\n' \
                    "$(tail -c 8192 "$BUILD_LOG" 2>/dev/null | grep -aoE '\[[0-9]+/[0-9]+\]' | tail -n 1)" || true
            fi
            printf '[aerium] res %s root_avail=%s build_avail=%s mem_avail=%s swap_free=%s\n' \
                "$(date -u +%H:%M:%S)" \
                "$_root_avail" \
                "$(df -BM --output=avail "$SCRIPT_DIR/chromium" 2>/dev/null | tail -1 | tr -d ' ')" \
                "$(awk '/^MemAvailable:/{printf "%dM", $2/1024}' /proc/meminfo)" \
                "$(awk '/^SwapFree:/{printf "%dM", $2/1024}' /proc/meminfo)"
            sleep 120
        done
    }
    aerium_sample_resources &
    AERIUM_RES_PID=$!

    set +e
    # Output goes through a process substitution rather than a plain `|
    # tee` on purpose: a pipe would make the shell block until every
    # process holding the write end has exited, which is unbounded if the
    # backend hangs. With >(...) the exit status below is still timeout's
    # own and the wait stays bounded by the loop that follows.
    if [ -n "${AERIUM_UI_DIR:-}" ]; then
        timeout -s INT -k 5m ${REMAINING_MIN}m \
            autoninja -j "${NINJA_JOBS:-2}" -k "${NINJA_KEEP_GOING:-0}" \
            -C out/Default chrome_public_apk \
            >> "$BUILD_LOG" 2>&1
        RET=$?
    else
        timeout -s INT -k 5m ${REMAINING_MIN}m \
            autoninja -j "${NINJA_JOBS:-2}" -k "${NINJA_KEEP_GOING:-0}" \
            -C out/Default chrome_public_apk \
            > >(tee -a "$BUILD_LOG") 2>&1
        RET=$?
    fi
    set -e
    kill "$AERIUM_RES_PID" 2>/dev/null || true
    wait "$AERIUM_RES_PID" 2>/dev/null || true

    # Let the build backend finish its own shutdown before force-killing
    # anything.
    #
    # `timeout` returns as soon as its DIRECT child exits - verified: with a
    # child that dies on SIGINT while a grandchild lives on, timeout returns
    # 124 immediately and the grandchild keeps running. Here the direct child
    # is the autoninja wrapper and the grandchild is siso, so the old
    # `pkill -9 -f siso` on the very next line could be landing while siso is
    # still unwinding.
    #
    # That matters because the tail end of that unwind is where siso writes
    # out/Default/.siso_fs_state - the record of which command produced which
    # output, and therefore the ONLY thing that lets the next stage skip work
    # it has already done. The object files themselves carry no such marker,
    # which is why every stage has been rewriting the same ~28,300 objects
    # byte-identically. Whether the SIGKILL really was landing mid-write is
    # what the end-of-job diagnostics settle: a checkpoint carrying a large
    # .siso_fs_state and no journal means siso now shuts down cleanly.
    #
    # Bounded at 4 minutes: writing the state takes seconds, and the stage
    # still has to pack and upload ~20 GB inside the job timeout.
    #
    # Matched on the process NAME, not on `pgrep -f siso`: -f tests the whole
    # command line, which also matches any shell whose arguments merely
    # mention siso, and a false positive here burns the full four minutes of
    # a stage's budget waiting for a process that was never the build.
    siso_alive() {
        pgrep -x siso >/dev/null 2>&1 || pgrep -f '(^|/)siso ninja' >/dev/null 2>&1
    }
    for _ in $(seq 1 120); do
        siso_alive || break
        sleep 2
    done
    # Anything still alive after that is a straggler that would keep writing
    # to the tree while the stage action packs it into the resume artifact.
    pkill -9 -f 'siso' 2>/dev/null || true
    sleep 3

    { set +e
      echo "=== [$(date -u '+%H:%M:%SZ')] POST-BUILD incremental state (autoninja rc=$RET) ==="
      ls -la out/Default/.siso_fs_state out/Default/.siso_fs_state.journal 2>&1
      echo "--- every siso/ninja entry in out/Default ---"
      ls -la out/Default 2>/dev/null | grep -i 'siso\|ninja'
    } 2>&1 | tee -a "$STAGE_DIAG" || true
    if [ $RET = 124 ]; then
        echo "[aerium] time budget reached; build will resume on the next stage"
        exit 0
    elif [ $RET != 0 ]; then
        echo "[aerium] build failed with exit code $RET"
        # siso (the build backend modern Chromium uses in place of
        # plain ninja) does not echo a failing command's own output to
        # stdout - it only prints "see ./out/Default/siso_output for full
        # command line and output" and leaves it at that. Without this dump,
        # every CI failure was a black box that could only be diagnosed by
        # downloading the multi-GB resume artifact and looking inside it.
        if [ -f out/Default/siso_output ]; then
            echo "[aerium] --- tail of out/Default/siso_output (last 200 lines) ---"
            if [ -n "${AERIUM_UI_DIR:-}" ]; then
                echo "[aerium] $(grep -cE ': (fatal )?error:' out/Default/siso_output) compile errors, the details are in the encrypted failure marker"
            else
                tail -n 200 out/Default/siso_output || true
            fi
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
UNSIGNED_APK="$(find out/Default/apks -name 'Chrome*.apk' | head -n1)"
APK_BASE=${AERIUM_APK_BASE:-aerium-core}
sign_apk "$UNSIGNED_APK" "$SCRIPT_DIR/release/$APK_BASE-$VERSION-$AERIUM_ABI.apk"
rm -rf $SCRIPT_DIR/keys

# --- Archive what a native crash report needs to symbolise (issue #11).
#
# Every native crash report this project has received so far is offsets with
# no names: args.gn sets symbol_level = 0, and R8 renames every Java class and
# method in a release build. That cost real diagnosis time on issue #11 - the
# first report was readable only because its poison-byte fault address
# happened to spell out the bug by itself, and the second report is a stack of
# single- and double-letter class names (fo6.onAnimationEnd, co6.d, yn6.a...)
# that nothing here can currently map back to source.
#
# Neither artifact goes in the public release. They ride along in the
# existing aerium-android-<arch> workflow artifact instead (30-day retention,
# set in the stage action) - the mapping is only useful with a matching crash
# report anyway, and the unstripped library would roughly double the size of
# what most people are here to download.
#
# The mapping file's name comes from GN's own rule
# (proguard_mapping_path = "$_final_apk_path.mapping" in
# build/config/android/rules.gni), so it always sits next to the unsigned
# apk under whatever name upstream gave it - it is not renamed by sign_apk,
# which only ever writes its signed copy elsewhere.
if [ -f "$UNSIGNED_APK.mapping" ]; then
    cp "$UNSIGNED_APK.mapping" "$SCRIPT_DIR/release/$APK_BASE-$VERSION-$AERIUM_ABI.apk.mapping"
    echo "[aerium] archived R8 mapping: release/$APK_BASE-$VERSION-$AERIUM_ABI.apk.mapping"
else
    echo "[aerium] no R8 mapping next to $UNSIGNED_APK - crash reports for this build will stay unsymbolised"
fi

# lib.unstripped/ is where GN's shared_library template keeps the pre-strip
# copy (build/config/android/rules.gni), named the same as the stripped one
# that ends up inside the APK. Compressed because an unstripped libchrome.so
# keeps its full ELF symbol table and is multiple hundred MB uncompressed;
# -9 rather than the checkpoint tar's -3 because this runs once per finished
# build rather than once per stage, so there is time to spend on it.
UNSTRIPPED_LIB=out/Default/lib.unstripped/libchrome.so
if [ -f "$UNSTRIPPED_LIB" ]; then
    zstd -T0 -9 -q -f -o "$SCRIPT_DIR/release/$APK_BASE-$VERSION-$AERIUM_ABI-libchrome.so.zst" "$UNSTRIPPED_LIB"
    echo "[aerium] archived unstripped libchrome.so: release/$APK_BASE-$VERSION-$AERIUM_ABI-libchrome.so.zst"
else
    echo "[aerium] no unstripped libchrome.so found at $UNSTRIPPED_LIB"
fi

echo "$VERSION" > $SCRIPT_DIR/release/version.txt
touch $SCRIPT_DIR/release/finished.marker
echo "[aerium] build finished: release/$APK_BASE-$VERSION-$AERIUM_ABI.apk"
