"""Independent RV32/RVC shift/forwarding/branch regression with Python oracle."""
import json
from pathlib import Path
import random
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[1]
PREFIX='D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf'


def main():
    out=ROOT/'build/shift_program';out.mkdir(parents=True,exist_ok=False)
    rng=random.Random(20261030)
    values=[0,1,0xffffffff,0x80000000,0x7fffffff,0xaaaaaaaa,0x55555555]+[rng.getrandbits(32) for _ in range(33)]
    asm=['.section .text.init','.global _start','_start:','li s0,0x10003000','la s1,vectors',f'li s2,{len(values)*32}',
         'loop:','lw t0,0(s1)','lw t1,4(s1)','lw t2,8(s1)','sll t3,t0,t1','bne t2,t3,fail',
         'lw t2,12(s1)','srl t3,t0,t1','bne t2,t3,fail','lw t2,16(s1)','sra t3,t0,t1','bne t2,t3,fail',
         'addi s1,s1,20','addi s2,s2,-1','bnez s2,loop']
    # Both compressed-eligible immediate shifts and full-width instruction forms.
    for value in values[:8]:
        for amount in range(32):
            signed=value if value<0x80000000 else value-(1<<32)
            for op,expected in [('slli',(value<<amount)&0xffffffff),('srli',value>>amount),('srai',(signed>>amount)&0xffffffff)]:
                asm.extend([f'li a0,0x{value:08x}',f'{op} a1,a0,{amount}',f'li t2,0x{expected:08x}','bne a1,t2,fail'])
    asm+=['li t0,0xa5','sw t0,0(s0)','done:','j done','fail:','li t0,0xee','sw t0,0(s0)','j done','.section .rodata','vectors:']
    for value in values:
        for amount in range(32):
            signed=value if value<0x80000000 else value-(1<<32)
            asm.append('.word '+','.join(hex(x) for x in [value,amount|0xffffffe0,(value<<amount)&0xffffffff,value>>amount,(signed>>amount)&0xffffffff]))
    (out/'program.S').write_text('\n'.join(asm)+'\n')
    cmd=[PREFIX+'-gcc.exe','-march=rv32imc_zicsr','-mabi=ilp32','-nostdlib','-nostartfiles','-T',str(ROOT/'firmware/source/port/link.ld'),str(out/'program.S'),'-o',str(out/'program.elf')]
    result=subprocess.run(cmd,capture_output=True,text=True)
    (out/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise RuntimeError(result.stderr)
    data=(out/'program.elf').read_bytes();ram=bytearray(65536)
    off=struct.unpack_from('<I',data,28)[0];size,count=struct.unpack_from('<HH',data,42)
    for i in range(count):
        kind,offset,va,pa,n,memsize,flags,align=struct.unpack_from('<8I',data,off+i*size)
        if kind==1:
            start=pa-0x80000000
            assert start>=0 and start+memsize<=len(ram)
            ram[start:start+n]=data[offset:offset+n]
    for lane in range(8):
        (out/f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin').write_text(''.join(f'{v:08b}\n' for v in ram[lane::8]))
    (out/'vectors.json').write_text(json.dumps({'register_vectors':len(values)*32,'register_shift_checks':len(values)*32*3,
         'immediate_shift_checks':8*32*3,'oracle':'Python fixed-width integer shifts','seed':20261030},indent=2))
    print('Independent shift program image ready')


if __name__=='__main__':main()
