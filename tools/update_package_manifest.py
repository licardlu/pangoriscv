"""Record Git-visible handoff files without staging, committing or uploading."""
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def main():
    raw = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
    names = sorted(set(raw.decode('utf8').split('\0')) - {'', 'SUBMISSION_SHA256.json'})
    def record_file(name):
        path = ROOT / name
        if path.is_file():
            data = path.read_bytes()
            return dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        return None
    files = []
    with ThreadPoolExecutor(max_workers=12) as executor:
        for index, entry in enumerate(executor.map(record_file, names), 1):
            if entry is not None:
                files.append(entry)
            if index % 2000 == 0:
                print(f'HASHED {index}/{len(names)}', flush=True)
    record = dict(schema=1, generated=datetime.now(timezone.utc).isoformat(), algorithm='sha256',
                  branch=subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip(),
                  note='Current Git-visible working-tree handoff, including untracked source/evidence; not a commit or upload. Excludes itself and ignored build/tool caches.',
                  files=files)
    (ROOT / 'SUBMISSION_SHA256.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print(json.dumps(dict(files=len(files), bytes=sum(x['bytes'] for x in files), branch=record['branch'])))


if __name__ == '__main__':
    main()
