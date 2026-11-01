"""Compare initialized 64-bit RAM byte lanes with every ELF PT_LOAD file byte."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def compare_bytes(expected, actual, address):
    if expected != actual:
        index = next((i for i, pair in enumerate(zip(expected, actual)) if pair[0] != pair[1]),
                     min(len(expected), len(actual)))
        raise ValueError(f'ELF/RAM image mismatch at 0x{address+index:08x}')


def verify(elf, directory):
    elf, directory = Path(elf), Path(directory)
    data = elf.read_bytes()
    if data[:7] != b'\x7fELF\x01\x01\x01':
        raise ValueError('ELF32 little-endian executable required')
    phoff = struct.unpack_from('<I', data, 28)[0]
    phentsize, phnum = struct.unpack_from('<HH', data, 42)
    lanes = []
    for i in range(8):
        candidates = list(directory.glob(f'MicroSoc.v_*_symbol{i}.bin'))
        if len(candidates) != 1:
            raise ValueError(f'exactly one RAM initialization file for byte lane {i} required')
        lanes.append(bytes(int(line, 2) for line in candidates[0].read_text().splitlines()))
    if len({len(x) for x in lanes}) != 1 or len(lanes[0]) != 8192:
        raise ValueError('expected eight 8192-byte lanes for 64KiB RAM')
    ram = bytes(lanes[i % 8][i // 8] for i in range(65536))
    checked = 0
    for i in range(phnum):
        kind, offset, vaddr, paddr, size, memsize, flags, align = struct.unpack_from('<8I', data, phoff+i*phentsize)
        if kind != 1 or not size:
            continue
        start = paddr-0x80000000
        if start < 0 or start+memsize > len(ram):
            raise ValueError('ELF segment exceeds RAM')
        compare_bytes(data[offset:offset+size], ram[start:start+size], paddr)
        checked += size
    if not checked:
        raise ValueError('ELF has no initialized load segment')
    return {'checked_bytes':checked, 'ram_bytes':len(ram),
            'elf_sha256':hashlib.sha256(data).hexdigest(),
            'ram_sha256':hashlib.sha256(ram).hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.elf,args.directory), indent=2))
