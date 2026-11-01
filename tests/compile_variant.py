"""Build untouched CoreMark using a controlled compiler-option experiment."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--name',required=True)
    p.add_argument('--optimization',choices=['-O2','-O3','-Os'],default='-O3')
    p.add_argument('--tune',default='sifive-7-series')
    p.add_argument('--iterations',type=int,default=7000)
    p.add_argument('--extra',action='append',default=[])
    p.add_argument('--prefix',default='D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf')
    a=p.parse_args();out=ROOT/'build'/a.name;out.mkdir(parents=True,exist_ok=False)
    flags=[a.optimization,'-fno-common','-funroll-loops','-finline-functions','-funroll-all-loops',
      '-falign-functions=8','-falign-jumps=8','-falign-loops=8','-finline-limit=1000',
      '-mtune='+a.tune,'-ffast-math','-fno-tree-loop-distribute-patterns',
      '--param=fsm-scale-path-stmts=3','-march=rv32imc_zicsr_zifencei','-mabi=ilp32','-fno-builtin']
    flags += a.extra
    (out/'compiler_flags.h').write_text('#define COMPILER_FLAGS '+json.dumps(' '.join(flags))+'\n')
    core=ROOT/'firmware/source/coremark';port=ROOT/'firmware/source/port'
    sources=[core/n for n in ['core_main.c','core_list_join.c','core_matrix.c','core_state.c','core_util.c']]
    sources += [port/n for n in ['core_portme.c','ee_printf.c','start.S']]
    cmd=[a.prefix+'-gcc.exe',*flags,'-nostdlib','-nostartfiles','-ffreestanding',
      f'-DITERATIONS={a.iterations}','-DPERFORMANCE_RUN=1','-include',out/'compiler_flags.h',
      '-I'+str(port),'-I'+str(core),'-T'+str(port/'link.ld'),
      '-Wl,-Map='+str(out/'coremark.map'),*sources,'-lgcc','-o',out/'coremark.elf']
    result=subprocess.run(list(map(str,cmd)),capture_output=True,text=True)
    (out/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise RuntimeError(result.stderr)
    (out/'manifest.json').write_text(json.dumps({'flags':flags,'iterations':a.iterations,
      'source_sha256':{s.relative_to(ROOT).as_posix():hashlib.sha256(s.read_bytes()).hexdigest() for s in sources},
      'command':list(map(str,cmd)),'elf_sha256':hashlib.sha256((out/'coremark.elf').read_bytes()).hexdigest()},indent=2))
    print(subprocess.check_output([a.prefix+'-size.exe',str(out/'coremark.elf')],text=True))


if __name__=='__main__':main()
