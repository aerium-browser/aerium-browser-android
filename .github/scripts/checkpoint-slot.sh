#!/bin/bash
# Resolve which of the two checkpoint slots to read from or write to.
#
#   checkpoint-slot.sh restore   -> outputs name=<slot holding the newest>
#   checkpoint-slot.sh save      -> outputs target=<slot to write>
#                                           previous_id=<artifact to retire after>
#
# A run cannot hold two artifacts under one name, so saving to a fixed name
# means deleting the old checkpoint before uploading the new one - and being
# interrupted in that window leaves the run with nothing. The Windows repo lost
# five stages of compiling to exactly that on run 33089940410: cancelled eight
# seconds into the upload, moments after the delete.
#
# So the checkpoint alternates between $BASE and $BASE-b. Whoever saves writes
# to the slot that is not current and retires the other only once the upload
# has succeeded, which means there is always at least one complete checkpoint.
#
# Artifact ids increase monotonically, so the largest id is the latest upload.
# That is what makes "which slot is current" answerable without any state of
# our own, and what lets a run written before this scheme - one slot, the base
# name - resolve correctly with no special case.
#
# Environment: GH_TOKEN, BASE, and for restore, optionally RESTORE_RUN_ID.
set -euo pipefail

_mode="${1:?usage: checkpoint-slot.sh restore|save}"
: "${BASE:?BASE must be set}"

_run_id="$GITHUB_RUN_ID"
if [ "$_mode" = restore ] && [ -n "${RESTORE_RUN_ID:-}" ]; then
    _run_id="$RESTORE_RUN_ID"
fi

# Both slots for this run, oldest first. An expired artifact is not a
# checkpoint: downloading it fails, so it must not be picked.
#
# A failure to list is deliberately not fatal. On restore an empty answer
# means "no checkpoint", which the caller already handles (a first stage has
# none); on save it means the first slot is used, and the worst case is an
# upload that collides with an existing name and fails loudly, rather than a
# silent overwrite.
_slots="$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$_run_id/artifacts?per_page=100" \
    --jq "[.artifacts[]
           | select(.expired == false)
           | select(.name == \"$BASE\" or .name == \"$BASE-b\")
           | {name: .name, id: .id}]
          | sort_by(.id)" 2>/dev/null || echo '[]')"
_count="$(jq 'length' <<<"$_slots")"
echo "[checkpoint-slot] run $_run_id has $_count of {$BASE, $BASE-b}" >&2

if [ "$_mode" = restore ]; then
    # The newest, or nothing. The caller skips the download when this is empty.
    _name="$(jq -r '.[-1].name // ""' <<<"$_slots")"
    echo "[checkpoint-slot] restoring from: ${_name:-<none>}" >&2
    echo "name=$_name" >> "$GITHUB_OUTPUT"
    exit 0
fi

if [ "$_count" -eq 0 ]; then
    # Nothing to lose yet.
    _target="$BASE"
    _previous_id=""
elif [ "$_count" -eq 1 ]; then
    _current_name="$(jq -r '.[0].name' <<<"$_slots")"
    _previous_id="$(jq -r '.[0].id' <<<"$_slots")"
    if [ "$_current_name" = "$BASE" ]; then _target="$BASE-b"; else _target="$BASE"; fi
else
    # Both present, which means an earlier stage was interrupted after its
    # upload but before it could retire the older slot. Overwrite the older one
    # and keep the newer as the fallback for this stage's window.
    _target="$(jq -r '.[0].name' <<<"$_slots")"
    _older_id="$(jq -r '.[0].id' <<<"$_slots")"
    _previous_id="$(jq -r '.[1].id' <<<"$_slots")"
    gh api -X DELETE "repos/$GITHUB_REPOSITORY/actions/artifacts/$_older_id" \
        || echo "[checkpoint-slot] could not clear $_target; the upload will say so" >&2
fi

echo "[checkpoint-slot] writing to: $_target (retiring ${_previous_id:-<none>} after)" >&2
echo "target=$_target" >> "$GITHUB_OUTPUT"
echo "previous_id=$_previous_id" >> "$GITHUB_OUTPUT"
