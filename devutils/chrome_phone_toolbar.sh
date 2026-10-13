#!/bin/bash
# Aerium phone toolbar: Chrome-style Home button, no Extensions button.
# Run from chromium/src. Safe to run on every resumed build stage.
set -euo pipefail

XML="chrome/browser/ui/android/toolbar/java/res/layout/toolbar_phone.xml"
JAVA="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"

if [[ ! -f "$XML" || ! -f "$JAVA" ]]; then
  echo "[aerium-toolbar] FATAL: expected Chromium toolbar files are missing" >&2
  exit 1
fi

# Remove only Aerium's extension-toolbar ViewStub. The extensions feature and
# its menu remain available from the browser menu.
python3 - "$XML" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
pattern = r'\s*<ViewStub\b(?=[^>]*android:id="@\+id/extensions_toolbar_container_stub")[^>]*/>\s*'
new, count = re.subn(pattern, '\n', s, count=1, flags=re.S)
if count:
    p.write_text(new)
elif 'extensions_toolbar_container_stub' in s:
    raise SystemExit('[aerium-toolbar] FATAL: could not safely remove extension toolbar ViewStub')
print('[aerium-toolbar] extension toolbar button removed' if count else '[aerium-toolbar] extension toolbar button already absent')
PY

# Chromium already provides the native HomeButton view and click handling.
# Force it on, while preserving Chromium's native icon, tint, hit target and
# homepage navigation implementation.
python3 - "$JAVA" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = 'onHomeButtonUpdate(HomepageManager.isHomepageEnabled()\n                || FeatureUtilities.isBottomToolbarEnabled());'
new = 'onHomeButtonUpdate(true);'
if old in s:
    s = s.replace(old, new, 1)
elif 'onHomeButtonUpdate(true);' not in s:
    raise SystemExit('[aerium-toolbar] FATAL: Chromium HomeButton initialization changed; refusing an unsafe patch')
p.write_text(s)
print('[aerium-toolbar] native Home button enabled')
PY
