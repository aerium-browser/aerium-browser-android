# Copyright 2026 Dioide
# SPDX-License-Identifier: GPL-3.0-only

import argparse
import base64
import concurrent.futures
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

GITILES = 'https://chromium.googlesource.com/chromium/src/+/refs/tags/{}/{}?format=TEXT'
SKIP = ('*.grd', '*.grdp', '*.xtb')


def patch_files(dirs):
    out = []
    for d in dirs:
        if os.path.isdir(d):
            out += sorted(os.path.join(d, n) for n in os.listdir(d) if n.endswith('.patch'))
    return out


def touched(patches):
    seen, created = [], set()
    known = set()
    for p in patches:
        fresh = False
        cur = None
        with open(p, encoding='utf-8', errors='surrogateescape') as f:
            for line in f:
                if line.startswith('diff --git '):
                    cur = line.split()[2][2:]
                    fresh = cur not in known
                    if fresh:
                        known.add(cur)
                        seen.append(cur)
                elif cur and fresh and line.startswith('new file mode'):
                    created.add(cur)
    return seen, created


def skipped(path, extra):
    if path in extra:
        return True
    return any(path.endswith(s[1:]) for s in SKIP)


def fetch(version, path):
    url = GITILES.format(version, path)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                return base64.b64decode(r.read())
        except Exception as e:
            if attempt == 5:
                raise RuntimeError(f'{path}: {e}')
            time.sleep(5 * (attempt + 1))


def same(a, b):
    if not os.path.isfile(a) or not os.path.isfile(b):
        return False
    if os.path.getsize(a) != os.path.getsize(b):
        return False
    with open(a, 'rb') as x, open(b, 'rb') as y:
        return x.read() == y.read()


def put(src, dst):
    os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
    shutil.copyfile(src, dst)
    shutil.copymode(src, dst)


def save(args):
    seen, created = touched(patch_files(args.patches))
    n = 0
    for path in seen:
        if path in created:
            continue
        src = os.path.join(args.src, path)
        if os.path.isfile(src):
            put(src, os.path.join(args.cache, path))
            n += 1
    print(f'[aerium] pristine copies kept: {n}')


def refresh(args):
    patches = patch_files(args.patches)
    seen, created = touched(patches)
    extra = set(args.skip or [])
    work = [p for p in seen if not skipped(p, extra)]
    need = [p for p in work if p not in created]
    tmp = tempfile.mkdtemp(prefix='aerium-refresh-')
    try:
        missing = []
        for path in need:
            cached = os.path.join(args.cache, path)
            if os.path.isfile(cached):
                put(cached, os.path.join(tmp, path))
            else:
                missing.append(path)
        with concurrent.futures.ThreadPoolExecutor(4) as pool:
            for path, data in zip(missing, pool.map(lambda p: fetch(args.version, p), missing)):
                dst = os.path.join(tmp, path)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with open(dst, 'wb') as f:
                    f.write(data)
                put(dst, os.path.join(args.cache, path))
        excludes = [f'--exclude={s}' for s in SKIP] + [f'--exclude={p}' for p in extra]
        env = dict(os.environ, GIT_CEILING_DIRECTORIES=os.path.dirname(tmp))
        env.pop('GIT_DIR', None)
        env.pop('GIT_WORK_TREE', None)
        for p in patches:
            r = subprocess.run(['git', 'apply', '--whitespace=nowarn', *excludes, p],
                               cwd=tmp, capture_output=True, text=True, env=env)
            if r.returncode:
                print(f'[aerium] FATAL: {os.path.basename(p)} did not refresh', file=sys.stderr)
                sys.exit(1)
        for path in need:
            new = os.path.join(tmp, path)
            cached = os.path.join(args.cache, path)
            if os.path.isfile(new) and same(new, cached):
                print('[aerium] FATAL: patches were not applied during refresh', file=sys.stderr)
                sys.exit(1)
        for path in work:
            if path in created and not os.path.isfile(os.path.join(tmp, path)):
                print('[aerium] FATAL: patches were not applied during refresh', file=sys.stderr)
                sys.exit(1)
        n = 0
        for path in work:
            new = os.path.join(tmp, path)
            cur = os.path.join(args.src, path)
            if os.path.isfile(new) and not same(new, cur):
                put(new, cur)
                n += 1
        print(f'[aerium] patched files refreshed: {n} of {len(work)} ({len(missing)} fetched)')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def copy(args):
    n = 0
    for root, _, names in os.walk(args.from_dir):
        for name in names:
            src = os.path.join(root, name)
            dst = os.path.join(args.to_dir, os.path.relpath(src, args.from_dir))
            if not same(src, dst):
                put(src, dst)
                n += 1
    print(f'[aerium] {args.label} refreshed: {n}')


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('save')
    s.add_argument('--src', required=True)
    s.add_argument('--cache', required=True)
    s.add_argument('patches', nargs='+')
    r = sub.add_parser('refresh')
    r.add_argument('--src', required=True)
    r.add_argument('--cache', required=True)
    r.add_argument('--version', required=True)
    r.add_argument('--skip', action='append')
    r.add_argument('patches', nargs='+')
    c = sub.add_parser('copy')
    c.add_argument('--label', default='files')
    c.add_argument('from_dir')
    c.add_argument('to_dir')
    args = ap.parse_args()
    {'save': save, 'refresh': refresh, 'copy': copy}[args.cmd](args)


if __name__ == '__main__':
    main()
