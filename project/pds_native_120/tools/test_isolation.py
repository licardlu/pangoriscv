"""Verify a relocated source-only copy while denying reads from the old repo."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main(forbidden):
    manifest = json.loads((ROOT/'release_manifest.json').read_text())
    # Intentionally omit provenance, baseline bitstreams, evidence and build caches.
    probe = Path(tempfile.mkdtemp(prefix='pango standalone probe '))
    for entry in manifest['files'] + [{'path': 'release_manifest.json'}]:
        source = ROOT/entry['path']
        target = probe/entry['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    guard = r'''
import json, os, pathlib, sys
release = pathlib.Path(sys.argv[1]).resolve()
forbidden = pathlib.Path(sys.argv[2]).resolve()
sys.path.insert(0, str(release/'tools'))
opened = set()
def audit(event, args):
    if event != 'open' or not isinstance(args[0], (str, bytes, os.PathLike)):
        return
    path = pathlib.Path(os.fsdecode(args[0])).resolve()
    if path.is_relative_to(forbidden):
        raise PermissionError('Read from old source tree forbidden: ' + str(path))
    if path.is_relative_to(release):
        opened.add(path.relative_to(release).as_posix())
sys.addaudithook(audit)
import build
result = build.verify()
print(json.dumps({'status': 'PASS', 'verification': result,
                  'source_tree_reads_denied': str(forbidden), 'local_files_opened': len(opened)}))
'''
    # A supplied old tree is only a deny rule, never an input dependency.
    forbidden = Path(forbidden).resolve()
    result = subprocess.run([sys.executable, '-I', '-c', guard, str(probe), str(forbidden)],
                            cwd=probe, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    report = json.loads(result.stdout)
    report['relocated_copy'] = str(probe)
    report['scope'] = 'source-only verify under Python file-read guard; PDS independently rebuilt separately'
    report['original_files_deleted'] = 0
    report['temporary_copy_removed'] = False
    out = ROOT/'evidence/isolation'
    out.mkdir(parents=True, exist_ok=True)
    (out/'result.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--forbid-root', type=Path, default=ROOT)
    args = parser.parse_args()
    main(args.forbid_root)
