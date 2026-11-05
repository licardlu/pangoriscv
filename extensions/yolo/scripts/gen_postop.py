"""Generate DDR image + expected output for postop_engine.

Covers the four operators the model needs, on small tensors so the comparison is
exhaustive.  Layouts are channel-last [y][x][c] with c padded to C (multiple of
8), the same layout conv_band_engine consumes.
"""
import argparse
import json
import sys
import types
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--op", type=int, required=True, help="0 maxpool 1 upsample 2 concat 3 add")
    ap.add_argument("--h", type=int, default=8)
    ap.add_argument("--w", type=int, default=8)
    ap.add_argument("--c", type=int, default=8)
    ap.add_argument("--k", type=int, default=3)
    ap.add_argument("--stride", type=int, default=1)
    ap.add_argument("--ca", type=int, default=8)
    ap.add_argument("--seed", type=int, default=11)
    ap.add_argument("--tag", default="t")
    a = ap.parse_args()

    rng = np.random.default_rng(a.seed)
    C, H, W = a.c, a.h, a.w
    pad = a.k // 2

    if a.op == 0:
        OH = (H + 2 * pad - a.k) // a.stride + 1
        OW = (W + 2 * pad - a.k) // a.stride + 1
        A = rng.integers(-128, 128, size=(H, W, C), dtype=np.int16)
        xp = np.full((H + 2 * pad, W + 2 * pad, C), -128, np.int16)
        xp[pad:pad + H, pad:pad + W] = A
        Y = np.full((OH, OW, C), -128, np.int16)
        for y in range(OH):
            for x in range(OW):
                blk = xp[y * a.stride:y * a.stride + a.k,
                         x * a.stride:x * a.stride + a.k, :]
                Y[y, x] = blk.max(axis=(0, 1))
        Bn = None
    elif a.op == 1:
        OH, OW = H * 2, W * 2
        A = rng.integers(-128, 128, size=(H, W, C), dtype=np.int16)
        Y = np.repeat(np.repeat(A, 2, axis=0), 2, axis=1)
        Bn = None
    elif a.op == 2:
        assert 0 < a.ca < C and a.ca % 8 == 0
        OH, OW = H, W
        A = rng.integers(-128, 128, size=(H, W, C), dtype=np.int16)
        Bn = rng.integers(-128, 128, size=(H, W, C - a.ca), dtype=np.int16)
        Y = np.concatenate([A[:, :, :a.ca], Bn], axis=2)
    else:
        OH, OW = H, W
        A = rng.integers(-128, 128, size=(H, W, C), dtype=np.int16)
        Bn = rng.integers(-128, 128, size=(H, W, C), dtype=np.int16)
        Y = np.clip(A + Bn, -128, 127)

    def as_bytes(t):
        return (t.reshape(-1) & 0xFF).astype(np.uint8).tobytes()

    A_BASE = 0x0000
    B_BASE = 0x10000
    Y_BASE = 0x20000
    total = Y_BASE + Y.size
    memw = (total + 7) // 8 + 8

    mem = bytearray(memw * 8)
    mem[A_BASE:A_BASE + len(as_bytes(A))] = as_bytes(A)
    if Bn is not None:
        mem[B_BASE:B_BASE + len(as_bytes(Bn))] = as_bytes(Bn)
    # output region stays zero: a pre-filled region would make "no write" pass

    gen = ROOT / "gen"
    gen.mkdir(exist_ok=True)
    words = ["%016x" % int.from_bytes(mem[i * 8:i * 8 + 8], "little")
             for i in range(memw)]
    (gen / ("post_ddr_%s.hex" % a.tag)).write_text("\n".join(words) + "\n", encoding="ascii")

    ys = Y.size
    yb = as_bytes(Y)
    ewords = ["%016x" % int.from_bytes(yb[i:i + 8], "little")
              for i in range(0, ys, 8)]
    (gen / ("post_exp_%s.hex" % a.tag)).write_text("\n".join(ewords) + "\n", encoding="ascii")

    hdr = ('''localparam integer Q_OP=%d, Q_C=%d, Q_IN_W=%d, Q_IN_H=%d, Q_K=%d, Q_STRIDE=%d, Q_CA=%d;
localparam integer Q_OH=%d, Q_OW=%d, Q_MEMW=%d, Q_NOUT=%d;
`define Q_DDR "%s"
`define Q_EXP "%s"
localparam [31:0] Q_A_BASE=32'h%08x, Q_B_BASE=32'h%08x, Q_Y_BASE=32'h%08x;
''' % (a.op, C, W, H, a.k, a.stride, a.ca, OH, OW, memw, ys // 8,
       (gen / ("post_ddr_%s.hex" % a.tag)).as_posix(),
       (gen / ("post_exp_%s.hex" % a.tag)).as_posix(),
       A_BASE, B_BASE, Y_BASE))
    (gen / "post_params.vh").write_text(hdr, encoding="ascii")
    (gen / ("post_meta_%s.json" % a.tag)).write_text(json.dumps(
        dict(op=a.op, out=[OH, OW, C], out_bytes=ys, memw=memw), indent=1), encoding="utf-8")
    print("op=%d out=%dx%dx%d bytes=%d memw=%d" % (a.op, OH, OW, C, ys, memw))


if __name__ == "__main__":
    main()
