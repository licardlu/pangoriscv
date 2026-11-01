"""Build a separate trap diagnostic image. Never overwrites the CoreMark image."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

from verify_image import verify

ROOT = Path(__file__).resolve().parents[1]


def build(out, prefix):
    out = Path(out).resolve()
    # In particular, do not let an output argument target firmware/image.
    if out == ROOT/'firmware/image' or out.is_relative_to(ROOT/'firmware/image'):
        raise ValueError('CoreMark image is frozen; choose a separate diagnostic directory')
    out.mkdir(parents=True, exist_ok=False)
    source = ROOT/'firmware/diagnostics'
    inputs = [source/'start.S', source/'trap_test.c', ROOT/'firmware/source/port/link.ld']
    cmd = [prefix+'-gcc.exe', '-O2', '-Wall', '-Wextra', '-Werror',
           '-march=rv32imc_zicsr_zifencei', '-mabi=ilp32', '-fno-builtin',
           '-nostdlib', '-nostartfiles', '-ffreestanding', '-Wl,--no-relax',
           '-T', str(inputs[2]), str(inputs[0]), str(inputs[1]),
           '-Wl,-Map='+str(out/'diagnostics.map'), '-o', str(out/'diagnostics.elf')]
    result = subprocess.run(cmd, capture_output=True, text=True)
    (out/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr)
    symbols = subprocess.check_output([prefix+'-nm.exe', str(out/'diagnostics.elf')], text=True)
    trap_address = int(next(line.split()[0] for line in symbols.splitlines()
                            if line.endswith(' diag_trap_entry')), 16)
    if trap_address & 3:
        raise ValueError('mtvec direct entry must be four-byte aligned')
    data = (out/'diagnostics.elf').read_bytes()
    ram = bytearray(65536)
    off = struct.unpack_from('<I', data, 28)[0]
    size, count = struct.unpack_from('<HH', data, 42)
    for i in range(count):
        kind, offset, va, pa, n, memsize, flags, align = struct.unpack_from('<8I', data, off+i*size)
        if kind == 1:
            start = pa-0x80000000
            if start < 0 or start+memsize > len(ram):
                raise ValueError('Diagnostic image exceeds RAM')
            ram[start:start+n] = data[offset:offset+n]
    for lane in range(8):
        (out/f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin').write_text(
            ''.join(f'{v:08b}\n' for v in ram[lane::8]), encoding='ascii')
    disassembly = subprocess.check_output([prefix+'-objdump.exe', '-d', str(out/'diagnostics.elf')], text=True)
    (out/'diagnostics.dis').write_text(disassembly)
    record = {'purpose': 'illegal instruction, ECALL, masked/pending CLINT timer, GPR preservation and MRET',
              'command': cmd, 'source_sha256': {p.relative_to(ROOT).as_posix():
              hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
              'image': verify(out/'diagnostics.elf', out), 'board_verified': False}
    (out/'diagnostics.json').write_text(json.dumps(record, indent=2))
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--prefix', default='D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf')
    a = p.parse_args()
    build(a.out, a.prefix)
