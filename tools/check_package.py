"""Verify that every file in this package matches SUBMISSION_SHA256.json.

This is the first thing to run after copying the package off the archive: it
catches truncated downloads, unzipped-in-the-wrong-encoding filenames and any
local edit that would make the shipped code differ from the recorded one.

    python tools/check_package.py
    python tools/check_package.py --verbose      # list every file
    python tools/check_package.py --root D:/somewhere/pangoriscv

Exit code 0 = every recorded file is present with the recorded SHA256.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'SUBMISSION_SHA256.json'


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', type=Path, default=ROOT)
    ap.add_argument('--verbose', action='store_true')
    args = ap.parse_args()

    root = args.root.resolve()
    manifest = root / 'SUBMISSION_SHA256.json'
    if not manifest.is_file():
        print('FAIL no SUBMISSION_SHA256.json under %s' % root)
        return 2
    record = json.loads(manifest.read_text(encoding='utf-8-sig'))
    entries = record['files']

    missing, changed = [], []
    for entry in entries:
        path = root / entry['path']
        if not path.is_file():
            missing.append(entry['path'])
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry['sha256']:
            changed.append(entry['path'])
        elif args.verbose:
            print('  ok  %s' % entry['path'])

    print('root    : %s' % root)
    print('recorded: %d files, %.1f MB'
          % (len(entries), sum(e['bytes'] for e in entries) / 1048576))
    print('present : %d' % (len(entries) - len(missing)))
    if missing:
        print('\nMISSING %d:' % len(missing))
        for p in missing[:20]:
            print('  - ' + p)
    if changed:
        print('\nCHANGED %d (content differs from the recorded hash):' % len(changed))
        for p in changed[:20]:
            print('  - ' + p)
    if missing or changed:
        return 1
    print('\nPASS package contents match SUBMISSION_SHA256.json')
    return 0


if __name__ == '__main__':
    sys.exit(main())
