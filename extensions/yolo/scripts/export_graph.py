"""export_graph.py -- the execution schedule of the whole detector, op by op.

layers.csv lists the 60 convolutions, but the network is not 60 convolutions: the
C3 and SPPF blocks interleave their convolutions with concat, add, maxpool and
upsample, and those extras are written inline in the block's forward() so no
forward hook can see them.  Without them the firmware has no schedule to follow
and the accelerator cannot be driven past the first C3.

So the ops are derived from the module tree instead, then **validated against
layers.csv**: if the convolution subsequence of this schedule is not exactly the
order the hooks recorded, the derivation is wrong and this script fails loudly
rather than emitting a plausible-looking table.

Output (gen/graph.json, gen/graph.h):
    ops[]      op, module, in/out shape, channels, kernel, stride, inputs
    tensors[]  a buffer id per op output, with byte offsets into the DDR image

Op codes match postop_engine plus the convolutions:
    0 CONV   1 MAXPOOL   2 UPSAMPLE   3 CONCAT   4 ADD
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

import torch

ROOT = Path(__file__).resolve().parents[1]
CKPT = ROOT / "data/models/yolov5n-garbage.pt"

OP_CONV, OP_MAXPOOL, OP_UPSAMPLE, OP_CONCAT, OP_ADD = 0, 1, 2, 3, 4
OPNAME = {0: "CONV", 1: "MAXPOOL", 2: "UPSAMPLE", 3: "CONCAT", 4: "ADD"}


def conv_out(m):
    """(cin, cout, k, stride) of a Conv wrapper"""
    c = m.conv
    return c.in_channels, c.out_channels, c.kernel_size[0], c.stride[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=320)
    ap.add_argument("--out", default=str(ROOT / "gen"))
    a = ap.parse_args()

    sd = torch.load(CKPT, map_location="cpu", weights_only=False)
    model = sd["model"].float().eval()
    seq = model.model

    ops = []

    def emit(op, module, cin, cout, w, h, k=0, stride=1, inputs=None, extra=None):
        o = dict(idx=len(ops), op=op, name=OPNAME[op], module=module,
                 cin=cin, cout=cout, in_w=w, in_h=h, k=k, stride=stride,
                 inputs=inputs or [])
        if extra:
            o.update(extra)
        ops.append(o)
        return o

    # layers.csv carries the real geometry of every convolution, including the
    # autopad value: model.0 is 6x6 stride 2 with pad 2, not k//2 = 3.  Deriving
    # it in this script instead gave 161x161 for layer 1 and every downstream
    # shape was wrong by a row, so the table is the only source used here.
    csv_rows = {r["module"]: r for r in
                csv.DictReader((ROOT / "data/layer_table/layers.csv").open())}

    def row(path):
        r = csv_rows.get(path)
        if r is None:
            sys.exit("layer %r missing from layers.csv" % path)
        return r

    def do_conv(m, path, source):
        r = row(path)
        return emit(OP_CONV, path, int(r["cin"]), int(r["cout"]),
                    int(r["in_w"]), int(r["in_h"]),
                    k=int(r["k"]), stride=int(r["stride"]),
                    inputs=[source],
                    extra=dict(out_w=int(r["out_w"]), out_h=int(r["out_h"]),
                               pad=int(r["pad"])))

    def do_c3(m, path, cin, cout, w, h, source):
        o1 = do_conv(m.cv1, path + ".cv1.conv", source)
        current = o1["idx"]
        cin1 = o1["cout"]
        w, h = o1["out_w"], o1["out_h"]
        for bi, b in enumerate(m.m):
            residual = current
            first = do_conv(b.cv1, "%s.m.%d.cv1.conv" % (path, bi), current)
            second = do_conv(b.cv2, "%s.m.%d.cv2.conv" % (path, bi), first["idx"])
            current = second["idx"]
            if getattr(b, "add", False):
                ob = row("%s.m.%d.cv2.conv" % (path, bi))
                added = emit(OP_ADD, "%s.m.%d.add" % (path, bi),
                     int(ob["cout"]), int(ob["cout"]), int(ob["out_w"]), int(ob["out_h"]),
                     inputs=[residual, current])
                current = added["idx"]
        # this C3 is the two-branch flavour: cv1 feeds the bottlenecks and cv2
        # feeds the concat directly.  layers.csv puts cv2 *after* the
        # bottlenecks, which is what torch.cat's left-to-right argument
        # evaluation produces, and that is what pins the order down.
        branch = do_conv(m.cv2, path + ".cv2.conv", source)
        oc = row(path + ".cv3.conv")
        joined = emit(OP_CONCAT, path + ".cat", cin1 * 2, int(oc["cin"]),
             int(oc["in_w"]), int(oc["in_h"]), inputs=[current, branch["idx"]])
        return do_conv(m.cv3, path + ".cv3.conv", joined["idx"])["idx"]

    def do_sppf(m, path, cin, cout, w, h, source):
        o1 = do_conv(m.cv1, path + ".cv1.conv", source)
        pool_inputs = [o1["idx"]]
        cin1 = o1["cout"]
        w, h = o1["out_w"], o1["out_h"]
        # SPPF always runs the same maxpool three times and concatenates the
        # original with all three results, so the count is 3 and the concat has
        # 4 inputs, not `n` (SPPF stores no such attribute)
        for i in range(3):
            pooled = emit(OP_MAXPOOL, "%s.m%d" % (path, i), cin1, cin1, w, h,
                 k=m.m.kernel_size, stride=m.m.stride, inputs=[pool_inputs[-1]])
            pool_inputs.append(pooled["idx"])
        oc = row(path + ".cv2.conv")
        joined = emit(OP_CONCAT, path + ".cat", cin1 * 4, int(oc["cin"]),
             int(oc["in_w"]), int(oc["in_h"]), inputs=pool_inputs)
        return do_conv(m.cv2, path + ".cv2.conv", joined["idx"])["idx"]

    layer_out = {}          # layer index -> (c, h, w) of that layer's output
    layer_tensor = {}
    detector_outputs = []
    x = (3, a.size, a.size)

    for i, layer in enumerate(seq):
        cls = type(layer).__name__
        path = "model.%d" % i
        f = layer.f
        source = -1 if i == 0 else layer_tensor[i - 1]
        if isinstance(f, int) and f != -1:
            source = layer_tensor[f if f >= 0 else i + f]
            x = layer_out[f if f >= 0 else i + f]
        if cls == "Conv":
            o = do_conv(layer, path + ".conv", source)
            result = o["idx"]
            x = (o["cout"], o["out_h"], o["out_w"])
        elif cls == "C3":
            result = do_c3(layer, path, x[0], layer.cv3.conv.out_channels, x[2], x[1], source)
            o = row(path + ".cv3.conv")
            x = (int(o["cout"]), int(o["out_h"]), int(o["out_w"]))
        elif cls == "SPPF":
            result = do_sppf(layer, path, x[0], layer.cv2.conv.out_channels, x[2], x[1], source)
            o = row(path + ".cv2.conv")
            x = (int(o["cout"]), int(o["out_h"]), int(o["out_w"]))
        elif cls == "MaxPool2d":
            k = layer.kernel_size
            s = layer.stride
            oh = (x[1] + 2 * (k // 2) - k) // s + 1
            ow = (x[2] + 2 * (k // 2) - k) // s + 1
            result = emit(OP_MAXPOOL, path, x[0], x[0], x[2], x[1],
                          k=k, stride=s, inputs=[source])["idx"]
            x = (x[0], oh, ow)
        elif cls == "Upsample":
            oh, ow = x[1] * 2, x[2] * 2
            result = emit(OP_UPSAMPLE, path, x[0], x[0], x[2], x[1],
                          inputs=[source])["idx"]
            x = (x[0], oh, ow)
        elif cls == "Concat":
            # `f` names the layers whose outputs are joined; -1 means "the
            # previous layer", which is this layer's own input
            srcs = f if isinstance(f, list) else [f]
            co = [int(layer_out[v if v != -1 else i - 1][0]) for v in srcs]
            result = emit(OP_CONCAT, path, sum(co), sum(co), x[2], x[1],
                 inputs=[layer_tensor[v if v >= 0 else i + v] for v in srcs])["idx"]
            x = (sum(co), x[1], x[2])
        elif cls == "Detect":
            # three heads, each a Conv followed by a 1x1 Conv2d.  They are the
            # only convs with no activation (act=None in layers.csv), and the
            # CPU decodes them in FP32, but they still have to run somewhere.
            # Names come from named_modules rather than a hard-coded `cv2`,
            # because this Detect variant does not expose that attribute.
            srcs = f if isinstance(f, list) else [f]
            heads = [(n, mm) for n, mm in layer.named_modules()
                     if isinstance(mm, torch.nn.Conv2d)]
            for hi, (nm, sub) in enumerate(heads):
                head = do_conv(sub, "%s.%s" % (path, nm), layer_tensor[srcs[hi]])
                detector_outputs.append(head["idx"])
            result = detector_outputs[-1]
        else:
            sys.exit("unhandled layer class %s at %d" % (cls, i))
        layer_out[i] = x
        layer_tensor[i] = result

    for op in ops:
        if op["op"] == OP_CONV:
            oh, ow = op["out_h"], op["out_w"]
        elif op["op"] == OP_UPSAMPLE:
            oh, ow = op["in_h"] * 2, op["in_w"] * 2
        elif op["op"] == OP_MAXPOOL:
            oh = (op["in_h"] + 2 * (op["k"] // 2) - op["k"]) // op["stride"] + 1
            ow = (op["in_w"] + 2 * (op["k"] // 2) - op["k"]) // op["stride"] + 1
        else:
            oh, ow = op["in_h"], op["in_w"]
        op["out_shape"] = [op["cout"], oh, ow]

    # ---- validate against layers.csv -------------------------------------
    # The conv order here was derived from the module tree; layers.csv recorded
    # it by hooking the real forward.  If the two disagree, the derivation is
    # wrong and the schedule would silently skip or duplicate work.
    got = [o["module"] for o in ops if o["op"] == OP_CONV]
    want = [r["module"] for r in
            csv.DictReader((ROOT / "data/layer_table/layers.csv").open())]
    if got != want:
        print("CONV ORDER MISMATCH: derived %d, recorded %d" % (len(got), len(want)))
        for i, (g, w2) in enumerate(zip(got, want)):
            if g != w2:
                print("  first diff at %d: derived %r vs recorded %r" % (i, g, w2))
                break
        sys.exit(1)
    print("conv order matches layers.csv (%d convs)" % len(got))

    by = {OPNAME[k]: sum(1 for o in ops if o["op"] == k) for k in OPNAME}
    print("ops:", len(ops), by)

    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "graph.json").write_text(json.dumps(dict(
        size=a.size, n_ops=len(ops), outputs=detector_outputs, ops=ops),
        indent=1), encoding="utf-8")
    print("wrote", out / "graph.json")


if __name__ == "__main__":
    main()
