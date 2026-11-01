#!/usr/bin/env python3
"""把 objcopy 出来的裸二进制转成 $readmemh 能吃的 64 位小端字表。

V2 起主存改成 8192 x 64 位 (取指一拍 8 字节, 能切两条指令)。
字节序仍然是 RISC-V 的小端: 低地址字节在字的低位。

用法: elf2hex.py <input.bin> <output.hex> [depth_words]
"""
import struct
import sys


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    depth = int(sys.argv[3]) if len(sys.argv) > 3 else 8192

    with open(src, "rb") as f:
        data = f.read()

    if len(data) > depth * 8:
        print(f"ERROR: image {len(data)} bytes exceeds {depth*8}")
        return 1

    words = [0] * depth
    for i in range(0, len(data), 8):
        chunk = data[i:i + 8]
        if len(chunk) < 8:
            chunk = chunk + b"\x00" * (8 - len(chunk))
        words[i // 8] = struct.unpack("<Q", chunk)[0]

    with open(dst, "w", newline="\n") as f:
        for w in words:
            f.write("%016x\n" % w)

    print(f"wrote {dst}: {depth} words x 64bit, image {len(data)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
