"""Lite-A: single source of truth for layer shapes, MACs, params and the DDR map.

Why this file exists
--------------------
The v2 plan carried hand-computed numbers that were wrong (a downsampling stage
was missing, so the deep layers were placed one level too shallow).  Everything
downstream -- array sizing, frame-rate estimates, the DDR address table -- is
derived from those numbers.  So they are computed here, once, from an explicit
topology, and every document quotes this output instead of re-typing it.

Topology
--------
YOLOv3-tiny structure is preserved exactly: 5 stride-2 pools, then the
pool-2/1, the 1x1/3x3 head pair, route -4, upsample, route concat, second head.
Only the width and the class count change:

    width x0.5      -> 8 16 32 64 128 256 512
    classes 4       -> head channels 3*(5+4) = 27   (NOT scaled)

Run:  python lite_a.py
"""

from __future__ import annotations

# --------------------------------------------------------------------------
# topology: (kind, kwargs).  'src' names an earlier layer for route/upsample.
# --------------------------------------------------------------------------
TOPOLOGY = [
    dict(kind="conv", k=3, cout=8,   s=1),          # 0
    dict(kind="pool", k=2, s=2),                    # 1
    dict(kind="conv", k=3, cout=16,  s=1),          # 2
    dict(kind="pool", k=2, s=2),                    # 3
    dict(kind="conv", k=3, cout=32,  s=1),          # 4
    dict(kind="pool", k=2, s=2),                    # 5
    dict(kind="conv", k=3, cout=64,  s=1),          # 6
    dict(kind="pool", k=2, s=2),                    # 7
    dict(kind="conv", k=3, cout=128, s=1),          # 8  <- skip for route
    dict(kind="pool", k=2, s=2),                    # 9
    dict(kind="conv", k=3, cout=256, s=1),          # 10
    dict(kind="pool", k=2, s=1),                    # 11
    dict(kind="conv", k=3, cout=512, s=1),          # 12  biggest single layer
    dict(kind="conv", k=1, cout=128, s=1),          # 13
    dict(kind="conv", k=3, cout=256, s=1),          # 14
    dict(kind="conv", k=1, cout=27,  s=1),          # 15  head 1 (stride 32)
    dict(kind="route", src=[12]),                   # 16  route -4 -> layer 12 (512 ch)
    dict(kind="conv", k=1, cout=64,  s=1),          # 17
    dict(kind="upsample", s=2, src=[17]),           # 18
    dict(kind="route", src=[18, 8]),                # 19  concat 64 + 128
    dict(kind="conv", k=3, cout=128, s=1),          # 20
    dict(kind="conv", k=1, cout=27,  s=1),          # 21  head 2 (stride 16)
]

CLASSES = 4


def build(n_in: int):
    """Return per-layer records for a square n_in x n_in input."""
    recs = []
    size = n_in           # spatial size of the current tensor
    ch = 3                # input channels
    for idx, spec in enumerate(TOPOLOGY):
        kind = spec["kind"]
        if kind == "conv":
            k, cout, s = spec["k"], spec["cout"], spec["s"]
            out_size = (size + 2 * (k // 2) - k) // s + 1
            params = ch * cout * k * k + cout
            macs = out_size * out_size * cout * ch * k * k
            recs.append(dict(idx=idx, kind=f"conv{k}x{k}", cin=ch, cout=cout,
                             size=out_size, params=params, macs=macs))
            ch, size = cout, out_size
        elif kind == "pool":
            k, s = spec["k"], spec["s"]
            # Darknet maxpool uses padding = k//2, so a 2/1 pool keeps the size
            out_size = (size + k // 2 - k) // s + 1
            recs.append(dict(idx=idx, kind=f"pool{k}/{s}", cin=ch, cout=ch,
                             size=out_size, params=0, macs=0))
            size = out_size
        elif kind == "route":
            srcs = spec["src"]
            total = sum(recs[i]["cout"] for i in srcs)
            size = recs[srcs[0]]["size"]
            for i in srcs[1:]:
                assert recs[i]["size"] == size, "route sources must share a size"
            recs.append(dict(idx=idx, kind="route", cin=total, cout=total,
                             size=size, params=0, macs=0))
            ch = total
        elif kind == "upsample":
            size *= spec["s"]
            recs.append(dict(idx=idx, kind=f"upsample x{spec['s']}", cin=ch,
                             cout=ch, size=size, params=0, macs=0))
        else:
            raise ValueError(kind)
    return recs


def report(n_in: int):
    recs = build(n_in)
    total_macs = sum(r["macs"] for r in recs)
    total_params = sum(r["params"] for r in recs)
    print(f"\n=== input {n_in}x{n_in} : {total_macs/1e6:.2f} MMAC, "
          f"{total_params:,} params ({total_params/1048576:.3f} MiB int8) ===")
    print(f"{'idx':>3} {'layer':<12} {'in':>4} {'out':>4} {'size':>5} "
          f"{'params':>12} {'MACs':>14} {'act KB':>8}")
    for r in recs:
        act = r["size"] * r["size"] * r["cout"]
        print(f"{r['idx']:>3} {r['kind']:<12} {r['cin']:>4} {r['cout']:>4} "
              f"{r['size']:>5} {r['params']:>12,} {r['macs']:>14,} {act/1024:>8.1f}")
    return recs, total_macs, total_params


# --------------------------------------------------------------------------
# DDR map: generated, never hand-typed.  Every region is aligned and checked.
# --------------------------------------------------------------------------
ALIGN = 0x10000          # 64 KiB
WEIGHT_ALIGN = 0x100       # 256 B, enough for 256-bit bursts


def _align(x, a):
    return (x + a - 1) // a * a


def memory_map(n_in: int, classes=CLASSES, verbose=True):
    recs, total_macs, total_params = report(n_in)
    regions = []

    def add(name, size, align, note=""):
        start = _align(regions[-1]["end"] if regions else 0, align)
        regions.append(dict(name=name, start=start, end=start + size,
                            size=size, align=align, note=note))
        return start

    fb = 1280 * 720 * 2
    add("video_fb_a", fb, ALIGN, "1280x720 RGB565")
    add("video_fb_b", fb, ALIGN, "ping-pong")
    add("ai_input", n_in * n_in * 3, ALIGN, f"{n_in}x{n_in}x3 int8 RGB")
    max_act = max(r["size"] * r["size"] * r["cout"] for r in recs)
    add("act_a", max_act, ALIGN, "largest layer output")
    add("act_b", max_act, ALIGN, "ping-pong")
    skip = recs[8]["size"] * recs[8]["size"] * recs[8]["cout"]
    add("skip_l8", skip, ALIGN, "route source, held across the trunk")
    add("weights", total_params, WEIGHT_ALIGN, "int8 weights + bias/scale")
    add("layer_cfg", len(recs) * 64, WEIGHT_ALIGN, "per-layer descriptor")

    # ---- checks -----------------------------------------------------------
    ok = True
    for a, b in zip(regions, regions[1:]):
        if b["start"] < a["end"]:
            print(f"  !! OVERLAP {a['name']} -> {b['name']}"); ok = False
    for r in regions:
        if r["start"] % r["align"]:
            print(f"  !! MISALIGNED {r['name']}"); ok = False
    total = regions[-1]["end"]
    print(f"\nmemory map ({n_in} input), total {total:,} B "
          f"= {total/1048576:.2f} MiB   checks: {'PASS' if ok else 'FAIL'}")
    print(f"{'region':<12} {'start':>10} {'end':>10} {'KiB':>9}  note")
    for r in regions:
        print(f"{r['name']:<12} 0x{r['start']:08X} 0x{r['end']:08X} "
              f"{r['size']/1024:>9.1f}  {r['note']}")
    return regions, recs, total_macs, total_params, ok


def fps_table(f_mhz=50.0):
    """Frame rate from the corrected MAC counts. APM assumes 1 MAC per APM
    (the conservative budget the review asked for; packing is unproven)."""
    print("\n=== frame rate, computed from the corrected MAC counts "
          f"(@{f_mhz:g} MHz) ===")
    print("APM column assumes 1 int8 MAC per APM, i.e. no packing.")
    macs = {n: sum(r["macs"] for r in build(n)) for n in (96, 128, 160)}
    print(f"{'lanes':>6} {'APM':>5} {'peak GMAC/s':>12} "
          f"{'96 eff50/60':>15} {'128 eff50/60':>16} {'160 eff50/60':>16}")
    for lanes in (32, 64, 128):
        peak = lanes * f_mhz * 1e6
        cells = []
        for n in (96, 128, 160):
            a = peak * 0.50 / macs[n]
            b = peak * 0.60 / macs[n]
            cells.append(f"{a:5.1f}/{b:5.1f} fps ")
        print(f"{lanes:>6} {lanes:>5} {peak/1e9:>12.2f} "
              f"{cells[0]:>15} {cells[1]:>16} {cells[2]:>16}")
    print("(eff = fraction of peak MACs actually issued; DDR stalls not included)")


if __name__ == "__main__":
    for n in (96, 128, 160):
        report(n)
    memory_map(128)
    fps_table()
