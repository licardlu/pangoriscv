"""Self-contained PDS build. Uses only this release and the installed PDS tool."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from verify_image import verify as verify_image

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local(path):
    if not path or '\\' in path or ':' in path or Path(path).is_absolute():
        raise ValueError('Package-relative POSIX path required: ' + path)
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT) or not resolved.is_file():
        raise ValueError('Missing file or path outside package: ' + path)
    return resolved


def sources():
    return [local(line.strip()) for line in (ROOT/'sources.f').read_text().splitlines()
            if line.strip() and not line.startswith('#')]


def verify():
    record = json.loads((ROOT/'release_manifest.json').read_text())
    for entry in record['files']:
        if sha(local(entry['path'])) != entry['sha256']:
            raise ValueError('Release file changed: ' + entry['path'])
    actual = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*')
              if p.is_file() and p.relative_to(ROOT).parts[0] not in
              ('build', 'evidence', 'bitstream', 'provenance')
              and '__pycache__' not in p.parts and p.name != 'release_manifest.json'}
    expected = {e['path'] for e in record['files']}
    if actual - expected:
        raise ValueError('Untracked package inputs: ' + repr(sorted(actual-expected)))
    queue = list(sources())
    seen = set()
    modules = {}
    ram_files = []
    while queue:
        path = queue.pop()
        if path in seen:
            continue
        seen.add(path)
        text = path.read_text(encoding='utf-8')
        for inc in re.findall(r'`include\s+"([^"]+)"', text):
            dependency = (path.parent/inc).resolve()
            local(dependency.relative_to(ROOT).as_posix())
            queue.append(dependency)
        for name in re.findall(r'^\s*module\s+(\w+)', text, re.M):
            if name in modules:
                raise ValueError('Duplicate module: ' + name)
            modules[name] = path.relative_to(ROOT).as_posix()
        for name in re.findall(r'\$readmemb\(\s*"([^"]+)"', text):
            ram_files.append(local('firmware/image/' + name))
    if len(ram_files) != 8:
        raise ValueError('Expected exactly eight RAM initialization lanes')
    if 'VexiiRiscv' in modules or 'pango_replica_core' not in modules:
        raise ValueError('Wrong core implementation in release')
    image = verify_image(ROOT/'firmware/image/coremark.elf', ROOT/'firmware/image')
    if image['elf_sha256'] != record['firmware']['elf_sha256'] or image['ram_sha256'] != record['firmware']['ram_sha256']:
        raise ValueError('Frozen firmware changed')
    return {'status': 'PASS', 'design_sources': len(sources()), 'hdl_files_with_includes': len(seen),
            'modules': len(modules), 'external_source_dependencies': 0, 'memory_lanes': 8,
            'image': image, 'scope': 'release hashes, include closure, local data and frozen firmware; not formal equivalence'}


def create_manifest():
    # Explicit maintenance action after intentional edits; never done by build.
    files = []
    for p in sorted(ROOT.rglob('*')):
        if not p.is_file() or '__pycache__' in p.parts or p.name == 'release_manifest.json':
            continue
        if p.relative_to(ROOT).parts[0] in ('build', 'evidence', 'bitstream', 'provenance'):
            continue
        files.append({'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)})
    image = verify_image(ROOT/'firmware/image/coremark.elf', ROOT/'firmware/image')
    result = {'schema': 1, 'variant': 'native-shifters-exact-pds-standalone', 'files': files,
              'firmware': image, 'independent_sources': True, 'semantic_modularization_complete': False,
              'sta_closed': False, 'baseline_bitstream_sha256':
              '6a7eb74c43e7f42ea8c1ff73693348726bbf7c66c14221bd65ec1ac1afba9198'}
    (ROOT/'release_manifest.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return {'status': 'MANIFEST_WRITTEN', 'files': len(files)}


def tcl_path(path):
    value = path.as_posix()
    if any(c in value for c in '{}\r\n'):
        raise ValueError('Unsupported Tcl path: ' + value)
    return '{' + value + '}'


def build(name, pds):
    checked = verify()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise ValueError('Build name must be one directory name')
    executable = pds or os.environ.get('PDS_SHELL') or shutil.which('pds_shell.exe')
    if not executable or not Path(executable).is_file():
        raise ValueError('Supply --pds <pds_shell.exe> or set PDS_SHELL/PATH')
    out = ROOT/'build'/name
    out.mkdir(parents=True, exist_ok=False)
    staged = []
    for source in sources():
        target = out/'sources'/source.name
        if target.exists():
            raise ValueError('Source basename collision: ' + source.name)
        target.parent.mkdir(parents=True, exist_ok=True)
        text = source.read_text(encoding='utf-8')
        includes = re.findall(r'`include\s+"([^"]+)"', text)
        for include in includes:
            original = (source.parent/include).resolve()
            copied = out/'sources/sections'/original.name
            copied.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, copied)
            text = text.replace('"' + include + '"', '"' + copied.as_posix() + '"')
        if includes:
            target.write_text(text, encoding='utf-8', newline='\n')
        else:
            shutil.copy2(source, target)
        staged.append(target)
    shutil.copytree(ROOT/'constraints', out/'constraints')
    for image in (ROOT/'firmware/image').glob('*.bin'):
        shutil.copy2(image, out/image.name)
    image = verify_image(ROOT/'firmware/image/coremark.elf', out)
    (out/'image_verification.json').write_text(json.dumps(image, indent=2))
    (out/'source_list.tcl').write_text('set exact_sources {\n' +
        ''.join('  ' + tcl_path(p) + '\n' for p in staged) + '}\n', encoding='utf-8')
    shutil.copy2(ROOT/'flow/build.tcl', out/'implementation.tcl')
    input_files = [{'path': p.relative_to(out).as_posix(), 'sha256': sha(p)}
                   for p in sorted(out.rglob('*')) if p.is_file()]
    (out/'input_snapshot.json').write_text(json.dumps({'verification': checked,
        'release_manifest_sha256': sha(ROOT/'release_manifest.json'), 'files': input_files}, indent=2))
    print('PDS_STARTED ' + str(out), flush=True)
    start = time.time()
    # Do not pass the old repository root, generator paths or tool configuration.
    env = os.environ.copy()
    env.pop('VEXII_ROOT', None)
    with (out/'pds_stdout.log').open('w', encoding='utf-8') as log:
        code = subprocess.call([str(Path(executable).resolve()), '-f', str(out/'implementation.tcl')],
                               cwd=out, stdout=log, stderr=subprocess.STDOUT, env=env)
    log = (out/'pds_stdout.log').read_text(errors='replace')
    bit = out/'generate_bitstream/pango_vexii_top.sbit'
    if code or 'EXACT_BUILD_FLOW_COMPLETE' not in log or not bit.is_file():
        raise RuntimeError('PDS build failed: ' + str(out/'pds_stdout.log') + '\n' + log[-3500:])
    compile_log = (out/'compile/run.log').read_text(errors='replace')
    if compile_log.count('Loading memory data from file') != 8 or 'Cannot open specified data' in compile_log:
        raise RuntimeError('Eight-lane firmware gate failed')
    timing = list((out/'report_timing').glob('*.rtr'))
    if not timing:
        raise RuntimeError('Missing final STA reports')
    baseline = json.loads((ROOT/'release_manifest.json').read_text())
    result = {'status': 'build_complete', 'wall_seconds': time.time()-start,
              'independent_sources': True, 'bitstream': bit.relative_to(ROOT).as_posix(),
              'sha256': sha(bit), 'loaded_memory_lanes': 8,
              'same_bitstream_as_board_proven_baseline': sha(bit) == baseline['baseline_bitstream_sha256'],
              'final_timing': [p.relative_to(ROOT).as_posix() for p in timing],
              'board_verified': False, 'sta_closed': None,
              'note': 'Build completion is not STA closure; board tests recorded separately'}
    (out/'build_result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2), flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['verify', 'build', 'manifest'])
    parser.add_argument('--name', default='run-001')
    parser.add_argument('--pds')
    args = parser.parse_args()
    try:
        if args.command == 'manifest':
            result = create_manifest()
        elif args.command == 'verify':
            result = verify()
        else:
            result = build(args.name, args.pds)
        print(json.dumps(result, indent=2))
    except Exception as exc:
        print('FAIL ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
