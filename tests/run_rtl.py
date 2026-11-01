"""ModelSim regression fixture: snapshot inputs, never touch a physical board."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from measure import assess


def validate_result(kind, text):
    if text.count('TEST_PASS') != 1 or re.search(r'TEST_FAIL|TIMEOUT|\*\* Fatal', text, re.I):
        raise ValueError('Missing unique pass marker: '+text[-4000:])
    if kind in ('benchmark', 'profile'):
        result = assess(text)
        if not result['crc_valid']:
            raise ValueError('Benchmark completed but the five CRCs did not match')
        if kind == 'profile':
            matches = re.findall(r'PROFILE_WINDOW cycles=(\d+)', text)
            if len(matches) != 1 or len(re.findall(r'PROFILE_START pc=', text)) != 1 or len(re.findall(r'PROFILE_STOP pc=', text)) != 1:
                raise ValueError('Profile needs exactly one closed timed window')
            # Retirement is a diagnostic boundary, not the authoritative CSR sample.
            if abs(int(matches[0]) - result['ticks']) > 64:
                raise ValueError('Profile window disagrees with firmware ticks')
            counters = {}
            for group in ('WINDOW', 'BRANCH', 'MEMORY', 'BLOCKS'):
                rows = re.findall(r'PROFILE_'+group+r' ([^\r\n]+)', text)
                if len(rows) != 1:
                    raise ValueError('Missing/duplicate profile counter group: '+group)
                counters[group.lower()] = {key: int(value) for key, value in
                                          re.findall(r'(\w+)=(\d+)', rows[0])}
            branch = counters['branch']
            if branch['count'] <= 0 or branch['miss'] > branch['count']:
                raise ValueError('Invalid branch event counts')
            result['profile'] = {'window': counters['window'], 'memory': counters['memory'],
                                 'blocks': counters['blocks'], 'branch_count': branch['count'],
                                 'branch_miss': branch['miss'],
                                 'branch_miss_rate': branch['miss']/branch['count'],
                                 'scope': 'simulation-only timed events; stalls overlap, dispatch is not retirement IPC'}
        return result
    return {'status': 'PASS', 'board_verified': False}


def profile_addresses(elf, objdump):
    """Find first low mcycle read in each port function; reject absent functions."""
    disassembly = subprocess.check_output([str(objdump), '-d', str(elf)], text=True)
    addresses = []
    for name in ('start_time', 'stop_time'):
        body = re.search(r'^[0-9a-f]+ <'+name+r'>:\n(.*?)(?=\n[0-9a-f]+ <|\Z)',
                         disassembly, re.M | re.S)
        if not body:
            raise ValueError('Missing non-inlined timing function: '+name)
        read = re.search(r'^\s*([0-9a-f]+):.*\bcsrr\s+\w+,mcycle\s*$', body[1], re.M)
        if not read:
            raise ValueError('Missing mcycle read: '+name)
        addresses.append(int(read[1], 16))
    return tuple(addresses)


def run(cmd, cwd, log):
    with (cwd/log).open('w', encoding='utf-8') as stream:
        result = subprocess.run(list(map(str, cmd)), cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
    text = (cwd/log).read_text(errors='replace')
    if result.returncode or re.search(r'\*\*\s*(Error|Fatal)', text):
        raise RuntimeError(f'{log}: {text[-4000:]}')
    return text


def main():
    p = argparse.ArgumentParser()
    p.add_argument('kind', choices=['lockstep', 'benchmark', 'profile', 'shifters', 'shift_program', 'branch_eq', 'traps'])
    p.add_argument('--name', required=True)
    p.add_argument('--image', type=Path, default=ROOT/'firmware/image')
    p.add_argument('--cycles', type=int, default=1000000)
    p.add_argument('--modelsim', type=Path, default=Path('D:/modeltech64_10.6e/win64'))
    p.add_argument('--objdump', default='D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-objdump.exe')
    args = p.parse_args()
    images = list(args.image.glob('*.bin'))
    if len(images) != 8:
        raise ValueError('Eight initialization lanes required before simulation')
    out = ROOT/'build'/args.name
    out.mkdir(parents=True, exist_ok=False)
    shutil.copytree(ROOT/'rtl', out/'rtl')
    for image in images:
        shutil.copy2(image, out/image.name)
    profile_args = []
    if args.kind == 'profile':
        start, stop = profile_addresses(args.image/'coremark.elf', args.objdump)
        profile_args = [f'+PROFILE_START={start:08x}', f'+PROFILE_STOP={stop:08x}']
        shutil.copy2(args.image/'coremark.elf', out/'profile.elf')
        (out/'profile_window.json').write_text(json.dumps({'start_pc': hex(start), 'stop_pc': hex(stop),
            'window': 'retirement of first mcycle low read in start_time/stop_time; diagnostic, not the authoritative tick counter'}, indent=2))
    manifest = {f.relative_to(out).as_posix(): hashlib.sha256(f.read_bytes()).hexdigest()
                for f in out.rglob('*') if f.is_file()}
    (out/'inputs.json').write_text(json.dumps(manifest, indent=2))
    ms = args.modelsim
    run([ms/'vlib.exe', 'work'], out, 'vlib.log')
    if args.kind == 'lockstep':
        tb = ROOT/'evidence/baseline/simulation_tb_exact.sv'
        for lib, rtl in [('reference', ROOT/'tests/reference_rtl'), ('replica', out/'rtl')]:
            run([ms/'vlib.exe', lib], out, lib+'_vlib.log')
            # sources.f entries start in rtl/, but rtl already names that folder.
            source_list = ROOT/('tests/reference_sources.f' if lib == 'reference' else 'sources.f')
            files = [rtl/Path(line).relative_to('rtl') for line in source_list.read_text().splitlines()
                     if line and not line.startswith('#') and '/board/' not in line]
            run([ms/'vlog.exe', '-sv', '-work', lib, '+incdir+'+str(rtl/'core'), *files], out, lib+'_compile.log')
        text = tb.read_text().replace('count==1000000', f'count=={args.cycles}')
        # Keep the upstream explicit config binding each DUT to a different library.
        (out/'tb.sv').write_text(text)
        run([ms/'vlog.exe', '-sv', 'tb.sv'], out, 'tb_compile.log')
        top = 'work.exact_config'
    elif args.kind == 'branch_eq':
        shutil.copy2(ROOT/'tests/tb_branch_eq_pipeline.sv', out/'tb.sv')
        run([ms/'vlog.exe', '-sv', out/'rtl/core/execute/branch_eq_pipeline.v', 'tb.sv'], out, 'compile.log')
        top = 'work.tb_branch_eq_pipeline'
    elif args.kind == 'shifters':
        shutil.copy2(ROOT/'evidence/baseline/simulation_tb_shifters.sv', out/'tb.sv')
        run([ms/'vlog.exe', '-sv', *sorted((out/'rtl/core/execute').glob('*.v')), 'tb.sv'], out, 'compile.log')
        top = 'work.tb_shifters'
    else:
        tbname = {'shift_program': 'tb_shift_program', 'profile': 'tb_profile', 'traps': 'tb_traps'}.get(args.kind, 'tb_benchmark')
        shutil.copy2(ROOT/('tests/'+tbname+'.sv'), out/'tb.sv')
        files = [out/line for line in (ROOT/'sources.f').read_text().splitlines()
                 if line and not line.startswith('#') and '/board/' not in line]
        run([ms/'vlog.exe', '-sv', '+incdir+'+str(out/'rtl/core'), *files, 'tb.sv'], out, 'compile.log')
        top = 'work.'+tbname
    acc = ['-voptargs=+acc'] if args.kind == 'lockstep' else []
    text = run([ms/'vsim.exe', '-c', *acc, top, f'+MAX_CYCLES={args.cycles}', *profile_args, '-do',
                'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'], out, 'simulate.log')
    result = validate_result(args.kind, text)
    (out/'validation.json').write_text(json.dumps(result, indent=2))
    print(text[-1800:])


if __name__ == '__main__':
    main()
