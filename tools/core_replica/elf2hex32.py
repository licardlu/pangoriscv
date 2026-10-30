#!/usr/bin/env python3
"""把 objcopy 出来的裸二进制转成 32 位字表 (V1 主存 16384 x 32 用)。

V2 起主存改成 8192 x 64 位, 那个版本在 elf2hex64.py。两份分开保留, 是因为
V1 是已上板交付的基线, 它的镜像格式不能跟着 V2 改。

用法: elf2hex32.py <input.bin> <output.hex> [depth_words]
"""
import struct
import sys


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    depth = int(sys.argv[3]) if len(sys.argv) > 3 else 16384

    with open(src, "rb") as f:
        data = f.read()

    if len(data) > depth * 4:
        print(f"ERROR: image {len(data)} bytes exceeds {depth*4}")
        return 1

    words = [0] * depth
    for i in range(0, len(data), 4):
        chunk = data[i:i + 4]
        if len(chunk) < 4:
            chunk = chunk + b"\x00" * (4 - len(chunk))
        words[i // 4] = struct.unpack("<I", chunk)[0]

    with open(dst, "w", newline="\n") as f:
        for w in words:
            f.write("%08x\n" % w)

    print(f"wrote {dst}: {depth} words x 32bit, image {len(data)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
