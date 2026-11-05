"""pack_model.py -- turn the trained detector into what the accelerator eats.

Outputs (gen/):
    ddr_model.bin    one flat DDR image: per-layer weights, bias, M, activation
                     table, then every layer's input and output tensor space
    layer_table.h    static const acc_layer_t[60] for the CPU firmware, matching
                     sw/acc_regs.h field for field
    model_manifest.json  sizes, scales, addresses -- the record of what was packed

Two invariants this script must hold, because the engine cannot check them:

  * the weight blob is wp.reshape(-1) over [cout][k][k][cin_pad] int8, which is
    exactly the order conv_band_rt walks (tile, bank, tap, channel-slice); the
    byte-exact regressions in sim/ are the proof that this order is right
  * scales chain: sx[layer i+1] == sy[layer i].  Each layer's output is stored
    at its own scale and the next layer must read it at that same scale, so the
    calibration only ever picks sx[0] and every sy[i].
"""
import argparse
import csv
import json
import sys
import types
from pathlib import Path

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
import torch

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"
SHIFT = 15
ALIGN = 256          # byte alignment for every region


def round_away(v):
    """round half away from zero, the rule the RTL epilogue implements"""
    return np.where(v >= 0, np.floor(v + 0.5), np.ceil(v - 0.5)).astype(np.int64)


def execution_order_convs(model):
    """every Conv2d in the order the forward pass actually runs them"""
    order = []
    hooks = []

    def mk(idx):
        def hook(mod, inp, out):
            order.append((idx, mod, inp[0], out))
        return hook

    for i, m in enumerate(model.modules()):
        if isinstance(m, torch.nn.Conv2d):
            hooks.append(m.register_forward_hook(mk(i)))
    return hooks


def main():
    raise SystemExit(
        "Legacy linear-convolution packer is not a detector. "
        "Use scripts/pack_deployment.py and gen/integration/packed instead.")
    ap = argparse.ArgumentParser()
    ap.add_argument("--calib", type=int, default=8, help="images for the scales")
    ap.add_argument("--out", default=str(ROOT / "gen"))
    a = ap.parse_args()

    outdir = Path(a.out)
    outdir.mkdir(parents=True, exist_ok=True)

    rows = list(csv.DictReader((ROOT / "data/layer_table/layers.csv").open()))
    plan = {r2["module"]: r2 for r2 in
            csv.DictReader((ROOT / "results/tile_plan/plan_cap96KiB.csv").open())}
    print("layer table:", len(rows), "convs")

    sd = torch.load(CKPT, map_location="cpu", weights_only=False)
    model = sd["model"].float().eval()

    # ---- calibration: abs-max of every conv's input and output -------------
    convs = [m for m in model.modules() if isinstance(m, torch.nn.Conv2d)]
    amax_in = [0.0] * len(convs)
    amax_out = [0.0] * len(convs)
    seen = [0] * len(convs)
    hooks = []
    for i, m in enumerate(convs):
        def mk(idx):
            def hook(mod, inp, out):
                amax_in[idx] = max(amax_in[idx], float(inp[0].abs().max()))
                amax_out[idx] = max(amax_out[idx], float(out.abs().max()))
                seen[idx] += 1
            return hook
        hooks.append(m.register_forward_hook(mk(i)))
    n = 0
    imgs = sorted((ROOT / "data/images/indomain_test").glob("*.jpg"))[:a.calib]
    if not imgs:
        sys.exit("no calibration images under data/images/indomain_test")
    from quant_yolov5n import preprocess          # same letterbox as everything else
    with torch.no_grad():
        for p in imgs:
            x, _, _ = preprocess(p, 320)
            model(x)
            n += 1
    for h in hooks:
        h.remove()
    miss = [i for i, c in enumerate(seen) if c == 0]
    if miss:
        sys.exit("calibration never reached conv index %r" % miss)
    print("calibrated on", n, "images,", len(convs), "convs all reached")

    # ---- scales: chained, calibration only picks sx[0] and every sy --------
    sx = [0.0] * len(rows)
    sy = [0.0] * len(rows)
    sx[0] = max(amax_in[0], 1e-6) / 127.0
    for i, r in enumerate(rows):
        sy[i] = max(amax_out[i], 1e-6) / 127.0
        if i + 1 < len(rows):
            sx[i + 1] = sy[i]

    # ---- pack --------------------------------------------------------------
    layers = []
    cursor = 0

    def alloc(nbytes):
        nonlocal cursor
        p = cursor
        cursor = (p + nbytes + ALIGN - 1) & ~(ALIGN - 1)
        return p

    for i, r in enumerate(rows):
        k = int(r["k"]); stride = int(r["stride"]); pad = int(r["pad"])
        cin = int(r["cin"]); cout = int(r["cout"])
        ih = int(r["in_h"]); iw = int(r["in_w"])
        oh = int(r["out_h"]); ow = int(r["out_w"])
        act = 2 if r["act"] == "SiLU" else (1 if r["act"] == "LeakyReLU" else 0)
        cpad = (cin + 7) // 8 * 8
        csl = cpad // 8
        wtot = k * k * csl

        m = dict(model.named_modules())[r["module"]]
        w = m.weight.detach().numpy().astype(np.float32)        # [cout][cin][ky][kx]
        b = (m.bias.detach().numpy().astype(np.float32)
             if m.bias is not None else np.zeros(cout, np.float32))
        w = np.transpose(w, (0, 2, 3, 1))                        # [cout][ky][kx][cin]

        sw = np.maximum(np.abs(w).reshape(cout, -1).max(1), 1e-6) / 127.0
        wq = np.clip(round_away(w / sw[:, None, None, None]), -128, 127)
        wp = np.zeros((cout, k, k, cpad), np.int64)
        wp[:, :, :, :cin] = wq
        bi = round_away(b / (sx[i] * sw))
        M = round_away(sx[i] * sw / sy[i] * float(1 << SHIFT))
        # the epilogue holds M in 32 bits and multiplies a 32-bit accumulator by
        # it; if a scale collapses this breaks loudly here instead of quietly
        if np.abs(M).max() >= (1 << 31):
            sys.exit("M out of 32-bit range at %s: %d" % (r["module"], int(np.abs(M).max())))

        qv = np.concatenate([bi, M]).astype(np.int64) & 0xFFFFFFFF
        qv = qv.astype(np.uint32)

        tab = np.zeros(256, np.int64)
        if act == 2:
            q = np.arange(-128, 128)
            sil = (q * sy[i]) / (1.0 + np.exp(-q * sy[i]))
            tab = np.clip(round_away(sil / sy[i]), -128, 127)

        w_bytes = cout * k * k * cpad
        q_bytes = 2 * cout * 4
        t_bytes = 256

        W = alloc(w_bytes); Q = alloc(q_bytes); T = alloc(t_bytes)
        layers.append(dict(order=i, module=r["module"], k=k, stride=stride,
                           pad=pad, cin=cin, cout=cout, cpad=cpad, ih=ih, iw=iw,
                           oh=oh, ow=ow, act=act, wtot=wtot,
                           w_base=W, q_base=Q, t_base=T,
                           sx=float(sx[i]), sy=float(sy[i]),
                           tr=int(plan[r["module"]]["tr"]),
                           w_bytes=w_bytes,
                           wp=wp.reshape(-1).astype(np.uint8).tobytes(),
                           qv=qv, tab=tab.astype(np.uint8).tobytes()))

    # ---- second pass: every layer's input and output tensor ---------------
    # one buffer per layer input and output, no sharing: concat and add take two
    # live inputs, so sharing would need a liveness pass.  The whole set is only
    # a few MiB, which DDR has and BRAM does not.
    for L in layers:
        L["a_base"] = alloc(L["ih"] * L["iw"] * L["cpad"])
        L["y_base"] = alloc(L["oh"] * L["ow"] * L["cout"])
    total = cursor
    img = np.zeros(total, np.uint8)

    for L in layers:
        img[L["w_base"]:L["w_base"] + L["w_bytes"]] = np.frombuffer(L["wp"], np.uint8)
        img[L["q_base"]:L["q_base"] + 2 * L["cout"] * 4] = \
            np.frombuffer(L["qv"].tobytes(), np.uint8)
        img[L["t_base"]:L["t_base"] + 256] = np.frombuffer(L["tab"], np.uint8)

    (outdir / "ddr_model.bin").write_bytes(img.tobytes())

    # ---- C header ----------------------------------------------------------
    lines = [
        "/* layer_table.h -- generated by scripts/pack_model.py, do not edit.",
        " *",
        " * %d layers, DDR image %d bytes (%.2f MiB).  Fields match sw/acc_regs.h." % (
            len(layers), total, total / 1048576.0),
        " * Scales are chained: sx[i+1] == sy[i], calibration only picked sx[0].",
        " * ACC_CIN is the PADDED channel count, not the real one: the engine",
        " * derives csl = cin>>3 and walks 8 channels per word, so cin=3 on the",
        " * first layer would give csl=0 and read nothing.  Channels cin..cpad-1",
        " * must be zero-filled by whoever writes the input tensor.",
        " */",
        "#ifndef LAYER_TABLE_H",
        "#define LAYER_TABLE_H",
        "",
        "#include \"acc_regs.h\"",
        "",
        "#define N_LAYERS %du" % len(layers),
        "",
        "static const acc_layer_t layers[N_LAYERS] = {"]
    for L in layers:
        lines.append(
            "    { .a_base=0x%08xu, .w_base=0x%08xu, .q_base=0x%08xu, "
            ".t_base=0x%08xu, .y_base=0x%08xu," % (
                L["a_base"], L["w_base"], L["q_base"], L["t_base"], L["y_base"]))
        lines.append(
            "      .cin=%du, .cout=%du, .in_w=%du, .in_h=%du, .out_w=%du, .out_h=%du,"
            % (L["cpad"], L["cout"], L["iw"], L["ih"], L["ow"], L["oh"]))
        lines.append(
            "      .k=%du, .stride=%du, .pad=%du, .act=%du, .tr=%du },   /* %s */"
            % (L["k"], L["stride"], L["pad"], L["act"], L["tr"], L["module"]))
    lines += ["};", "", "#endif /* LAYER_TABLE_H */", ""]
    (outdir / "layer_table.h").write_text("\n".join(lines), encoding="ascii")

    man = dict(total_bytes=total, n_layers=len(layers), shift=SHIFT,
               align=ALIGN,
               layers=[{k: v for k, v in L.items()
                        if k not in ("wp", "qv", "tab")} for L in layers])
    (outdir / "model_manifest.json").write_text(
        json.dumps(man, indent=1), encoding="utf-8")

    print("wrote %s (%d bytes), layer_table.h, model_manifest.json"
          % (outdir / "ddr_model.bin", total))


if __name__ == "__main__":
    main()
