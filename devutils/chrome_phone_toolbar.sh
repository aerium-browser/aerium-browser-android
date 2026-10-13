#!/bin/bash
# Aerium phone toolbar: native Home button, no separate Extensions toolbar stub.
# Run from chromium/src. Safe to run on every resumed build stage.
set -euo pipefail

XML="chrome/browser/ui/android/toolbar/java/res/layout/toolbar_phone.xml"
JAVA="chrome/browser/ui/android/toolbar/java/src/org/chromium/chrome/browser/toolbar/top/ToolbarPhone.java"

if [[ ! -f "$XML" || ! -f "$JAVA" ]]; then
  echo "[aerium-toolbar] FATAL: expected Chromium toolbar files are missing" >&2
  exit 1
fi

# Remove an explicit Extensions ViewStub if this Chromium revision has one.
# Chromium 152 uses optional_button_stub instead; that is a generic feature
# slot and must NOT be removed because it can host unrelated toolbar buttons.
python3 - "$XML" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
pattern = r'\s*<ViewStub\b(?=[^>]*android:id="@\+id/extensions_toolbar_container_stub")[^>]*/>\s*'
new, count = re.subn(pattern, '\\n', s, count=1, flags=re.S)
if count:
    p.write_text(new)
    print('[aerium-toolbar] explicit Extensions toolbar stub removed')
elif 'extensions_toolbar_container_stub' in s:
    raise SystemExit('[aerium-toolbar] FATAL: found Extensions stub ID but could not safely remove its ViewStub')
else:
    # Current Chromium layouts do not declare this ID. Do not fail the build
    # just because the upstream toolbar implementation uses another layout.
    print('[aerium-toolbar] no explicit Extensions toolbar stub in this Chromium revision; leaving generic optional button untouched')
PY

# Chromium 152 exposes onHomeButtonIsEnabledUpdate(boolean), not the older
# onHomeButtonUpdate(...) call. Force the native Home button on at the point
# where Chromium records its enabled state, preserving native click handling.
python3 - "$JAVA" <<'PY'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = 'mIsHomeButtonEnabled = homeButtonEnabled;'
new = 'mIsHomeButtonEnabled = true;'
count = s.count(old)
if count == 1:
    s = s.replace(old, new, 1)
    p.write_text(s)
elif count == 0 and re.search(r'mIsHomeButtonEnabled\s*=\s*true\s*;', s):
    print('[aerium-toolbar] native Home button already forced on')
else:
    raise SystemExit(f'[aerium-toolbar] FATAL: expected exactly one home-button enabled-state assignment, found {count}')
print('[aerium-toolbar] native Home button enabled')
PY
