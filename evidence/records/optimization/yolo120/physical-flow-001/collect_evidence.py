"""Copy compact, hash-bound implementation evidence; never delete build outputs."""
import argparse
import json
from pathlib import Path
import shutil

from build import PROJECT, REPO, sha, write_json


def collect(build, out, failure_reason=None):
    build = build.resolve()
    if not build.is_relative_to(PROJECT/'build'):
        raise ValueError('Expected a YOLO120 staged build')
    acceptance = build/'acceptance.json'
    if not acceptance.exists() and not failure_reason:
        raise ValueError('Run the acceptance gate or explicitly record a failed implementation')
    out.mkdir(parents=True, exist_ok=False)
    records = []

    def copy(p):
        target = out/p.relative_to(build)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, target)
        records.append(dict(path=target.relative_to(out).as_posix(), sha256=sha(target)))

    for name in ('inputs.json', 'acceptance.json', 'camera.fdc', 'flow.tcl',
                 'sources.f', 'shell.log', 'multiseed_summary.csv', 'cpu_region.input.txt',
                 'cpu_region.generated.txt', 'region_manifest.json'):
        if (build/name).is_file():
            copy(build/name)
    for p in sorted(build.glob('*.pcf')):
        copy(p)
    for directory in ('compile', 'synthesize', 'device_map', 'place_route',
                      'report_timing', 'constraint_check'):
        folder = build/directory
        if folder.exists():
            for p in sorted(folder.iterdir()):
                if p.is_file() and (p.name == 'run.log' or
                    p.suffix in ('.rtr', '.ccr', '.txt', '.snr', '.prr')):
                    copy(p)
    for p in sorted((build/'firmware').iterdir()):
        if p.is_file() and (p.suffix in ('.elf', '.map', '.su', '.json') or
                            p.name in ('program.hex', 'data.hex')):
            copy(p)
    checks = build/'checks'
    if checks.exists():
        for p in sorted(checks.rglob('*')):
            if p.is_file() and p.suffix in ('.json', '.log', '.hex'):
                copy(p)
    inputs = json.loads((build/'inputs.json').read_text(encoding='utf-8'))
    script = PROJECT/'tools/build.py'
    if inputs.get('build_script_sha256') == sha(script):
        target = out/'build_script.py'
        shutil.copy2(script, target)
        records.append(dict(path=target.name, sha256=sha(target)))
    write_json(out/'record.json', dict(build_name=build.name, files=records,
        failure_reason=failure_reason, board_verified=False,
        acceptance_gate_sha256=sha(script),
        note='Original PDS output names and absolute build paths are retained as evidence. '
             'Bitstream identity is recorded in acceptance.json; this record is not board acceptance.'))
    return len(records)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--failure-reason')
    args = p.parse_args()
    print(f'YOLO120_EVIDENCE_SAVED {collect(args.build, args.out, args.failure_reason)} files')
