
No command in this script programs or probes a physical board.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROFILE = json.loads((ROOT / 'platform/profile.json').read_text(encoding='utf-8'))
CONFIG = ROOT / 'tools/local-tools.json'
TOOLS = json.loads(CONFIG.read_text(encoding='utf-8-sig')) if CONFIG.exists() else {}


def run(command, cwd, log):
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open('w', encoding='utf-8') as out:
        out.write('COMMAND: ' + subprocess.list2cmdline(list(map(str, command))) + '\n')
        out.flush()
        proc = subprocess.run(list(map(str, command)), cwd=cwd, stdout=out, stderr=subprocess.STDOUT)
    if proc.returncode:
        print(log.read_text(encoding='utf-8', errors='replace')[-6000:])
        raise RuntimeError(f'command failed ({proc.returncode}): {log}')
    return log.read_text(encoding='utf-8', errors='replace')


def firmware(iterations, optimization='-O2'):
    output = ROOT / 'build' / f'firmware_{iterations}'
    output.mkdir(parents=True, exist_ok=True)
    prefix = TOOLS.get('gcc_prefix', os.environ.get('RISCV_PREFIX', 'riscv32-unknown-elf'))
    exe = '.exe' if os.name == 'nt' else ''
    flags = [optimization, '-fno-common', '-funroll-loops', '-finline-functions',
             '-funroll-all-loops', '-falign-functions=8', '-falign-jumps=8', '-falign-loops=8',
             '-finline-limit=1000', '-mtune=sifive-7-series', '-ffast-math',
             '-fno-tree-loop-distribute-patterns', '--param=fsm-scale-path-stmts=3',
             '-march=rv32imc_zicsr_zifencei', '-mabi=ilp32', '-fno-builtin']
    (output / 'compiler_flags.h').write_text('#define COMPILER_FLAGS ' + json.dumps(' '.join(flags)) + '\n')
    cfiles = [ROOT / 'firmware/coremark' / x for x in
              ['core_main.c', 'core_list_join.c', 'core_matrix.c', 'core_state.c', 'core_util.c']]
    command = [prefix+'-gcc'+exe, *flags, '-nostdlib', '-nostartfiles', '-ffreestanding',
               f'-DITERATIONS={iterations}', '-DPERFORMANCE_RUN=1', '-include', output/'compiler_flags.h',
               '-I'+str(ROOT/'firmware/port'), '-I'+str(ROOT/'firmware/coremark'),
               '-T'+str(ROOT/'firmware/port/link.ld'), '-Wl,-Map='+str(output/'coremark.map'),
               *cfiles, ROOT/'firmware/port/core_portme.c', ROOT/'firmware/port/ee_printf.c',
               ROOT/'firmware/port/start.S', '-lgcc', '-o', output/'coremark.elf']
    run(command, ROOT, output/'compile.log')
    run([prefix+'-size'+exe, output/'coremark.elf'], ROOT, output/'size.log')
    run([prefix+'-objdump'+exe, '-d', output/'coremark.elf'], ROOT, output/'coremark.dis')
    (output/'manifest.json').write_text(json.dumps({
        'iterations': iterations, 'cpu_hz': PROFILE['cpu_hz'], 'flags': flags,
        'elf_sha256': hashlib.sha256((output/'coremark.elf').read_bytes()).hexdigest()
    }, indent=2))
    print((output/'size.log').read_text())


def generate(iterations, name, extra):
    output = ROOT / 'build' / ('gen_' + name)
    output.mkdir(parents=True, exist_ok=False)
    args = [*PROFILE['generator_args'], '--ram-elf='+str(ROOT/'build'/f'firmware_{iterations}/coremark.elf'), *extra]
    java = TOOLS.get('java', os.environ.get('JAVA', 'java'))
    runtime = ROOT/'tools/runtime/classpath.json'
    classpath = TOOLS.get('classpath')
    if runtime.exists():
        classpath = os.pathsep.join(str(ROOT/f) for f in json.loads(runtime.read_text()))
    if classpath:
        cmd = [java, '-Xmx4G', '-Xss16M', '-cp', classpath,
               'vexiiriscv.soc.micro.MicroSocGen', *args]
        run(cmd, output, output/'generate.log')
    else:
        upstream = ROOT/'upstream/VexiiRiscv'
        sbt = TOOLS.get('sbt', 'sbt.bat' if os.name == 'nt' else 'sbt')
        run([sbt, 'runMain vexiiriscv.soc.micro.MicroSocGen '+subprocess.list2cmdline(args)],
            upstream, output/'generate.log')
        for item in [*upstream.glob('MicroSoc.v'), *upstream.glob('*.bin')]:
            shutil.copy2(item, output/item.name)
    (output/'generation.json').write_text(json.dumps({'args':args, 'profile':PROFILE}, indent=2))
    for item in [*output.glob('MicroSoc.v'), *output.glob('*.bin')]:
        shutil.copy2(item, ROOT/'rtl/generated'/item.name)
    print('Generated:', output)


def simulate(name, cycles):
    output = ROOT/'build'/('sim_'+name)
    output.mkdir(parents=True, exist_ok=False)
    ms = Path(TOOLS.get('modelsim', os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64')))
    for f in (ROOT/'rtl/generated').glob('*.bin'):
        shutil.copy2(f, output/f.name)
    run([ms/'vlib.exe', 'work'], output, output/'vlib.log')
    run([ms/'vlog.exe', '-sv', ROOT/'rtl/generated/MicroSoc.v', ROOT/'tb/tb_soc.sv'], output, output/'compile.log')
    text = run([ms/'vsim.exe', '-c', 'work.tb_soc', f'+MAX_CYCLES={cycles}', '-do',
                'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'], output, output/'simulate.log')
    if 'TEST_PASS soc_coremark' not in text:
        raise RuntimeError('missing explicit test pass marker')
    print('RTL boot/CRC/completion test passed:', output)


def implement(name):
    output = ROOT/'build'/name
    output.mkdir(parents=True, exist_ok=False)
    os.environ['VEXII_ROOT'] = str(ROOT)
    pds = TOOLS.get('pds', os.environ.get('PDS_SHELL', 'D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe'))
    text = run([pds, '-file', ROOT/'platform/build.tcl', '-work_dir', output, '-project_name', 'pango_vexii'],
               output, output/'pds.log')
    if 'BUILD_FLOW_COMPLETE' not in text:
        raise RuntimeError('PDS did not finish')
    print('PDS flow finished; inspect final timing before claiming closure:', output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['firmware','generate','simulate','implement'])
    parser.add_argument('--iterations', type=int, default=PROFILE['iterations'])
    parser.add_argument('--name', default='trial')
    parser.add_argument('--cycles', type=int, default=40_000_000)
    parser.add_argument('--optimization', default='-O2')
    opts, extra = parser.parse_known_args()
    if opts.iterations <= 0 or opts.cycles <= 0:
        parser.error('iterations/cycles must be positive')
    if opts.stage == 'firmware': firmware(opts.iterations, opts.optimization)
    if opts.stage == 'generate': generate(opts.iterations, opts.name, extra)
    if opts.stage == 'simulate': simulate(opts.name, opts.cycles)
    if opts.stage == 'implement': implement(opts.name)