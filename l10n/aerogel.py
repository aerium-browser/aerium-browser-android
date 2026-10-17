#!/usr/bin/env python3
import io
import os
import re
import sys

sys.path.insert(0, os.path.join('tools', 'grit'))

from grit import grd_reader
from grit.node import message

TARGETS = [
    ('chrome/browser/ui/android/strings/android_chrome_strings.grd',
     ['chrome/browser/ui/android/strings/android_chrome_strings.grd']),
    ('components/browser_ui/strings/android/browser_ui_strings.grd',
     ['components/browser_ui/strings/android/browser_ui_strings.grd']),
    ('chrome/android/features/tab_ui/java/strings/android_chrome_tab_ui_strings.grd',
     ['chrome/android/features/tab_ui/java/strings/android_chrome_tab_ui_strings.grd']),
    ('components/components_strings.grd',
     ['components/new_or_sad_tab_strings.grdp']),
    ('chrome/app/generated_resources.grd',
     ['chrome/app/extensions_strings.grdp']),
]

ENGLISH = [
    (r'You’ve gone Incognito', 'You’re in Aerogel'),
    (r"You've gone Incognito", "You're in Aerogel"),
    (r'Going Incognito doesn’t', 'Aerogel doesn’t'),
    (r"Going Incognito doesn't", "Aerogel doesn't"),
    (r'Open in Incognito (?:Aerium|Chrome|Chromium)(?: tab)?', 'Open in Aerogel tab'),
    (r'(?:Aerium|Chrome|Chromium) Incognito', 'Aerogel tabs'),
    (r'Locked Incognito mode', 'Locked Aerogel tabs'),
    (r'Incognito is not available', 'Aerogel tabs are not available'),
    (r'\bIncognito\b', 'Aerogel'),
    (r'\bincognito\b', 'Aerogel'),
]

CJK = r'[぀-ヿ㐀-鿿豈-﫿]'

LOCAL = {
    'de': [(r'Inkognito([a-zäöüß])', lambda m: 'Aerogel-' + m.group(1).upper()),
           (r'\b[Ii]nkognito\b', 'Aerogel')],
    'es': [(r'\b[Ii]ncógnito\b', 'Aerogel')],
    'fr': [(r'\b([Oo]nglets?|[Ff]enêtres?|[Ss]essions?|[Hh]istorique) (?:de )?navigation privée', r'\1 Aerogel'),
           (r'\b([Mm]ode) (?:de )?navigation privée', r'\1 Aerogel'),
           (r'Ongl\. navig\. priv\.', 'Onglets Aerogel'),
           (r'\ben navigation privée', 'en Aerogel'),
           (r'\bNavigation privée', 'Aerogel'),
           (r"\bde Aerogel", "d'Aerogel"),
           (r"\bDe Aerogel", "D'Aerogel")],
    'it': [(r'\b[Ii]ncognito\b', 'Aerogel')],
    'ja': [(r'シークレット ?モード', 'Aerogel'),
           (r'シークレット', 'Aerogel')],
    'nl': [(r'\b[Ii]ncognito([a-z])', r'Aerogel-\1'),
           (r'\b[Ii]ncognito\b', 'Aerogel')],
    'pl': [(r'\b[Ii]ncognito\b', 'Aerogel')],
    'pt-BR': [(r'\b([Mm]odo) de navegação anônima', r'\1 Aerogel'),
              (r'\b([Mm]odo) anônimo', r'\1 Aerogel'),
              (r'\b([Jj]anelas?|[Gg]uias?|[Aa]bas?|[Ss]essões|[Ss]essão) anônim[oa]s?', r'\1 Aerogel'),
              (r'\b([nd])a [Nn]avegação anônima', r'\1o Aerogel'),
              (r'\bNavegação anônima', 'Aerogel'),
              (r'\bnavegação anônima', 'Aerogel')],
    'pt-PT': [(r'\b([Mm]odo) de navegação anónima', r'\1 Aerogel'),
              (r'Sep\. nav\. anónima', 'Separadores Aerogel'),
              (r'naveg\. anón\.', 'Aerogel'),
              (r'separad\. nav\. anónima', 'separador Aerogel'),
              (r'\b([Ss]eparador(?:es)?|[Jj]anelas?|[Ss]essões|[Ss]essão) (?:de [Nn]avegação )?anónim[oa]s?', r'\1 Aerogel'),
              (r'\b([nd])a [Nn]avegação anónima', r'\1o Aerogel'),
              (r'\bNavegação anónima', 'Aerogel'),
              (r'\bnavegação anónima', 'Aerogel')],
    'ru': [(r'[Ии]нкогнито', 'Aerogel')],
    'tr': [(r'\bGizli\b', 'Aerogel'),
           (r'\bgizli (?=(sekme|mod|pencere|oturum|tarama))', 'Aerogel ')],
    'ur': [(r'پوشیدگی', 'Aerogel')],
    'zh-CN': [(r'无痕(模式|式|浏览)?', 'Aerogel')],
    'zh-TW': [(r'無痕(模式|式|瀏覽)?', 'Aerogel')],
}
ALSO = {'es': ['es-419'], 'fr': ['fr-CA'], 'zh-TW': ['zh-HK'], 'pt-PT': [], 'pt-BR': []}

PH_BLOCK = re.compile(r'(<ph\b.*?</ph>|<ph\b[^>]*/>)', re.S)


def outside_ph(text, rules):
    parts = PH_BLOCK.split(text)
    for i in range(0, len(parts), 2):
        for pattern, repl in rules:
            parts[i] = re.sub(pattern, repl, parts[i])
    return ''.join(parts)


def spaced(text):
    text = re.sub('(?<=%s)Aerogel' % CJK, ' Aerogel', text)
    text = re.sub('Aerogel(?=%s)' % CJK, 'Aerogel ', text)
    return text


def message_id(block, base):
    mini = ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<grit latest_public_release="0" current_release="1">'
            '<outputs></outputs><release seq="1">'
            '<messages fallback_to_english="true">\n' + block +
            '</messages></release></grit>\n')
    root = grd_reader.Parse(io.StringIO(mini), dir=base)
    for node in root.Preorder():
        if isinstance(node, message.MessageNode):
            return node.GetCliques()[0].GetMessage().GetId()
    return None


def main():
    total = written = 0
    for grd, sources in TARGETS:
        if not os.path.exists(grd):
            print('[aerium] FATAL: %s is missing' % grd, file=sys.stderr)
            return 1
        base = os.path.dirname(grd)
        remap = {}
        for src_path in sources:
            if not os.path.exists(src_path):
                print('[aerium] FATAL: %s is missing' % src_path, file=sys.stderr)
                return 1
            src = open(src_path, encoding='utf-8').read()
            out = []
            pos = 0
            for m in re.finditer(r'[ \t]*<message name="[A-Z0-9_]+".*?</message>\n', src, re.S):
                block = m.group(0)
                body = re.search(r'>(.*)</message>', block, re.S).group(1)
                if not re.search(r'[Ii]ncognito', PH_BLOCK.sub('', body)):
                    continue
                head = block[:block.index('>') + 1]
                new_body = outside_ph(body, ENGLISH)
                if new_body == body:
                    continue
                new_block = head + new_body + '</message>\n'
                old_id = message_id(block, base)
                new_id = message_id(new_block, base)
                if old_id and new_id and old_id != new_id:
                    remap[old_id] = new_id
                out.append(src[pos:m.start()])
                out.append(new_block)
                pos = m.end()
                total += 1
            out.append(src[pos:])
            open(src_path, 'w', encoding='utf-8').write(''.join(out))
        grd_src = open(grd, encoding='utf-8').read()
        xtbs = re.findall(r'<file path="([^"]+\.xtb)" lang="([^"]+)"', grd_src)
        langs = {}
        for lang, aliases in ALSO.items():
            for alias in aliases:
                langs[alias] = lang
        for path, lang in xtbs:
            xtb = os.path.join(base, path)
            if not os.path.exists(xtb):
                continue
            bundle = open(xtb, encoding='utf-8').read()
            present = set(re.findall(r'<translation id="(\d+)"', bundle))
            rules = LOCAL.get(langs.get(lang, lang))
            lines = []
            for old_id, new_id in remap.items():
                if new_id in present:
                    continue
                m = re.search(r'<translation id="%s">(.*?)</translation>' % old_id, bundle, re.S)
                if not m:
                    continue
                text = m.group(1)
                if rules:
                    text = outside_ph(text, rules)
                    if langs.get(lang, lang) in ('ja', 'zh-CN', 'zh-TW'):
                        text = spaced(text)
                lines.append('<translation id="%s">%s</translation>\n' % (new_id, text))
                present.add(new_id)
            if not lines:
                continue
            if '</translationbundle>' not in bundle:
                print('[aerium] FATAL: no </translationbundle> in ' + xtb, file=sys.stderr)
                return 1
            bundle = bundle.replace('</translationbundle>', ''.join(lines) + '</translationbundle>', 1)
            open(xtb, 'w', encoding='utf-8').write(bundle)
            written += len(lines)
    print('[aerium] Aerogel: %d strings renamed, %d translations carried over' % (total, written))
    return 0


if __name__ == '__main__':
    sys.exit(main())
