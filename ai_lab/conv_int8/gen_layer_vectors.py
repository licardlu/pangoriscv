"""Whole-layer vectors for conv3x3_layer: one real Lite-A layer, full tensor.

Layer 2 of Lite-A at 128 input: 64x64, CIN=8, COUT=16.  It is the first layer
whose input channels fill a K-slice exactly, so it exercises the real datapath
without any padding tricks.

Files written to <outdir>/:
    cfg.txt   "CIN COUT W H S"
    bias.txt  COUT signed decimals
    m.txt     COUT signed decimals
    in.hex    W*H*CIN bytes, "hh" per line, layout [y][x][c]
    w.hex     COUT*CIN*9 bytes, layout [oc][tap][c]  (tap-major, matches RTL)
    gold.hex  W*H*COUT bytes, layout [y][x][oc]
"""

from __future__ import annotations

import argparse
import os

import numpy as np

from fixed_ref import (S_SHIFT, _rescale, compute_m, leaky_int8,
                       quant_per_channel, quant_per_tensor)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cin", type=int, default=8)
    ap.add_argument("--cout", type=int, default=16)
    ap.add_argument("--w", type=int, default=64)
    ap.add_argument("--h", type=int, default=64)
    ap.add_argument("--seed", type=int, default=101)
    ap.add_argument("--out", default="layer")
    a = ap.parse_args()
    cin, cout, W, H = a.cin, a.cout, a.w, a.h
    os.makedirs(a.out, exist_ok=True)

    rng = np.random.default_rng(a.seed)
    xf = rng.standard_normal((H, W, cin)).astype(np.float32)
    wf = (rng.standard_normal((cout, cin, 3, 3)) * 0.12).astype(np.float32)
    bf = (rng.standard_normal(cout) * 0.05).astype(np.float32)

    xq, s_x = quant_per_tensor(xf)
    wq, s_w = quant_per_channel(wf)

    # true float convolution, padding 1
    xp = np.pad(xf, ((1, 1), (1, 1), (0, 0)))
    acc_f = np.zeros((H, W, cout), dtype=np.float32)
    for ky in range(3):
        for kx in range(3):
            acc_f += xp[ky:ky + H, kx:kx + W, :] @ wf[:, :, ky, kx].T
    acc_f += bf[None, None, :]
    y_ref = np.where(acc_f < 0, acc_f * 0.125, acc_f)
    s_y = float(np.max(np.abs(y_ref))) / 127.0
    m = compute_m(s_x, s_w, s_y)
    bias_q = np.rint(bf / (s_x * s_w)).astype(np.int64)

    # tap-major weight view: k = tap*CIN + c
    wflat = wq.transpose(0, 2, 3, 1).reshape(cout, -1)   # (cout, cin*9)

    xqp = np.pad(xq.astype(np.int32), ((1, 1), (1, 1), (0, 0)))
    out = np.zeros((H, W, cout), dtype=np.int8)
    for oy in range(H):
        for ox in range(W):
            act = np.zeros(cin * 9, dtype=np.int32)
            for ky in range(3):
                for kx in range(3):
                    tap = ky * 3 + kx
                    act[tap * cin:(tap + 1) * cin] = xqp[oy + ky, ox + kx, :]
            acc = wflat.astype(np.int32) @ act + bias_q.astype(np.int32)
            y = _rescale(acc.reshape(1, 1, cout), m)[0, 0]
            out[oy, ox, :] = leaky_int8(np.clip(y, -128, 127).astype(np.int8))

    with open(os.path.join(a.out, "cfg.txt"), "w") as f:
        f.write(f"{cin} {cout} {W} {H} {S_SHIFT}\n")
    with open(os.path.join(a.out, "bias.txt"), "w") as f:
        f.write("\n".join(str(int(v)) for v in bias_q) + "\n")
    with open(os.path.join(a.out, "m.txt"), "w") as f:
        f.write("\n".join(str(int(v)) for v in m) + "\n")
    with open(os.path.join(a.out, "bias.hex"), "w") as f:
        f.write("\n".join(f"{int(v) & 0xFFFFFFFF:08x}" for v in bias_q) + "\n")
    with open(os.path.join(a.out, "m.hex"), "w") as f:
        f.write("\n".join(f"{int(v) & 0xFFFFFFFF:08x}" for v in m) + "\n")
    with open(os.path.join(a.out, "in.hex"), "w") as f:
        f.write("\n".join(f"{int(b) & 0xFF:02x}" for b in xq.reshape(-1)) + "\n")
    with open(os.path.join(a.out, "w.hex"), "w") as f:
        f.write("\n".join(f"{int(b) & 0xFF:02x}" for b in wflat.reshape(-1)) + "\n")
    with open(os.path.join(a.out, "gold.hex"), "w") as f:
        f.write("\n".join(f"{int(b) & 0xFF:02x}" for b in out.reshape(-1)) + "\n")

    gq = out.reshape(-1).astype(np.float64) * s_y
    rf = y_ref.reshape(-1).astype(np.float64)
    cos = float(rf @ gq / (np.linalg.norm(rf) * np.linalg.norm(gq) + 1e-12))
    print(f"layer {H}x{W} cin={cin} cout={cout}: {H*W*cout} output bytes, "
          f"s_x={s_x:.5f} s_y={s_y:.5f} cos={cos:.5f}")
    if cos < 0.99:
        raise SystemExit("reference inconsistent with the true convolution")


if __name__ == "__main__":
    main()
