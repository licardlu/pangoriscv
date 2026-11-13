#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Plot logic-analyzer / ILA sample exports as publication-style digital waveforms.

Input : CSV, space-, tab- or semicolon-separated text.
        First non-comment line = signal names, every following line = one sample.
        Single-bit columns hold 0/1, bus columns hold hexadecimal values.

Output: white-background PNG, 1600 px wide, English labels only (no CJK font
        dependency), one lane per signal.

Examples
--------
python plot_wave.py capture.csv -o wave.png --title "RV32I ILA"
python plot_wave.py capture.csv --start 200 --end 600 --max-rows 8
python plot_wave.py capture.csv --bus pc --bit bus_req

Notes
-----
* A leading time/index column (named time, t, sample, index, cycle, ...) is
  detected and dropped; the x axis is the absolute sample index.
* Columns whose name contains pc/addr/bus are always drawn as buses.
  Columns whose values are only 0/1 (and whose name has no bus keyword) are
  drawn as single-bit signals. Everything else is drawn as a bus.
* --start / --end follow Python slice semantics: start inclusive, end exclusive.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass

import numpy as np

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from matplotlib.ticker import MaxNLocator

# --------------------------------------------------------------------------
# Style constants (light theme, print friendly)
# --------------------------------------------------------------------------
WIDTH_PX = 1600
DPI = 200
FIG_W_IN = WIDTH_PX / DPI          # 8.0 in -> exactly 1600 px
ROW_IN = 0.62                      # height of one signal lane
BIT_COLOR = "#123B6D"
BUS_EDGE = "#8A5100"
BUS_FILL = "#FBE3BE"
TEXT_COLOR = "#1A1A1A"
SUBTLE_TEXT = "#5F6368"
GRID_COLOR = "#DCDFE4"
LANE_COLOR = "#EDEFF3"
AXIS_COLOR = "#9AA0A6"

BUS_WORDS = {"pc", "addr", "bus"}
INDEX_NAMES = {
    "time", "t", "index", "idx", "sample", "samples", "sample_index",
    "n", "no", "cycle", "cycle_count", "clk_cnt", "cnt", "timestamp",
}
UNKNOWN_TOKENS = {"x", "z", "-", "", "na", "n/a"}


@dataclass
class Signal:
    name: str
    kind: str            # "bit" | "bus"
    values: np.ndarray   # int values, length == number of samples
    width: int           # hex digit width for bus labels


# --------------------------------------------------------------------------
# Parsing
# --------------------------------------------------------------------------
def _split(line: str, delim: str | None) -> list[str]:
    if delim is None:
        return [p for p in re.split(r"[\s]+", line.strip()) if p]
    return [p.strip() for p in line.split(delim)]


def _pick_delimiter(header: str) -> str | None:
    if "," in header:
        return ","
    if "\t" in header:
        return "\t"
    if ";" in header:
        return ";"
    return None


def _clean_token(tok: str) -> str:
    return tok.strip().strip('"').strip("'")


def _looks_like_data(line: str) -> bool:
    toks = _split(line, _pick_delimiter(line))
    if not toks:
        return False
    pat = re.compile(r"^(0x)?[0-9a-fA-F_]+h?$|^[xXzZ-]$")
    return all(pat.match(t) for t in toks)


def read_capture(path: str) -> tuple[list[str], list[list[str]]]:
    """Return (signal names, rows of raw tokens) with comments stripped."""
    with open(path, "r", encoding="utf-8-sig", errors="replace") as fh:
        raw = [ln.rstrip("\r\n") for ln in fh]

    lines = []
    for ln in raw:
        s = ln.strip()
        if not s or s.startswith("#") or s.startswith("//"):
            continue
        lines.append(s)
    if not lines:
        raise SystemExit(f"[error] no data found in {path}")

    delim = _pick_delimiter(lines[0])
    header = [_clean_token(t) for t in _split(lines[0], delim)]
    body_start = 1

    if _looks_like_data(lines[0]):          # headerless file
        header = [f"sig{i}" for i in range(len(header))]
        body_start = 0

    rows: list[list[str]] = []
    for lineno, line in enumerate(lines[body_start:], start=body_start + 1):
        toks = [_clean_token(t) for t in _split(line, delim)]
        if len(toks) != len(header):
            alt = [t for t in re.split(r"[,\t;]+|\s+", line) if t]
            if len(alt) == len(header):
                toks = alt
            else:
                raise SystemExit(
                    f"[error] line {lineno}: expected {len(header)} columns, "
                    f"got {len(toks)}"
                )
        rows.append(toks)

    if not rows:
        raise SystemExit(f"[error] {path} contains a header but no samples")

    # Drop a leading time/index column if present.
    if len(header) > 1 and header[0].strip().lower() in INDEX_NAMES:
        header = header[1:]
        rows = [r[1:] for r in rows]

    # Make duplicate names unique.
    seen: dict[str, int] = {}
    unique = []
    for name in header:
        if name in seen:
            seen[name] += 1
            unique.append(f"{name}_{seen[name]}")
        else:
            seen[name] = 0
            unique.append(name)
    return unique, rows


def parse_bus_token(tok: str) -> int | None:
    s = tok.strip().replace("_", "")
    low = s.lower()
    if low in UNKNOWN_TOKENS:
        return None
    if low.startswith("0x"):
        return int(low[2:], 16)
    if low.endswith("h") and len(low) > 1:
        return int(low[:-1], 16)
    if low.endswith("b") and len(low) > 1 and set(low[:-1]) <= {"0", "1"}:
        return int(low[:-1], 2)
    return int(low, 16)


def parse_bit_token(tok: str) -> int | None:
    low = tok.strip().lower()
    if low in UNKNOWN_TOKENS:
        return None
    if low in {"0", "1"}:
        return int(low)
    return None


def _has_bus_name(name: str) -> bool:
    """True for pc / pc_next / mem_addr / dbg_bus, False for 'busy'."""
    camel = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name)
    words = {w.lower() for w in re.split(r"[^A-Za-z0-9]+", camel) if w}
    return bool(words & BUS_WORDS)


def classify(name: str, tokens: list[str], force_bus: set[str],
             force_bit: set[str]) -> str:
    if name in force_bus:
        return "bus"
    if name in force_bit:
        return "bit"
    if _has_bus_name(name):
        return "bus"
    vals = {t.strip().lower() for t in tokens}
    if vals <= {"0", "1"}:
        return "bit"
    return "bus"


def build_signals(names: list[str], rows: list[list[str]],
                  force_bus: set[str], force_bit: set[str]) -> list[Signal]:
    columns = list(zip(*rows)) if rows else []
    signals: list[Signal] = []
    for i, name in enumerate(names):
        tokens = list(columns[i])
        kind = classify(name, tokens, force_bus, force_bit)
        if kind == "bit":
            vals: list[int] = []
            prev = 0
            unknown = 0
            for tok in tokens:
                v = parse_bit_token(tok)
                if v is None:
                    unknown += 1
                    v = prev
                prev = v
                vals.append(v)
            width = 0
        else:
            vals = []
            prev = 0
            unknown = 0
            for tok in tokens:
                try:
                    v = parse_bus_token(tok)
                except ValueError:
                    v = None
                if v is None:
                    unknown += 1
                    v = prev
                prev = v
                vals.append(v)
            digits = len(re.sub(r"(?i)^0x|h$", "", tokens[0].strip())) if tokens else 1
            for tok in tokens:
                digits = max(digits, len(re.sub(r"(?i)^0x|h$", "", tok.strip())))
            width = max(1, min(16, digits))
            if unknown:
                print(f"[warn] {name}: {unknown} unreadable bus value(s) held")
        if kind == "bit" and unknown:
            print(f"[warn] {name}: {unknown} unreadable bit value(s) held")
        dtype = np.int64 if kind == "bit" else np.uint64
        signals.append(Signal(name=name, kind=kind,
                              values=np.asarray(vals, dtype=dtype),
                              width=width))
    return signals


# --------------------------------------------------------------------------
# Run-length helpers
# --------------------------------------------------------------------------
def runs_of(values: np.ndarray) -> list[tuple[int, int, int]]:
    """[(start, end_exclusive, value), ...]"""
    n = len(values)
    if n == 0:
        return []
    change = np.flatnonzero(values[1:] != values[:-1]) + 1
    starts = np.concatenate(([0], change))
    ends = np.concatenate((change, [n]))
    return [(int(s), int(e), int(values[s])) for s, e in zip(starts, ends)]


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
def _text_width_px(fig, text: str, fontsize: float) -> float:
    """Rendered width of a string in device pixels at the figure DPI."""
    t = fig.text(0.0, 0.0, text, fontsize=fontsize,
                 fontfamily="DejaVu Sans", alpha=0.0)
    width = t.get_window_extent(renderer=fig.canvas.get_renderer()).width
    t.remove()
    return width


def _bit_level(y: float, val: int) -> float:
    return y + (0.30 if val else -0.30)


def draw_bit(ax, x0: int, x1: int, y: float, values: np.ndarray,
             px_per_sample: float) -> None:
    runs = [(s + x0, e + x0, v) for s, e, v in runs_of(values)]
    xs = [runs[0][0]]
    ys = [_bit_level(y, runs[0][2])]
    for i in range(1, len(runs)):
        b = runs[i][0]
        xs += [b, b]
        ys += [_bit_level(y, runs[i - 1][2]), _bit_level(y, runs[i][2])]
    xs.append(x1)
    ys.append(ys[-1])
    ax.plot(xs, ys, color=BIT_COLOR, lw=1.25, solid_joinstyle="miter",
            solid_capstyle="butt", zorder=3)

    if px_per_sample >= 16:      # sparse capture: show actual sample points
        idx = np.arange(len(values)) + x0
        ax.plot(idx, _bit_level(y, 0) + np.where(values > 0, 0.60, 0.0),
                ls="none", marker="o", ms=1.8, color=BIT_COLOR, zorder=4)


def draw_bus(ax, x0: int, x1: int, y: float, values: np.ndarray, width: int,
             px_per_sample: float, axes_px: float) -> None:
    half = 0.30
    runs = [(s + x0, e + x0, v) for s, e, v in runs_of(values)]
    lengths = [e - s for s, e, _ in runs]

    # Chamfer half-width at every run boundary: ~0.4 sample, capped at 3.5 px
    # so dense buses keep a flat top instead of turning into hatching.
    before = [0.0] * len(runs)
    after = [0.0] * len(runs)
    for i in range(1, len(runs)):
        t = min(0.45, 0.40 * min(lengths[i - 1], lengths[i]),
                3.5 / max(px_per_sample, 1e-6))
        after[i - 1] = t
        before[i] = t

    polys: list[list[tuple[float, float]]] = []
    for i, (s, e, _) in enumerate(runs):
        gs, ge = s + before[i], e - after[i]
        if ge <= gs:
            gs, ge = s, e
        polys.append([(gs, y - half), (ge, y - half),
                      (ge, y + half), (gs, y + half)])
        if i + 1 < len(runs):    # fill the crossing region between runs
            b, t = e, after[i]
            polys.append([(b - t, y + half), (b + t, y + half), (b + t, y - half)])
            polys.append([(b - t, y + half), (b - t, y - half), (b + t, y - half)])
    if polys:
        ax.add_collection(PolyCollection(
            polys, facecolors=BUS_FILL, edgecolors="none", zorder=2))

    # two interleaved outlines -> classic crossing "X" at every transition
    top_x, top_y, bot_x, bot_y = [], [], [], []
    for i, (s, e, _) in enumerate(runs):
        gs, ge = s + before[i], e - after[i]
        if ge <= gs:
            gs, ge = s, e
        top_x += [gs, ge]
        top_y += [y + half, y + half]
        bot_x += [gs, ge]
        bot_y += [y - half, y - half]
        if i + 1 < len(runs):
            nxt = runs[i + 1][0] + before[i + 1]
            top_x += [nxt]
            top_y += [y - half]
            bot_x += [nxt]
            bot_y += [y + half]
    ax.plot(top_x, top_y, color=BUS_EDGE, lw=1.0, zorder=3,
            solid_joinstyle="miter")
    ax.plot(bot_x, bot_y, color=BUS_EDGE, lw=1.0, zorder=3,
            solid_joinstyle="miter")

    # Hex labels: greedy left to right with a minimum centre spacing.  A label
    # that fits inside a run is drawn in the band; otherwise it floats just
    # above the band so that dense buses still get annotated without smearing.
    n_lanes = max(1, int(round(ax.get_ylim()[1] - ax.get_ylim()[0])))
    fs = 7.0 if n_lanes <= 14 else 6.5
    probe = "0x" + "0" * width
    label_px = _text_width_px(ax.figure, probe, fs) + 4.0
    span = max(x1 - x0, 1)

    chosen: list[tuple[float, int, bool]] = []
    last_px = -1e9
    for s, e, val in runs:
        cx = ((s + e) / 2.0 - x0) / span * axes_px
        if cx - label_px / 2.0 < 1.0 or cx + label_px / 2.0 > axes_px - 1.0:
            continue
        inside = (e - s) * px_per_sample >= label_px * 0.98
        if cx - last_px < label_px + (14.0 if inside else 26.0):
            continue
        chosen.append(((s + e) / 2.0, val, inside))
        last_px = cx
        if len(chosen) >= 14:
            break

    for xc, val, inside in chosen:
        if not inside:           # stem anchors the floating label to its run
            ax.plot([xc, xc], [y + half + 0.01, y + 0.385],
                    color=BUS_EDGE, lw=0.8, zorder=5)
        ax.text(xc, y if inside else y + 0.39, f"0x{val:0{width}X}",
                ha="center", va="center" if inside else "bottom",
                fontsize=fs, color="#4A2A00", zorder=5, clip_on=False,
                fontfamily="DejaVu Sans",
                bbox=dict(boxstyle="square,pad=0.12", fc="white",
                          ec="none", alpha=0.82))


def plot_capture(signals: list[Signal], start: int, end: int,
                 title: str, subtitle: str, out_path: str) -> tuple[int, int]:
    n = len(signals)
    n_samples = end - start
    if n == 0 or n_samples <= 0:
        raise SystemExit("[error] nothing to plot after cropping")

    top_in = 1.15
    bottom_in = 0.92
    fig_h_in = top_in + ROW_IN * n + bottom_in
    left_in = min(2.30, 0.34 + 0.058 * max(len(s.name) for s in signals))
    right_in = 0.22

    left = left_in / FIG_W_IN
    right = 1.0 - right_in / FIG_W_IN
    bottom = bottom_in / fig_h_in
    height = (ROW_IN * n) / fig_h_in

    fig = plt.figure(figsize=(FIG_W_IN, fig_h_in), dpi=DPI, facecolor="white")
    ax = fig.add_axes([left, bottom, right - left, height], facecolor="white")
    ax.set_ylim(-0.5, n - 0.5)

    px_per_sample = (FIG_W_IN * DPI * (right - left)) / n_samples
    axes_px = FIG_W_IN * DPI * (right - left)

    for i, sig in enumerate(signals):
        y = (n - 1 - i)
        vals = sig.values[start:end]
        if sig.kind == "bit":
            draw_bit(ax, start, end, y, vals, px_per_sample)
        else:
            draw_bus(ax, start, end, y, vals, sig.width,
                     px_per_sample, axes_px)

    ax.set_xlim(start - 0.2, end + 0.2)

    # lane separators
    for i in range(n - 1):
        ax.axhline((n - 1 - i) - 0.5, color=LANE_COLOR, lw=0.6, zorder=1)

    ax.set_yticks(np.arange(n)[::-1])
    ax.set_yticklabels([s.name for s in signals])
    ax.tick_params(axis="y", length=0, pad=7, labelsize=7.6)
    for lbl in ax.get_yticklabels():
        lbl.set_color(TEXT_COLOR)
        lbl.set_fontfamily("DejaVu Sans")

    ax.xaxis.set_major_locator(MaxNLocator(nbins=10, integer=True))
    ax.tick_params(axis="x", labelsize=7.4, colors=SUBTLE_TEXT, length=3)
    ax.grid(axis="x", color=GRID_COLOR, ls=":", lw=0.7, zorder=0)
    ax.set_axisbelow(True)

    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(AXIS_COLOR)
    ax.spines["bottom"].set_linewidth(0.8)

    ax.set_xlabel("Samples (core_clk rising edge)", fontsize=8.6,
                  color=TEXT_COLOR, labelpad=7, fontfamily="DejaVu Sans")

    fig.text(0.5, 1.0 - 0.36 / fig_h_in, title, ha="center", va="center",
             fontsize=12, fontweight="bold", color="#111111",
             fontfamily="DejaVu Sans")
    fig.text(0.5, 1.0 - 0.66 / fig_h_in, subtitle, ha="center", va="center",
             fontsize=7.4, color=SUBTLE_TEXT, fontfamily="DejaVu Sans")

    fig.savefig(out_path, dpi=DPI, facecolor="white")
    plt.close(fig)
    return WIDTH_PX, int(round(fig_h_in * DPI))


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def _names(arg: str | None) -> set[str]:
    if not arg:
        return set()
    return {p.strip() for p in arg.split(",") if p.strip()}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Render digital ILA/logic-analyzer samples as a "
                    "publication-quality waveform PNG (1600 px wide).")
    ap.add_argument("input", help="CSV / space-separated capture file")
    ap.add_argument("-o", "--out", help="output PNG (default: <input>.png)")
    ap.add_argument("--title", default="ILA Capture", help="figure title")
    ap.add_argument("--start", type=int, default=0,
                    help="first sample index, inclusive (default 0)")
    ap.add_argument("--end", type=int, default=None,
                    help="last sample index, exclusive (default: all)")
    ap.add_argument("--max-rows", type=int, default=None,
                    help="plot at most N signal lanes (default: all)")
    ap.add_argument("--bus", default=None,
                    help="comma-separated names forced to bus rendering")
    ap.add_argument("--bit", default=None,
                    help="comma-separated names forced to single-bit rendering")
    args = ap.parse_args(argv)

    names, rows = read_capture(args.input)
    total = len(rows)

    start = max(0, args.start)
    end = total if args.end is None else min(total, args.end)
    if start >= end:
        raise SystemExit(
            f"[error] empty range: start={start}, end={end}, samples={total}")

    signals = build_signals(names, rows, _names(args.bus), _names(args.bit))

    if args.max_rows is not None:
        if args.max_rows <= 0:
            raise SystemExit("[error] --max-rows must be positive")
        if len(signals) > args.max_rows:
            print(f"[info] plotting first {args.max_rows} of "
                  f"{len(signals)} signals (--max-rows)")
            signals = signals[:args.max_rows]

    out = args.out or os.path.splitext(args.input)[0] + ".png"
    out_dir = os.path.dirname(os.path.abspath(out))
    os.makedirs(out_dir, exist_ok=True)

    subtitle = (f"{os.path.basename(args.input)}   |   "
                f"samples [{start}, {end})   |   "
                f"N = {end - start}   |   {len(signals)} lanes")
    w, h = plot_capture(signals, start, end, args.title, subtitle, out)

    bits = [s.name for s in signals if s.kind == "bit"]
    buses = [f"{s.name}[{s.width * 4}b]" for s in signals if s.kind == "bus"]
    print(f"[ok] samples={total}  range=[{start},{end})  lanes={len(signals)}")
    print(f"[ok] bit : {', '.join(bits) if bits else '-'}")
    print(f"[ok] bus : {', '.join(buses) if buses else '-'}")
    print(f"[ok] wrote {out}  ({w} x {h} px, {DPI} dpi)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
