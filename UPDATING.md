# Updating Aerium (Android)

How to move Aerium onto a newer Chromium/Vanadium release when the
**Upstream watch** workflow's weekly run goes red (this repo has Issues
disabled, so it reports via a failed run + job summary, not a tracking
issue - see the workflow file for why).

## Where things live

- **Base**: `vanadium` submodule (GrapheneOS Vanadium) + upstream
  `jqssun/android-helium-browser` scripts. Chromium version is derived
  from `vanadium/args.gn`.
- **Our changes**: `build.sh` (staged CI build), `theme.sh` (rename,
  privacy/battery-efficiency defaults, platform autofill, search-engine
  defaults, fingerprint-protection parity — visual theming is left
  stock), `patch.sh` (extension/UX seds — kept in sync with upstream),
  `res/` (Aerium icons), `args.gn`, the staged workflow under `.github/`.

## Sync procedure

> ⚠️ Upstream **force-pushes** its `main`. Never `git merge upstream/main`
> after the first time — the history is rewritten. Cherry-pick instead.

1. `git fetch upstream`
2. Diff the scripts that upstream owns:
   ```
   git diff HEAD upstream/main -- patch.sh common.sh args.gn
   ```
3. Port **only** the new lines into our copies by hand:
   - New `patch.sh` sed blocks → paste into our `patch.sh`, keeping our
     `helium`→`aerium` path renames (`aerium/android_config/...`,
     `AeriumConfParser.java`, etc.).
   - Ignore upstream changes to `res/icon.sh`, `res/icon.svg`,
     `build.sh`, `.github/` — those are fully replaced by our versions.
4. Bump the base: `git -C vanadium fetch --tags && git -C vanadium checkout <newtag>`
   then `git add vanadium`.
5. `bash -n build.sh patch.sh theme.sh common.sh` (syntax check).
6. **`devutils/verify-seds.sh`** — do not skip this. It runs the real
   `patch.sh`/`theme.sh` against a sparse tree of files fetched straight
   from `chromium.googlesource.com` at the new tag and reports every
   substitution that matched nothing. `sed -i` exits 0 when its pattern
   stops matching, so without this check a bump silently drops Aerium
   changes and the build still goes green with the behaviour missing.
   Read the script's header for how to interpret `NOOP` vs `MISSING` —
   a `NOOP` on a line that a Vanadium patch *adds* is expected, since the
   baseline is pristine Chromium; cross-check with
   `grep -r '<pattern>' vanadium/patches`.
7. Commit, then dispatch **Build** with `fresh: true` (the saved tree is
   for the old version and must be discarded).
8. When green, the `publish-release` job tags `v<version>` automatically.

## Why stages die with no log

A stage whose job shows a step stuck at `in_progress`, conclusion
`failure`, and whose log 404s was not a compile error — the runner itself
went away, so nothing was ever uploaded. Two causes, both addressed:

- **The job hit its 350-minute `timeout-minutes`.** The checkpoint is
  ~20 GB compressed; restoring it happens *before* `build.sh` runs, and
  packing plus uploading happens after. `build.sh` now measures its
  compile window from `STAGE_START_TS` (exported by the stage action
  before the restore step) rather than from its own start, and reserves
  `CHECKPOINT_RESERVE_MIN` (80) for the pack/upload tail. That reserve
  self-corrects as the checkpoint grows; raise it if stages start dying
  during "Pack build tree".
- **The root filesystem filled.** `maximize-build-space` leaves only a
  ~10 GB root reserve, and the 6 GB swap file is carved out of it. Every
  stage runs `apt-get install` and `install-build-deps.sh` on a fresh
  runner, and `depot_tools` plus its bootstrapped payload is over a GB.
  `depot_tools` now lives on the build mount (`chromium/depot_tools`,
  outside `chromium/src` so the checkpoint never picks it up) and the apt
  cache is cleaned after every install, not just during first-stage setup.

If stages still die, check the `df -h` output that each stage prints
before and after the build step before assuming a compile problem.
8. Update `.github/.upstream-seen` to the commit SHA reported in the
   watcher's job summary - the workflow keeps failing every Monday on
   that same commit until this file is updated, it does not clear
   itself.

## When a patch fails to apply

A bumped Chromium often moves code a `patch.sh` sed targets, so the sed
silently no-ops or `git am` (Vanadium patches) rejects.

- **Vanadium `git am` reject** (stage 1 fails fast): the offending patch
  is named in the log. Check whether Vanadium upstream already updated it
  for the new Chromium — usually bumping the submodule to a tag that
  matches the Chromium version fixes it.
- **Our `patch.sh` sed no-op** (compile error later, e.g. an expected
  symbol missing): grep the new Chromium source for the changed line and
  update the sed's match text.
- **Search-engine block in `theme.sh`**: targets
  `third_party/search_engines_data/resources/definitions/*.json` — a
  DEPS-pulled subproject that only exists after `gclient sync`, which is
  why the block lives in `theme.sh` (runs post-sync) and not in a
  `git am` patch (those run pre-sync). Its fallback-ID sed matches both
  `google.id` and `duckduckgo.id` because Vanadium's patch 0116 already
  retargets the stock lookup — if Vanadium drops or renames 0116 this
  still works. Our engine IDs start at 1001 so upstream additions can
  never collide; if upstream raises `kCurrentDataVersion` past 250,
  raise ours above it again.
- **Fingerprint-protection block in `theme.sh`**: touches
  `runtime_enabled_features.json5` (new `status: "stable"` entries -
  no flag or command-line switch needed, unlike Windows's
  ungoogled-chromium/bromite flags which need `components/ungoogled`,
  absent on Vanadium) plus `document.cc/.h`, `element.cc`, `range.cc`,
  `text_metrics.cc/.h`, `base_rendering_context_2d.cc` (two call
  sites - measureText and getImageData), `static_bitmap_image.cc/.h`,
  `image_encoder.cc`, `platform/BUILD.gn` (one `include_dirs` entry for
  `third_party/skia/include/private`), and `blink/common/features.cc`/
  `public/common/features.h` (new `kSpoofWebGLInfo` BASE_FEATURE,
  self-contained - no `components/ungoogled` dep needed since there's
  no command-line delivery, just a compile-time default). If a sed
  no-ops, the anchor line moved; re-derive it from the *pristine*
  Chromium source at the new tag (not from Windows's patches, which are
  diffed against a different intermediate state) - `git diff` against a
  fresh checkout of the new tag's `third_party/blink/...` files is the
  fastest way to spot what shifted.

## Seeded incremental builds (planned)

A minor Chromium bump changes ~10% of files, so recompiling from scratch
(9–12 stages) is wasteful in principle. The **within-run resume** already
implemented (zstd build-tree artifact handed between stages, restored on
re-dispatch) covers the common case: a failed/timed-out build continues
instead of restarting.

Cross-*version* seeding (reuse the previous version's compiled tree when
bumping Chromium) is **not yet wired up** — it requires checking a new
Chromium tag out over a tree that carries Vanadium's `git am` commits and
already-applied `patch.sh`/`theme.sh` edits, which is fiddly to get right
and must be validated against a real bump. Until then, bump builds use
`fresh: true` and rebuild from scratch. Track this in the roadmap.
