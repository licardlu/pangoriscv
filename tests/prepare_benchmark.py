"""Test fixture: produce short runs by changing only volatile iteration data.

Never alters CoreMark algorithm/input/CRC/timing code. Tests use the same .text
as the full release. Outputs are diagnostic simulation images, not board results.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from verify_image import verify


def sections(data):
    off=struct.unpack_from('<I',data,32)[0]
    size,count,index=struct.unpack_from('<HHH',data,46)
    headers=[struct.unpack_from('<10I',data,off+i*size) for i in range(count)]
    strings=headers[index]
    names=data[strings[4]:strings[4]+strings[5]]
    return {names[h[0]:].split(b'\0')[0].decode():h for h in headers}


def prepare(elf, count, out, nm):
    out.mkdir(parents=True,exist_ok=False)
    data=bytearray(elf.read_bytes())
    symbols=subprocess.check_output([nm,str(elf)],text=True)
    address=int(next(l.split()[0] for l in symbols.splitlines() if l.endswith(' seed4_volatile')),16)
    phoff=struct.unpack_from('<I',data,28)[0]
    ents,n=struct.unpack_from('<HH',data,42)
    ram=bytearray(65536)
    patched=False
    for i in range(n):
        kind,offset,va,pa,size,memsize,flags,align=struct.unpack_from('<8I',data,phoff+i*ents)
        if kind!=1:continue
        if pa<=address<pa+size:
            struct.pack_into('<I',data,offset+address-pa,count);patched=True
    assert patched
    for i in range(n):
        kind,offset,va,pa,size,memsize,flags,align=struct.unpack_from('<8I',data,phoff+i*ents)
        if kind!=1:continue
        start=pa-0x80000000
        assert start>=0 and start+memsize<=len(ram)
        ram[start:start+size]=data[offset:offset+size]
    original=elf.read_bytes(); sec=sections(original)['.text']
    assert original[sec[4]:sec[4]+sec[5]]==data[sec[4]:sec[4]+sec[5]]
    (out/'coremark.elf').write_bytes(data)
    for lane in range(8):
        (out/f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin').write_text(
            ''.join(f'{v:08b}\n' for v in ram[lane::8]),encoding='ascii')
    result={'iterations':count,'text_sha256':hashlib.sha256(data[sec[4]:sec[4]+sec[5]]).hexdigest(),
            'source_elf_sha256':hashlib.sha256(original).hexdigest(),
            'patched_data_address':hex(address),'image':verify(out/'coremark.elf',out)}
    (out/'diagnostic.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result,indent=2))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--elf',type=Path,default=ROOT/'firmware/image/coremark.elf')
    p.add_argument('--iterations',type=int,default=100)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--nm',default='D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf-nm.exe')
    a=p.parse_args();prepare(a.elf,a.iterations,a.out,a.nm)
