"""Generate test vectors for the conv3x3 RTL from the bit-exact reference.

K-slice layout: 8 consecutive taps of the flattened (tap-major, channel-minor)
K dimension, k = tap * CIN + c, tap = ky*3 + kx.  A dot product is order
independent, so the RTL only needs a[k] paired with w[oc][k].

Patterns are chosen to hit paths that random data can miss:
    rand      normal distribution
    zero      all-zero input and weights  -> M == 0, exercises the degenerate scale
    extreme   activations at +-127        -> accumulator magnitude
    sat       large weights               -> clip and the -128 clamp
    neg       all-negative activations    -> the leaky branch only

Usage: python gen_vectors.py --cin 8 --cout 8 --h 4 --w 4 --pattern rand --out vec
"""

from __future__ import annotations

import argparse
import os

import numpy as np

from fixed_ref import (S_SHIFT, _rescale, compute_m, leaky_int8,
                       quant_per_channel, quant_per_tensor)


def pack_bytes(vals) -> int:
    """Little-endian byte packing, matching a_bus[k*8 +: 8]."""
    out = 0
    for i, v in enumerate(vals):
        out |= (int(v) & 0xFF) << (8 * i)
    return out


def make_inputs(cin, cout, h, w, pattern, rng):
    if pattern == "rand":
        xf = rng.standard_normal((h, w, cin)).astype(np.float32)
        wf = (rng.standard_normal((cout, cin, 3, 3)) * 0.15).astype(np.float32)
    elif pattern == "zero":
        xf = np.zeros((h, w, cin), dtype=np.float32)
        wf = np.zeros((cout, cin, 3, 3), dtype=np.float32)
    elif pattern == "extreme":
        xf = rng.choice([-1.0, 1.0], size=(h, w, cin)).astype(np.float32)
        wf = (rng.choice([-1.0, 1.0], size=(cout, cin, 3, 3)) * 0.5).astype(np.float32)
    elif pattern == "sat":
        xf = rng.standard_normal((h, w, cin)).astype(np.float32)
        wf = (rng.standard_normal((cout, cin, 3, 3)) * 4.0).astype(np.float32)
    elif pattern == "neg":
        xf = -np.abs(rng.standard_normal((h, w, cin))).astype(np.float32)
        wf = (rng.standard_normal((cout, cin, 3, 3)) * 0.15).astype(np.float32)
    else:
        raise ValueError(pattern)
    return xf, wf


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cin", type=int, default=8)
    ap.add_argument("--cout", type=int, default=8)
    ap.add_argument("--h", type=int, default=4)
    ap.add_argument("--w", type=int, default=4)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--pattern", default="rand")
    ap.add_argument("--out", default="vec")
    a = ap.parse_args()

    cin, cout, h, w = a.cin, a.cout, a.h, a.w
    assert cin % 8 == 0, "CIN must be a multiple of 8 (K-slice granularity)"
    outdir = a.out
    os.makedirs(outdir, exist_ok=True)

    rng = np.random.default_rng(a.seed)
    xf, wf = make_inputs(cin, cout, h, w, a.pattern, rng)
    bf = (rng.standard_normal(cout) * 0.05).astype(np.float32)

    xq, s_x = quant_per_tensor(xf)
    wq, s_w = quant_per_channel(wf)

    # float reference, to choose the output scale exactly as calibration would
    xp = np.pad(xf, ((1, 1), (1, 1), (0, 0)))
    acc_f = np.zeros((h, w, cout), dtype=np.float32)
    for ky in range(3):
        for kx in range(3):
            acc_f += xp[ky:ky + h, kx:kx + w, :] @ wf[:, :, ky, kx].T
    acc_f += bf[None, None, :]
    y_ref = np.where(acc_f < 0, acc_f * 0.125, acc_f)

    amax = float(np.max(np.abs(y_ref)))
    if amax == 0.0:
        s_y = 1.0            # degenerate: every output is zero, M becomes 0
    else:
        s_y = amax / 127.0
    m = compute_m(s_x, s_w, s_y)

    bias_q = np.rint(bf / (s_x * s_w)).astype(np.int64)

    xqp = np.pad(xq.astype(np.int32), ((1, 1), (1, 1), (0, 0)))
    ks = cin * 9 // 8

    # Weight layout MUST match the activation packing: k = tap*CIN + c, i.e.
    # tap-major.  numpy's default reshape of (cout,cin,3,3) gives c*9+tap
    # (channel-major), which silently pairs every activation with the wrong
    # weight while still letting RTL match an equally wrong reference.
    wflat = wq.transpose(0, 2, 3, 1).reshape(cout, -1)

    stim, gold = [], []
    for oy in range(h):
        for ox in range(w):
            act = np.zeros(cin * 9, dtype=np.int32)
            for ky in range(3):
                for kx in range(3):
                    tap = ky * 3 + kx
                    act[tap * cin:(tap + 1) * cin] = xqp[oy + ky, ox + kx, :]
            acc = np.zeros(cout, dtype=np.int32)
            for s in range(ks):
                sl = act[s * 8:(s + 1) * 8]
                wl = np.zeros((cout, 8), dtype=np.int32)
                wl[:, :] = wflat[:, s * 8:(s + 1) * 8]
                acc += (wl @ sl)
                stim.append((pack_bytes(sl), pack_bytes(wl.reshape(-1))))
            acc += bias_q.astype(np.int32)
            y = _rescale(acc.reshape(1, 1, cout), m)[0, 0]
            y = leaky_int8(np.clip(y, -128, 127).astype(np.int8))
            gold.append(pack_bytes(y))

    with open(os.path.join(outdir, "cfg.txt"), "w") as f:
        f.write(f"{cin} {cout} {S_SHIFT} {h*w} {ks}\n")
    with open(os.path.join(outdir, "bias.txt"), "w") as f:
        f.write("\n".join(str(int(v)) for v in bias_q) + "\n")
    with open(os.path.join(outdir, "m.txt"), "w") as f:
        f.write("\n".join(str(int(v)) for v in m) + "\n")
    with open(os.path.join(outdir, "stim.txt"), "w") as f:
        for ab, wb in stim:
            f.write(f"{ab:016x} {wb:0{cout*16}x}\n")
    with open(os.path.join(outdir, "gold.txt"), "w") as f:
        for y in gold:
            f.write(f"{y:016x}\n")

    # sanity: the int8 result must still resemble the true float convolution.
    # A wrong k-ordering pairs each activation with the wrong weight and the
    # cosine collapses, which is how this bug is caught.
    gq = np.array([[float(int.from_bytes(bytes([(g >> (8*i)) & 0xFF]), 'little', signed=True))
                    for i in range(cout)] for g in gold], dtype=np.float64) * s_y
    rf = y_ref.reshape(-1).astype(np.float64)
    gv = gq.reshape(-1)
    cos = float(rf @ gv / (np.linalg.norm(rf) * np.linalg.norm(gv) + 1e-12))
    if cos < 0.99:
        raise SystemExit(f"reference is inconsistent: cosine {cos:.4f} < 0.99")

    nsat = int(np.sum(np.abs(np.array([int.from_bytes(bytes([(g >> (8*i)) & 0xFF]), 'little', signed=True)
                                       for g in gold for i in range(cout)], dtype=np.int32)) == 127))
    print(f"pattern={a.pattern} cin={cin} cout={cout} {h}x{w} "
          f"s_x={s_x:.5f} s_y={s_y:.5f} M0={int(m[0])} sat={nsat}")


if __name__ == "__main__":
    main()
