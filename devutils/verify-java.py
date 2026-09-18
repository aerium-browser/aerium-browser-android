#!/usr/bin/env python3
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = (ROOT / 'theme.sh').read_text()
PATCH = (ROOT / 'patch.sh').read_text()
BOTH = THEME + '\n' + PATCH

INHERITED = {
    'findPreference', 'getActivity', 'getContext', 'getString', 'getProfile',
    'getPreferenceManager', 'startActivityForResult', 'getArguments',
    'requireContext', 'requireActivity', 'getResources', 'getView',
}
AMBIENT = {'TRUE', 'FALSE', 'NULL', 'MAX_VALUE', 'MIN_VALUE', 'UTF_8'}

findings = []


def report(where, kind, detail):
    findings.append((where, kind, detail))


def heredocs(suffix):
    lines = THEME.split('\n')
    i = 0
    while i < len(lines):
        m = re.match(r"^cat > (\S+%s) <<'(\w+)'$" % re.escape(suffix), lines[i])
        if m:
            path, delim = m.groups()
            body, j = [], i + 1
            while j < len(lines) and lines[j] != delim:
                body.append(lines[j])
                j += 1
            if j >= len(lines):
                report(path, 'UNTERMINATED-HEREDOC', delim)
                return
            yield path, '\n'.join(body) + '\n'
            i = j
        i += 1


def denoise(t):
    t = re.sub(r'"(?:\\.|[^"\\])*"', '""', t)
    t = re.sub(r"'(?:\\.|[^'\\])'", "' '", t)
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'(?m)//.*$', '', t)


def check_java(path, raw):
    name = os.path.basename(path)
    t = denoise(raw)

    for a, b in (('{', '}'), ('(', ')'), ('[', ']')):
        if t.count(a) != t.count(b):
            report(name, 'UNBALANCED', '%s%s  %d vs %d' % (a, b, t.count(a), t.count(b)))

    pkg = re.search(r'^package\s+([\w.]+);', t, re.M)
    expected = path.split('/src/')[1].rsplit('/', 1)[0].replace('/', '.')
    if not pkg:
        report(name, 'NO-PACKAGE', 'expected %s' % expected)
    elif pkg.group(1) != expected:
        report(name, 'PACKAGE-MISMATCH', '%s but path implies %s' % (pkg.group(1), expected))

    declared = set(re.findall(
        r'\b(?:static\s+final|final\s+static)\s+[\w<>\[\],.\s]+?\b([A-Z][A-Z0-9_]{2,})\s*[=;]', t))
    declared |= set(re.findall(r'\b([A-Z][A-Z0-9_]{2,})\s*\(', t))
    imported = set(re.findall(r'^import\s+(?:static\s+)?[\w.]*?\.(\w+);', t, re.M))
    used = {m.group(1) for m in re.finditer(r'(?<![\w.])([A-Z][A-Z0-9_]{2,})\b', t)
            if t[m.end():m.end() + 1] != '.'}
    for u in sorted(used - declared - imported - AMBIENT):
        report(name, 'UNDECLARED-CONSTANT', '%s (line %d)' % (u, line_of(raw, u)))

    fields = set(re.findall(
        r'(?:private|protected|public|final|static|\s)+[\w<>\[\],.?\s]+?\b(m[A-Z]\w*)\s*(?:=|;)', t))
    for u in sorted({m for m in re.findall(r'(?<![\w.])(m[A-Z]\w*)\b', t)} - fields):
        report(name, 'UNDECLARED-FIELD', '%s (line %d)' % (u, line_of(raw, u)))


def line_of(raw, sym):
    for i, l in enumerate(raw.split('\n')):
        if re.search(r'(?<![\w.])' + re.escape(sym) + r'\b', l):
            return i + 1
    return 0


def check_xml(path, raw):
    name = os.path.basename(path)
    try:
        ET.fromstring(raw)
    except ET.ParseError as e:
        report(name, 'MALFORMED-XML', str(e))
        return
    keys = re.findall(r'android:key="([^"]+)"', raw)
    for k in sorted({k for k in keys if keys.count(k) > 1}):
        report(name, 'DUPLICATE-KEY', k)


def check_resources(java_classes):
    declared = set(re.findall(r'<message name="(IDS_AERIUM_[A-Z0-9_]+)"', BOTH))
    used = set(re.findall(r'\bR\.string\.(aerium_[a-z0-9_]+)', BOTH))
    used |= set(re.findall(r'@string/(aerium_[a-z0-9_]+)', BOTH))
    for s in sorted(used):
        if 'IDS_' + s.upper() not in declared:
            report('strings', 'MISSING-STRING', 'R.string.%s has no <message>' % s)
    for d in sorted(declared):
        if d[4:].lower() not in used:
            report('strings', 'UNUSED-STRING', d)

    keys_declared = set(re.findall(r'\b(AERIUM_[A-Z0-9_]+)\s*=', BOTH))
    for k in sorted(set(re.findall(r'ChromePreferenceKeys\.(AERIUM_[A-Z0-9_]+)', BOTH))):
        if k not in keys_declared:
            report('prefkeys', 'MISSING-PREF-KEY', k)

    for frag in sorted(set(re.findall(r'android:fragment=\\?"([\w.]*Aerium\w+)', BOTH))):
        if frag.rsplit('.', 1)[1] not in java_classes:
            report('fragments', 'MISSING-FRAGMENT-CLASS', frag)


def main():
    java_classes = set()
    for path, body in heredocs('.java'):
        java_classes.add(os.path.basename(path)[:-5])
        check_java(path, body)
    for path, body in heredocs('.xml'):
        check_xml(path, body)
    for f in sorted((ROOT / 'res').rglob('*.xml')):
        check_xml(str(f), f.read_text())
    check_resources(java_classes)

    print('[verify-java] %d Java class(es) checked' % len(java_classes))
    for where, kind, detail in findings:
        print('%-22s %-32s %s' % (kind, where, detail))
    print('[verify-java] %d finding(s)' % len(findings))
    return 1 if findings else 0


if __name__ == '__main__':
    sys.exit(main())
