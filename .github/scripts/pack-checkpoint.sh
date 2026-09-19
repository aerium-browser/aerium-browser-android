#!/bin/bash
set -euo pipefail

cd "$GITHUB_WORKSPACE"
if [ -f release/finished.marker ]; then
  echo "packed=finished" >> "$GITHUB_OUTPUT"
elif [ -f chromium/src/BUILD.gn ] && [ -f chromium/src/out/Default/args.gn ] && [ -f chromium/src/out/Default/build.ninja ]; then
  # Save progress even when this stage's build failed, so a fixed
  # workflow can resume instead of starting over. build.ninja is
  # required on top of BUILD.gn/args.gn: a tree where gn gen itself
  # failed (e.g. a bad args.gn flag - run 29985315083) has the first
  # two but no build graph, and uploading it would overwrite the
  # previous GOOD checkpoint (the artifact name is shared across
  # runs with overwrite: true), destroying resumable progress in
  # exchange for a tree that can't be resumed anyway.
  EXTRA=""
  for f in chromium/.gclient_entries chromium/.gclient_previous_sync_commits; do
    [ -f "$f" ] && EXTRA="$EXTRA $f"
  done
  # tar exit code 1 only means files changed while reading - the
  # archive is still usable, which --warning=no-file-changed and the
  # `RC -gt 1` check below already handle.
  #
  # .siso_fs_state.journal must NOT be excluded. It is not volatile
  # scratch: it is siso's incremental record of which steps have
  # completed. build.sh ends every stage with `timeout -s INT`, so
  # siso is always interrupted and never folds the journal into
  # .siso_fs_state - the journal IS the state. Excluding it made
  # every stage start with no incremental knowledge and recompile
  # the same ~28,300 objects, so a 15-stage run finished at the
  # exact 38.1% it reached in stage 1 (remaining went 45,981 ->
  # 46,030). Object files were in the checkpoint all along and were
  # simply rewritten byte-identically.
  #
  # --format=posix is load-bearing, not cosmetic. GNU tar's default
  # "gnu" format stores mtimes as whole seconds, while siso's
  # .siso_fs_state keys every recorded output on its NANOSECOND mtime.
  # A default-format pack/unpack round trip therefore hands the next
  # stage a tree in which every single file's mtime has been rounded
  # down to .000000000, so not one entry in the restored state file
  # matches the file it describes, the whole state is discarded as
  # stale, and the stage recompiles ~30k objects it already has. Only
  # the pax format carries sub-second times (verified with GNU tar
  # 1.35, the version on ubuntu-latest: gnu round-trips
  # 10:11:12.123456789 as 10:11:12.000000000, posix as
  # 10:11:12.123456789). The Unpack step needs no matching flag - tar
  # detects the format when reading.
  #
  # --pax-option pays for it: pax otherwise emits an extended header
  # for every file just to carry atime/ctime, which nothing here
  # restores or cares about. Dropping those two keeps the archive the
  # same size as before for whole-second files and only spends the
  # extra header where a sub-second mtime actually needs preserving.
  #
  # Probed against an empty archive first: a stage that reached this
  # point has ~5 hours of compilation in it, and a tar that refused
  # the flags would abort the pack and throw all of it away. Falling
  # back to the old format merely leaves the incremental state
  # unusable again - the failure we already have - instead of losing
  # the objects too.
  TAR_FMT=(--format=posix --pax-option='delete=atime,delete=ctime')
  if ! tar -c "${TAR_FMT[@]}" -f /dev/null --files-from=/dev/null 2>/dev/null; then
    echo "WARNING: this tar rejects the pax flags; packing in the default format"
    TAR_FMT=()
  fi
  set +e
  tar -c -I 'zstd -T0 -3' -f chromium/artifacts.tar.zst \
    "${TAR_FMT[@]}" \
    --warning=no-file-changed \
    --exclude='chromium/artifacts.tar.zst' \
    chromium/src chromium/.gclient $EXTRA
  RC=$?
  set -e
  if [ $RC -gt 1 ]; then
    echo "tar failed with exit code $RC"
    exit $RC
  fi
  ls -la chromium/artifacts.tar.zst
  echo "packed=intermediate" >> "$GITHUB_OUTPUT"
else
  echo "Source setup did not complete; nothing worth saving"
  echo "packed=none" >> "$GITHUB_OUTPUT"
fi
