# Copyright 2026 Dioide
# SPDX-License-Identifier: GPL-3.0-only

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

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


def git_env(tmp):
    env = dict(os.environ, GIT_CEILING_DIRECTORIES=os.path.dirname(tmp))
    env.pop('GIT_DIR', None)
    env.pop('GIT_WORK_TREE', None)
    return env


def rebuild(args, missing, extra, tmp):
    if not args.base:
        print('[aerium] FATAL: no pristine copies and no base patches', file=sys.stderr)
        sys.exit(1)
    base = patch_files(args.base)
    bseen, _ = touched(base)
    bset = set(bseen)
    tb = tempfile.mkdtemp(prefix='aerium-base-')
    try:
        for path in bseen:
            if skipped(path, extra):
                continue
            src = os.path.join(args.src, path)
            if os.path.isfile(src):
                put(src, os.path.join(tb, path))
        excludes = [f'--exclude={s}' for s in SKIP] + [f'--exclude={p}' for p in extra]
        for p in reversed(base):
            r = subprocess.run(['git', 'apply', '-R', '--whitespace=nowarn', *excludes, p],
                               cwd=tb, capture_output=True, text=True, env=git_env(tb))
            if r.returncode:
                print(f'[aerium] FATAL: {os.path.basename(p)} did not reverse', file=sys.stderr)
                sys.exit(1)
        for path in missing:
            orig = os.path.join(tb, path) if path in bset else os.path.join(args.src, path)
            if not os.path.isfile(orig):
                print('[aerium] FATAL: a pristine file could not be rebuilt', file=sys.stderr)
                sys.exit(1)
            put(orig, os.path.join(tmp, path))
            put(orig, os.path.join(args.cache, path))
        print(f'[aerium] pristine copies rebuilt: {len(missing)}')
    finally:
        shutil.rmtree(tb, ignore_errors=True)


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
        if missing:
            rebuild(args, missing, extra, tmp)
        excludes = [f'--exclude={s}' for s in SKIP] + [f'--exclude={p}' for p in extra]
        env = git_env(tmp)
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
        print(f'[aerium] patched files refreshed: {n} of {len(work)}')
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
    r.add_argument('--version', default='')
    r.add_argument('--base', action='append')
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
