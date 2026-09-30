#!/usr/bin/env python3
import html
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join('tools', 'grit'))

from grit import grd_reader
from grit.node import message

HERE = os.path.dirname(os.path.abspath(__file__))

GRDS = [
    'chrome/browser/ui/android/strings/android_chrome_strings.grd',
    'chrome/app/generated_resources.grd',
]

ALSO = {
    'es': ['es-419'],
    'fr': ['fr-CA'],
    'pt-BR': ['pt-PT'],
    'zh-TW': ['zh-HK'],
}

PLACEHOLDER = re.compile(r'\{([A-Z][A-Z0-9_]*)\}')


def aerium_messages(grd):
    src = open(grd, encoding='utf-8').read()
    blocks = re.findall(
        r'[ \t]*<message name="IDS_AERIUM_[A-Z0-9_]+".*?</message>\n', src, re.S)
    mini = ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<grit latest_public_release="0" current_release="1">'
            '<outputs></outputs><release seq="1">'
            '<messages fallback_to_english="true">\n' + ''.join(blocks) +
            '</messages></release></grit>\n')
    root = grd_reader.Parse(io.StringIO(mini), dir=os.path.dirname(grd))
    found = {}
    for node in root.Preorder():
        if isinstance(node, message.MessageNode):
            m = node.GetCliques()[0].GetMessage()
            found[node.attrs['name']] = (
                m.GetId(), m.GetPresentableContent(),
                {p.GetPresentation() for p in m.GetPlaceholders()})
    xtbs = {
        lang: os.path.join(os.path.dirname(grd), path)
        for path, lang in re.findall(r'<file path="([^"]+\.xtb)" lang="([^"]+)"', src)
    }
    return found, xtbs


def render(text, placeholders):
    names = set(PLACEHOLDER.findall(text))
    if names != placeholders:
        return None
    parts = PLACEHOLDER.split(text)
    out = []
    for i, part in enumerate(parts):
        out.append('<ph name="%s" />' % part if i % 2 else html.escape(part, quote=False))
    return ''.join(out)


def main():
    english = json.load(open(os.path.join(HERE, 'en.json'), encoding='utf-8'))
    languages = sorted(
        f[:-5] for f in os.listdir(HERE) if f.endswith('.json') and f != 'en.json')
    written = stale = files = 0
    for grd in GRDS:
        found, xtbs = aerium_messages(grd)
        for lang in languages:
            translations = json.load(open(os.path.join(HERE, lang + '.json'), encoding='utf-8'))
            for locale in [lang] + ALSO.get(lang, []):
                xtb = xtbs.get(locale)
                if not xtb or not os.path.exists(xtb):
                    continue
                bundle = open(xtb, encoding='utf-8').read()
                present = set(re.findall(r'<translation id="(\d+)"', bundle))
                lines = []
                for name, (msg_id, presentable, placeholders) in sorted(found.items()):
                    text = translations.get(name)
                    if text is None or msg_id in present:
                        continue
                    if english.get(name) != presentable:
                        stale += 1
                        continue
                    rendered = render(text, placeholders)
                    if rendered is None:
                        print('[aerium] FATAL: placeholders in %s for %s do not match the English'
                              % (lang, name), file=sys.stderr)
                        return 1
                    lines.append('<translation id="%s">%s</translation>\n' % (msg_id, rendered))
                    present.add(msg_id)
                if not lines:
                    continue
                if '</translationbundle>' not in bundle:
                    print('[aerium] FATAL: no </translationbundle> in ' + xtb, file=sys.stderr)
                    return 1
                bundle = bundle.replace('</translationbundle>', ''.join(lines) + '</translationbundle>', 1)
                open(xtb, 'w', encoding='utf-8').write(bundle)
                written += len(lines)
                files += 1
    print('[aerium] translations: %d strings into %d files, %d skipped as out of date'
          % (written, files, stale))
    return 0


if __name__ == '__main__':
    sys.exit(main())
