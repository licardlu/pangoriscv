"""Run the frozen 10:00 implementation, then its gated SRAM acceptance once."""
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'build/overnight_20261116'
RELEASE = ROOT / 'project/trash_sorting/candidates/overnight_020/release'
START = datetime.datetime(2026, 11, 16, 2, tzinfo=datetime.timezone.utc).timestamp()
DEADLINE = datetime.datetime(2026, 11, 16, 4, tzinfo=datetime.timezone.utc).timestamp()


def main():
    with (BASE / 'final_execution_001.lock').open('x') as handle:
        handle.write(str(os.getpid()))
    state = dict(status='waiting_for_10am', pid=os.getpid(), steps=[],
                 not_before_utc='2026-11-16T02:00:00Z', deadline_utc='2026-11-16T04:00:00Z')

    def save():
        state['utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (BASE / 'final_execution_001.json').write_text(json.dumps(state, indent=2), encoding='utf8')

    def verify_frozen():
        selected = json.loads((BASE / 'final_selection_001.json').read_text(encoding='utf8'))
        frozen = Path(selected['source'])
        for name, digest in selected['files'].items():
            if hashlib.sha256((frozen / name).read_bytes()).hexdigest() != digest:
                raise ValueError('Frozen input changed: ' + name)
        spec = importlib.util.spec_from_file_location('accepted_build', Path(__file__).with_name('build_full.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.verify_firmware_sources(frozen)
        return selected, frozen

    def run(name, command, log):
        if time.time() >= DEADLINE:
            raise RuntimeError('Deadline reached; no new step started: ' + name)
        step = dict(name=name, command=[str(p) for p in command], status='running',
                    started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), log=str(log))
        state['steps'].append(step)
        state['status'] = name
        save()
        with log.open('x', encoding='utf8') as handle:
            result = subprocess.run(step['command'], cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        step.update(returncode=result.returncode, status='completed' if result.returncode == 0 else 'failed',
                    completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
        save()
        if result.returncode:
            raise RuntimeError('Step failed: ' + name)

    save()
    try:
        verify_frozen()
        while time.time() < START:
            time.sleep(max(0, min(10, START - time.time())))
            save()
        selected, frozen = verify_frozen()
        if (ROOT / 'build/overnight_020_full_001').exists():
            raise ValueError('Formal build already exists; refusing duplicate implementation')
        pds = ROOT.parent / 'pds/PDS_2022.2-SP6.1/bin'
        run('formal_implementation', [sys.executable, Path(__file__).with_name('build_full.py'),
            '--name', 'overnight_020_full_001', '--pds', pds, '--source-dir', frozen,
            '--seed', '7', '--hold-margin-ps', '300', '--optimize-multi-corner-timing',
            '--slack-prior-global-router', 'TRUE', '--release-dir', RELEASE], BASE / 'full_001.log')
        manifest = json.loads((RELEASE / 'manifest.json').read_text(encoding='utf8'))
        if (manifest['model_sha256'] != selected['model_sha256'] or
                not manifest['timing_pass'] or manifest['benchmark_mode'] != 'simulated_demo' or
                manifest['physical_full_application_verified']):
            raise ValueError('Formal release does not match frozen acceptance')
        run('board_acceptance', [sys.executable, ROOT / 'project/trash_sorting/tools/restore_full_board.py',
            '--release-dir', RELEASE, '--port', 'COM34', '--pds', pds,
            '--out', ROOT / 'evidence/records/overnight-20261116/final-board-001',
            '--fixtures', RELEASE / 'numerical_fixtures', '--verify-input', '--probe-frames', '3',
            '--collect-profile'], BASE / 'final_board_001.log')
        state['status'] = 'completed'
        save()
    except BaseException as error:
        state.update(status='failed', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
