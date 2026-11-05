"""Tile planning for the DDR-backed convolution engine.

Reads the real layer table (data/layer_table/layers.csv, exported by hooking the
actual Conv2d execution order, not from memory) and picks per-layer tiling
parameters under an on-chip storage cap.

Hardware model this script commits to
-------------------------------------
Array: P = 8 output pixels x C = 8 output channels = 64 MAC/cycle.  The array
is NOT widened here (no extra APM).  Per cycle it consumes 8 activation bytes
(pixels at stride s) and 8 weight bytes (one tap x 8 channels).  That is the
port requirement the storage has to meet: 16 B/cycle worst case for activations
(stride 2 needs a 16-byte window to extract 8 stride-2 bytes), 8 B/cycle for
weights.

Schedule (band-tiled, conservative: no load/compute overlap assumed, and no
attempt at global optimum -- extra reads are accepted):

    for band of TR output rows:            # TR is what we search
        load all CIN activation rows for this band into the band buffer
        for each 8-channel output tile:
            load that tile's weights (8 x CIN x k x k) into the weight buffer
            compute 8 channels x TR rows x full width
            requantise and write back                   # output written once

So activations are read from DDR once per output row band, weights once per band
per channel tile.  Both re-read factors are made explicit below; nothing is
hidden by an "ideal cache" assumption.

Storage budget
--------------
The previous AI budget was <= 70 DRM.  One DRM here is 36 Kbit = 4.5 KiB, so
70 DRM = 315 KiB nominal.  Nominal is not usable: this script keeps 12 % back
for implementation waste, double buffering and quantisation parameters, and
also reports the stricter 64 KiB variant so the two can be compared rather than
one being declared the only option.
"""
import argparse
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ROOT / "data" / "layer_table" / "layers.csv"

DRM_BYTES = 36864 // 8          # 36 Kbit = 4608 B
WASTE = 0.12                    # implementation waste + double buffering


def drm_to_bytes(n, waste=WASTE):
    return int(n * DRM_BYTES * (1.0 - waste))


def ceil_div(a, b):
    return -(-a // b)


def plan_row(layer, tr, ddr_mbps):
    """Cost of one candidate (TR) for one layer. Returns dict or None."""
    cin, cout = layer["cin"], layer["cout"]
    k, s = layer["k"], layer["stride"]
    ih, iw, oh, ow = layer["in_h"], layer["in_w"], layer["out_h"], layer["out_w"]
    macs = layer["macs"]

    P, C = 8, 8
    n_cb = ceil_div(cout, C)

    # --- buffers (bytes) ---------------------------------------------------
    rows_in_band = tr * s + k - s                 # input rows touched per band
    act_band = rows_in_band * iw * cin            # int8 activations, whole band
    w_buf = C * cin * k * k                       # one 8-channel tile, all CIN
    acc = C * tr * ow * 4                         # int32 accumulators
    qpar = C * 8                                  # bias + M per channel
    total = act_band + w_buf + acc + qpar

    # --- DDR traffic (bytes) ----------------------------------------------
    n_band = ceil_div(oh, tr)
    traffic_in = n_band * act_band                # re-read per band (halo)
    traffic_w = n_band * cout * cin * k * k       # re-read per band, all tiles
    traffic_out = cout * oh * ow

    # --- cycles ------------------------------------------------------------
    cyc_compute = ceil_div(macs, P * C)
    # requantise: 8 channels x 1 pixel per cycle -> output elements / 8
    cyc_requant = ceil_div(cout * oh * ow, 8)
    # band fill: one 8-byte word per cycle from DDR
    cyc_load_act = ceil_div(traffic_in, 8)
    cyc_load_w = ceil_div(traffic_w, 8)
    # DDR is shared: convert bytes to cycles at the configured rate
    bytes_per_cycle = ddr_mbps * 1e6 / 110e6
    cyc_ddr = ceil_div(traffic_in + traffic_w + traffic_out, max(1.0, bytes_per_cycle))

    cyc_serial = cyc_compute + cyc_requant + cyc_load_act + cyc_load_w
    cyc_overlap = max(cyc_compute + cyc_requant, cyc_ddr)

    return {
        "tr": tr,
        "n_cb": n_cb,
        "act_band": act_band,
        "w_buf": w_buf,
        "acc": acc,
        "total": total,
        "traffic_in": traffic_in,
        "traffic_w": traffic_w,
        "traffic_out": traffic_out,
        "traffic": traffic_in + traffic_w + traffic_out,
        "cyc_compute": cyc_compute,
        "cyc_serial": cyc_serial,
        "cyc_overlap": cyc_overlap,
        "util": macs / (max(1, cyc_serial) * P * C),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ddr", type=float, default=400.0, help="DDR MB/s, measured value goes here later")
    ap.add_argument("--cap-kib", type=float, default=None, help="override the cap in KiB")
    ap.add_argument("--out", default="tile_plan")
    a = ap.parse_args()

    rows = list(csv.DictReader(LAYERS.open()))
    for r in rows:
        for f in ("k", "stride", "pad", "cin", "cout", "in_h", "in_w", "out_h", "out_w", "macs", "params"):
            r[f] = int(r[f])

    caps = []
    if a.cap_kib is not None:
        caps.append(("cap%.0fKiB" % a.cap_kib, int(a.cap_kib * 1024)))
    else:
        caps.append(("70DRM", drm_to_bytes(70)))
        caps.append(("64KiB", 64 * 1024))

    outdir = ROOT / "results" / a.out
    outdir.mkdir(parents=True, exist_ok=True)

    summary = {}
    for tag, cap in caps:
        chosen = []
        tot_bytes = tot_cyc = tot_cyc_ov = tot_mac = 0
        fails = []
        for r in rows:
            best = None
            for tr in (1, 2, 4, 8):   # the engine's TRM is 8, so nothing larger is legal
                if tr < 1 or tr > r["out_h"]:
                    continue
                c = plan_row(r, tr, a.ddr)
                if c["total"] > cap:
                    continue
                # prefer smallest cycle count, then smallest storage
                key = (c["cyc_serial"], c["total"])
                if best is None or key < best[0]:
                    best = (key, c)
            if best is None:
                fails.append((r["module"], min(plan_row(r, tr, a.ddr)["total"]
                                               for tr in (1,) if tr <= r["out_h"])))
                continue
            c = best[1]
            chosen.append(dict(module=r["module"], k=r["k"], s=r["stride"],
                               cin=r["cin"], cout=r["cout"],
                               oh=r["out_h"], ow=r["out_w"], macs=r["macs"], **c))
            tot_bytes += c["total"]
            tot_cyc += c["cyc_serial"]
            tot_cyc_ov += c["cyc_overlap"]
            tot_mac += r["macs"]

        with (outdir / ("plan_%s.csv" % tag)).open("w", newline="") as f:
            wr = csv.DictWriter(f, fieldnames=list(chosen[0].keys()))
            wr.writeheader()
            wr.writerows(chosen)

        tot_tr_in = sum(c["traffic_in"] for c in chosen)
        tot_tr_w = sum(c["traffic_w"] for c in chosen)
        tot_tr_out = sum(c["traffic_out"] for c in chosen)
        tot_traffic = tot_tr_in + tot_tr_w + tot_tr_out
        summary[tag] = dict(
            cap=cap,
            layers_planned=len(chosen),
            layers_failed=len(fails),
            max_onchip=max(c["total"] for c in chosen),
            max_act=max(c["act_band"] for c in chosen),
            max_w=max(c["w_buf"] for c in chosen),
            max_acc=max(c["acc"] for c in chosen),
            traffic_in=tot_tr_in, traffic_w=tot_tr_w, traffic_out=tot_tr_out,
            traffic_total=tot_traffic,
            cycles_serial=tot_cyc,
            cycles_overlap=tot_cyc_ov,
            util_serial=tot_mac / (tot_cyc * 64),
            util_overlap=tot_mac / (tot_cyc_ov * 64),
            ms_serial=tot_cyc / 110e3,
            ms_overlap=tot_cyc_ov / 110e3,
        )

    print("DDR assumed %.0f MB/s; cycles at 110 MHz" % a.ddr)
    for tag, s in summary.items():
        print("\n[%s]  cap %.0f KiB (%d B)" % (tag, s["cap"] / 1024, s["cap"]))
        print("  planned %d layers, failed %d" % (s["layers_planned"], s["layers_failed"]))
        print("  on-chip peak %.1f KiB  (act %.1f / weights %.1f / acc %.1f)"
              % (s["max_onchip"] / 1024, s["max_act"] / 1024,
                 s["max_w"] / 1024, s["max_acc"] / 1024))
        print("  DDR  in %.2f MB  weights %.2f MB  out %.2f MB  = %.2f MB"
              % (s["traffic_in"] / 2**20, s["traffic_w"] / 2**20,
                 s["traffic_out"] / 2**20, s["traffic_total"] / 2**20))
        print("  cycles: serial %.3f M (%.1f ms) | overlapped %.3f M (%.1f ms)"
              % (s["cycles_serial"] / 1e6, s["ms_serial"],
                 s["cycles_overlap"] / 1e6, s["ms_overlap"]))
        print("  array utilisation: serial %.1f %% | overlapped %.1f %%"
              % (s["util_serial"] * 100, s["util_overlap"] * 100))
    print("\nwrote", outdir)


if __name__ == "__main__":
    main()
