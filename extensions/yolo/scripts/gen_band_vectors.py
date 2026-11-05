"""Generate a DDR image and the expected output for conv_band_engine.

The integer rules here are the contract the RTL must meet, written once in
Python so a discrepancy is always the RTL's fault and never the reference's:

  X_int  = round_away(x_f / s_x)                       per-tensor, clip to int8
  W_int  = round_away(w_f / s_w[oc])                   per output channel
  acc    = bias_i[oc] + sum_{c,ky,kx} X_int * W_int     int32, channel-last
  y_int  = clip(round_away(acc * M[oc] / 2**SHIFT))     round half AWAY FROM ZERO
  out    = act(y_int)                                  0 none, 1 leaky(>>3)

round_away is implemented as sign * floor(|v| + 0.5), which is what the RTL
does after the fix (magnitude first, then sign).  The earlier "add half and
arithmetic-shift" form rounded -0.75 to -1.0 instead of -0.75 -> -1, i.e. it was
round-half-up, not round-half-away.

Layouts (all channel-last, channels padded to a multiple of 8 with zeros):
  input   [y][x][CINPAD]
  weight  [cout][ky][kx][CINPAD]   as 64-bit words
  quant   int32 bias[cout] then int32 M[cout]
  output  [y][x][cout]
"""
import argparse
import json
import sys
import types
from pathlib import Path

# yolov5's checkpoint pickles reference one ultralytics symbol at import time
if "ultralytics" not in sys.modules:
    _u = types.ModuleType("ultralytics")
    _cu = types.ModuleType("ultralytics.utils")
    _ch = types.ModuleType("ultralytics.utils.checks")
    _ch.check_requirements = lambda *a, **k: None
    _u.utils = _cu
    _cu.checks = _ch
    sys.modules.update({"ultralytics": _u, "ultralytics.utils": _cu,
                        "ultralytics.utils.checks": _ch})

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"
SHIFT = 15


def round_away(v):
    v = np.asarray(v, dtype=np.float64)
    return np.trunc(v + np.copysign(0.5, v)).astype(np.int64)


def get_module(model, path):
    obj = model
    for part in path.split("."):
        obj = obj[int(part)] if part.isdigit() else getattr(obj, part)
    return obj


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layer", default=None, help="module path, e.g. model.0.conv")
    ap.add_argument("--shape", default="8,8,8,8,1,1", help="IN_H,IN_W,CIN,COUT,K,STRIDE")
    ap.add_argument("--act", type=int, default=0)
    ap.add_argument("--tr", type=int, default=4)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--tag", default="t")
    a = ap.parse_args()

    rng = np.random.default_rng(a.seed)

    if a.layer:
        import torch
        sd = torch.load(CKPT, map_location="cpu", weights_only=False)
        model = sd["model"].float().eval()
        m = get_module(model, a.layer)
        w = m.weight.detach().numpy().copy()          # [cout][cin][ky][kx]
        b = (m.bias.detach().numpy().copy() if m.bias is not None
             else np.zeros(w.shape[0], np.float32))
        cout, cin, k, _ = w.shape
        stride = int(m.stride[0]) if hasattr(m, "stride") else 1
        w = np.transpose(w, (0, 2, 3, 1))             # [cout][ky][kx][cin]
    else:
        ih, iw, cin, cout, k, stride = [int(t) for t in a.shape.split(",")]
        w = rng.normal(0, 0.08, size=(cout, k, k, cin)).astype(np.float32)
        b = rng.normal(0, 0.05, size=(cout,)).astype(np.float32)
        ih, iw = ih, iw
        # input dims derived from output dims via the layer formula below

    pad_csv = None
    if a.layer:
        # input size and padding come from the exported layer table, not from k//2:
        # model.0.conv is 6x6 stride 2 with pad 2, not 3
        import csv
        rows = {r["module"]: r for r in csv.DictReader((ROOT / "data/layer_table/layers.csv").open())}
        r = rows[a.layer]
        ih, iw = int(r["in_h"]), int(r["in_w"])
        pad_csv = int(r["pad"])
    else:
        pad = k // 2
        oh = (ih + 2 * pad - k) // stride + 1
        ow = (iw + 2 * pad - k) // stride + 1
        ih = (oh - 1) * stride + k - 2 * pad
        iw = (ow - 1) * stride + k - 2 * pad

    pad = k // 2 if pad_csv is None else pad_csv
    oh = (ih + 2 * pad - k) // stride + 1
    ow = (iw + 2 * pad - k) // stride + 1
    cpad = (cin + 7) // 8 * 8

    # ---- float data ------------------------------------------------------
    xf = rng.normal(0, 1.0, size=(ih, iw, cin)).astype(np.float32)

    # ---- quantise --------------------------------------------------------
    sx = max(abs(float(xf.max())), abs(float(xf.min())), 1e-6) / 127.0
    xq = np.clip(round_away(xf / sx), -128, 127).astype(np.int32)

    sw = np.maximum(np.abs(w).reshape(cout, -1).max(1), 1e-6) / 127.0
    wq = np.clip(round_away(w / sw[:, None, None, None]), -128, 127).astype(np.int32)

    bi = round_away(b / (sx * sw)).astype(np.int64)

    # output scale: pick s_y from the accumulator magnitude so the requant
    # multiplier stays inside 32 bits, which is what the hardware holds.
    acc_f = np.zeros((oh, ow, cout), np.float32)
    xp = np.pad(xf, ((pad, pad), (pad, pad), (0, 0)))
    for ky in range(k):
        for kx in range(k):
            xs = xp[ky:ky + (oh - 1) * stride + 1:stride, kx:kx + (ow - 1) * stride + 1:stride, :]
            acc_f += xs @ w[:, ky, kx, :].T
    acc_f += b
    sy = max(abs(float(acc_f.max())), abs(float(acc_f.min())), 1e-6) / 127.0

    M = round_away(sx * sw / sy * (1 << SHIFT)).astype(np.int64)

    # ---- integer reference ----------------------------------------------
    xpad = np.zeros((ih + 2 * pad, iw + 2 * pad, cpad), np.int32)
    xpad[pad:pad + ih, pad:pad + iw, :cin] = xq
    wp = np.zeros((cout, k, k, cpad), np.int32)
    wp[:, :, :, :cin] = wq

    acc = np.zeros((oh, ow, cout), np.int64)
    for ky in range(k):
        for kx in range(k):
            xs = xpad[ky:ky + (oh - 1) * stride + 1:stride,
                      kx:kx + (ow - 1) * stride + 1:stride, :]
            acc += xs @ wp[:, ky, kx, :].T
    acc += bi

    y = np.zeros_like(acc)
    for oc in range(cout):
        y[:, :, oc] = round_away(acc[:, :, oc].astype(np.float64) * M[oc] / (1 << SHIFT))
    y = np.clip(y, -128, 127)

    # ACT==2 (SiLU): the table is built from this layer's output scale and
    # shipped in the blob, because a build-time table would bake in one scale.
    qv = np.arange(-128, 128)
    atab = np.zeros(256, np.int32)
    if a.act == 2:
        sil = (qv * sy) / (1.0 + np.exp(-qv * sy))
        atab = np.clip(round_away(sil / sy), -128, 127).astype(np.int32)
        y = atab[(y + 128).astype(np.int64)]
    elif a.act == 1:
        y = np.where(y < 0, y >> 3, y)
    y = np.clip(y, -128, 127).astype(np.int32)

    # ---- DDR image -------------------------------------------------------
    A_BASE = 0x00000000
    in_bytes = ih * iw * cpad
    W_BASE = (in_bytes + 0xFFFF) & ~0xFFFF
    w_bytes = cout * k * k * cpad
    Q_BASE = (W_BASE + w_bytes + 0xFFF) & ~0xFFF
    q_bytes = 2 * cout * 4
    T_BASE = (Q_BASE + q_bytes + 0xFFF) & ~0xFFF
    t_bytes = 256
    Y_BASE = (T_BASE + t_bytes + 0xFFF) & ~0xFFF
    y_bytes = oh * ow * cout
    total = Y_BASE + y_bytes
    memw = (total + 7) // 8 + 8

    mem = np.zeros(memw, np.uint64)

    def put_word(byte_off, val):
        mem[byte_off >> 3] = np.uint64(val & 0xFFFFFFFFFFFFFFFF)

    flat = xpad[:, :, :].astype(np.int64) & 0xFF
    in_flat = np.zeros(in_bytes, np.int64)
    tmp = np.zeros((ih, iw, cpad), np.int64)
    tmp[:, :, :cin] = xq & 0xFF
    in_flat[:] = tmp.reshape(-1)
    for i in range(0, in_bytes, 8):
        w64 = 0
        for j in range(8):
            w64 |= int(in_flat[i + j]) << (8 * j)
        put_word(A_BASE + i, w64)

    w_flat = wp.reshape(-1) & 0xFF
    for i in range(0, w_bytes, 8):
        w64 = 0
        for j in range(8):
            w64 |= int(w_flat[i + j]) << (8 * j)
        put_word(W_BASE + i, w64)

    for i in range(0, t_bytes, 8):
        w64 = 0
        for j in range(8):
            w64 |= (int(atab[i + j]) & 0xFF) << (8 * j)
        put_word(T_BASE + i, w64)

    qv = np.concatenate([bi.astype(np.int64), M.astype(np.int64)]) & 0xFFFFFFFF
    for i in range(0, q_bytes, 8):
        lo = int(qv[i // 4])
        hi = int(qv[i // 4 + 1])
        put_word(Q_BASE + i, (hi << 32) | lo)

    gen = ROOT / "gen"
    gen.mkdir(exist_ok=True)
    (gen / ("ddr_%s.hex" % a.tag)).write_text(
        "\n".join("%016x" % int(v) for v in mem) + "\n", encoding="ascii")

    y_flat = y.reshape(-1) & 0xFF
    exp = []
    for i in range(0, y_bytes, 8):
        w64 = 0
        for j in range(8):
            w64 |= int(y_flat[i + j]) << (8 * j)
        exp.append(w64)
    (gen / ("expected_%s.hex" % a.tag)).write_text(
        "\n".join("%016x" % v for v in exp) + "\n", encoding="ascii")

    hdr = (
        "localparam integer P_IN_H=%d, P_IN_W=%d, P_CINPAD=%d, P_COUT=%d, P_K=%d, P_STRIDE=%d, P_ACT=%d, P_TR=%d, P_PAD=%d;\n"
        "localparam integer P_OH=%d, P_OW=%d, P_MEMW=%d, P_NOUT=%d;\n"
        "`define DDR_FILE \"%s\"\n`define EXP_FILE \"%s\"\n"
        "localparam [31:0] P_A_BASE=32'h%08x, P_W_BASE=32'h%08x, P_Q_BASE=32'h%08x, P_Y_BASE=32'h%08x, P_T_BASE=32'h%08x;\n"
        % (ih, iw, cpad, cout, k, stride, a.act, a.tr, pad, oh, ow, memw, y_bytes // 8,
           (gen / ("ddr_%s.hex" % a.tag)).as_posix(),
           (gen / ("expected_%s.hex" % a.tag)).as_posix(),
           A_BASE, W_BASE, Q_BASE, Y_BASE, T_BASE))

    (gen / ("tb_params_%s.vh" % a.tag)).write_text(hdr, encoding="ascii")
    (gen / "tb_params.vh").write_text(hdr, encoding="ascii")

    meta = dict(layer=a.layer, in_h=ih, in_w=iw, cin=cin, cout=cout, cpad=cpad,
                k=k, stride=stride, oh=oh, ow=ow, act=a.act, tr=a.tr,
                a_base=A_BASE, w_base=W_BASE, q_base=Q_BASE, t_base=T_BASE, y_base=Y_BASE,
                memw=memw, out_words=y_bytes // 8,
                sx=float(sx), sy=float(sy), M=[int(v) for v in M[:8]],
                bias=[int(v) for v in bi[:8]],
                out_min=int(y.min()), out_max=int(y.max()),
                out_nonzero=int((y != 0).sum()), out_total=int(y.size))
    (gen / ("meta_%s.json" % a.tag)).write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
