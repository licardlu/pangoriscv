"""Wait for the second gated implementation, then verify its paired board once."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'build/overnight_20261116'
RELEASE = ROOT / 'project/trash_sorting/candidates/overnight_020/release'
DEADLINE = datetime.datetime(2026, 11, 16, 4, tzinfo=datetime.timezone.utc).timestamp()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--attempt', choices=('002','004','005'), default='002')
    args = parser.parse_args()
    build = ROOT / ('build/overnight_020_full_' + args.attempt)
    key = 'final_retry_' + args.attempt
    with (BASE / (key + '.lock')).open('x') as handle:
        handle.write(str(os.getpid()))
    state = dict(status='waiting_for_gated_full_' + args.attempt, pid=os.getpid())

    def save():
        state['utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (BASE / (key + '.json')).write_text(json.dumps(state, indent=2), encoding='utf8')

    save()
    try:
        while True:
            if time.time() >= DEADLINE:
                raise RuntimeError('Deadline; no board step started')
            log = (BASE / ('full_' + args.attempt + '.log')).read_text(encoding='utf8', errors='replace')
            if 'Traceback (most recent call last)' in log:
                raise RuntimeError('Implementation failed; inspect full_' + args.attempt + '.log')
            if 'FULL_APPLICATION_BITSTREAM_READY' in log:
                break
            time.sleep(10)
        selected = json.loads((BASE / 'final_selection_001.json').read_text(encoding='utf8'))
        manifest = json.loads((RELEASE / 'manifest.json').read_text(encoding='utf8'))
        if (Path(manifest['source_build']).resolve() != build.resolve() or
                manifest['model_sha256'] != selected['model_sha256'] or
                not manifest['timing_pass'] or manifest['benchmark_mode'] != 'simulated_demo' or
                hashlib.sha256((RELEASE / 'yolo_camera_top.sbit').read_bytes()).hexdigest() != manifest['bitstream_sha256']):
            raise ValueError('Second implementation release identity mismatch')
        if time.time() >= DEADLINE:
            raise RuntimeError('Deadline; no board step started')
        command = [sys.executable, str(ROOT / 'project/trash_sorting/tools/restore_full_board.py'),
            '--release-dir', str(RELEASE), '--port', 'COM34',
            '--pds', str(ROOT.parent / 'pds/PDS_2022.2-SP6.1/bin'),
            '--out', str(ROOT / 'evidence/records/overnight-20261116/final-board-001'),
            '--fixtures', str(RELEASE / 'numerical_fixtures'), '--verify-input',
            '--probe-frames', '3', '--collect-profile']
        state.update(status='board_acceptance', command=command)
        save()
        with (BASE / 'final_board_001.log').open('x', encoding='utf8') as handle:
            result = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError('Board acceptance failed; inspect final_board_001.log')
        state['status'] = 'completed'
        save()
    except BaseException as error:
        state.update(status='failed', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
