"""Archive this package's final PDS reports and actual board captures."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil

from check_board import check

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def collect(name, tags):
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise ValueError('Invalid build name')
    build = ROOT/'build'/name
    result = json.loads((build/'build_result.json').read_text())
    if result['status'] != 'build_complete' or sha(ROOT/result['bitstream']) != result['sha256']:
        raise ValueError('Build incomplete or bitstream changed')
    for entry in json.loads((build/'input_snapshot.json').read_text())['files']:
        if sha(build/entry['path']) != entry['sha256']:
            raise ValueError('Build input changed: ' + entry['path'])
    rows = list(csv.reader((build/'multiseed_summary.csv').read_text(encoding='utf-8-sig').splitlines()))
    index = next(i for i, row in enumerate(rows) if row and row[0] == 'Seed')
    seed = dict(zip(rows[index], rows[index+1]))
    index = next(i for i, row in enumerate(rows) if row and row[0] == 'Logic Utilization')
    used = dict(zip(rows[index], rows[index+1]))
    resources = {k: int(used[k]) for k in ('LUT', 'FF', 'DRM', 'APM', 'Distributed RAM')}
    metrics = {k: float(seed[k]) for k in ('Setup(Slow)', 'Setup(Fast)', 'Hold(Slow)', 'Hold(Fast)',
                                          'Recovery(Slow)', 'Recovery(Fast)', 'Removal(Slow)', 'Removal(Fast)')}
    if len(result['final_timing']) != 1:
        raise ValueError('One final timing report required')
    timing = ROOT/result['final_timing'][0]
    text = timing.read_text(errors='replace')
    for name2 in ('Setup', 'Hold'):
        for corner in ('Slow', 'Fast'):
            match = re.search(re.escape(f'{name2} Summary({corner} Corner):') +
                              r'.*?\n core_clk\s+core_clk\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)', text, re.S)
            if not match or abs(float(match[1])-metrics[f'{name2}({corner})']) > 0.0001:
                raise ValueError('Final report/CSV mismatch')
    sta = 'Design Summary : All Constraints Met.' in text
    if sta and any(x < 0 for x in metrics.values()):
        raise ValueError('Inconsistent timing pass status')
    captures = []
    for tag in tags:
        if not re.fullmatch(r'[A-Za-z0-9_-]+', tag):
            raise ValueError('Invalid board tag')
        capture = check(ROOT/'evidence'/tag)
        if capture['bitstream_sha256'] != result['sha256']:
            raise ValueError('Board capture is for another bitstream')
        captures.append(capture)
    baseline = json.loads((ROOT/'evidence/baseline/measurement.json').read_text())
    reference = {k: baseline['resources'][k]-baseline['delta_vs_reference'][k] for k in resources}
    delta = {k: resources[k]-reference[k] for k in resources}
    report = {**result, 'sta_closed': sta, 'final_sta': metrics, 'resources': resources,
              'delta_vs_reference': delta,
              'area_gate_passed': sum(delta[k] for k in ('LUT', 'FF', 'Distributed RAM')) <= 0,
              'board_runs': captures, 'board_verified': len(captures) >= 2 and
              all(x['performance_parity'] for x in captures),
              'semantic_modularization_complete': False}
    output = ROOT/'evidence'/('implementation-' + name)
    output.mkdir(parents=True, exist_ok=False)
    files = {timing: 'final-timing.rtr', build/'multiseed_summary.csv': 'multiseed_summary.csv',
             build/'compile/run.log': 'compile.log', build/'synthesize/run.log': 'synthesize.log',
             build/'device_map/run.log': 'device_map.log', build/'place_route/run.log': 'place_route.log',
             build/'input_snapshot.json': 'input_snapshot.json', build/'implementation.tcl': 'implementation.tcl',
             build/'pds_stdout.log': 'pds_stdout.log', build/'image_verification.json': 'image_verification.json'}
    for source, target in files.items():
        shutil.copy2(source, output/target)
    (output/'measurement.json').write_text(json.dumps(report, indent=2))
    sums = [sha(p) + '  ' + p.name for p in sorted(output.iterdir()) if p.is_file()]
    (output/'SHA256SUMS').write_text('\n'.join(sums) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', required=True)
    parser.add_argument('--board', action='append', default=[])
    args = parser.parse_args()
    collect(args.name, args.board)
