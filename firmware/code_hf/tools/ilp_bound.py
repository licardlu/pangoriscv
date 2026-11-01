#!/usr/bin/env python3
"""Static issue-width bound for the CoreMark instruction stream.

Why: docs/plan-v16-120mhz-spec.md gate M1 asks "can a 4-wide core reach
IPC_live >= 2.85?".  Writing the 4-wide RTL costs weeks; scheduling the
disassembly costs a minute.  The model is calibrated against the *measured*
2-wide IPC_live (1.7525, see docs/performance-analysis.md) so the 4-wide
number is an extrapolation of a validated model, not a guess.

Model
-----
In-order, greedy list scheduling inside each basic block:
  * at most W instructions per cycle,
  * at most MEMP memory ops per cycle (load/store share the D$ port),
  * at most 1 control transfer per cycle,
  * RAW: a consumer may issue no earlier than producer_cycle + 1
    (matches this core: ALU result is forwarded at the end of the cycle,
     a load's data likewise -- see the pkt_lduse bucket).
Branches end a basic block; the mispredict cost is NOT part of this model
(it is accounted separately as the 26,557 dead cycles).

Usage: python tools/ilp_bound.py <firmware.dump>
"""
import re
import sys
from collections import defaultdict

INSN = re.compile(r'^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+(\S+)\s*(.*)$')
LABEL = re.compile(r'^([0-9a-f]+)\s+<([^>]+)>:')

MEM_MN = ('lw', 'lh', 'lhu', 'lb', 'lbu', 'sw', 'sh', 'sb')
CTRL_MN = ('beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu', 'jal', 'jalr')
NOSRC = ('lui', 'auipc', 'j', 'nop', 'ecall', 'ebreak', 'fence', 'mret', 'wfi')


def regs_of(mn, ops):
    """Return (rd, [rs...]) for a mnemonic/operand string."""
    ops = ops.split('#')[0].strip()
    if not ops:
        return None, []
    parts = [p.strip() for p in ops.split(',')]
    rd = parts[0] if parts else None
    rs = []
    if mn in NOSRC:
        rs = []
    elif mn in CTRL_MN:
        # beq rs1, rs2, target / jal rd, target / jalr rd, rs1, off
        if mn == 'jal':
            rs = []
        elif mn == 'jalr':
            rs = [parts[1]] if len(parts) > 1 else []
        else:
            rs = [parts[0], parts[1]] if len(parts) > 1 else []
    elif mn in MEM_MN:
        # lw rd, off(rs1) / sw rs2, off(rs1)
        m = re.search(r'\((\w+)\)', ops)
        base = m.group(1) if m else None
        if mn.startswith('s'):
            rd = None
            rs = [parts[0]] + ([base] if base else [])
        else:
            rs = [base] if base else []
    elif mn in ('csrrw', 'csrrs', 'csrrc'):
        rs = [parts[2]] if len(parts) > 2 else []
    else:
        rs = parts[1:]
    return rd, [r for r in rs if r]


def schedule(block, width, memports):
    """Greedy in-order schedule of one basic block -> number of cycles."""
    prod = {}                     # reg -> cycle it becomes available
    cyc_cnt = defaultdict(int)    # cycle -> instructions issued
    cyc_mem = defaultdict(int)
    cyc_ctrl = defaultdict(int)
    last = 0
    for mn, rd, rs in block:
        earliest = 1
        for r in rs:
            if r in prod:
                earliest = max(earliest, prod[r] + 1)
        is_mem = mn in MEM_MN
        is_ctrl = mn in CTRL_MN
        c = max(earliest, last)
        while (cyc_cnt[c] >= width
               or (is_mem and cyc_mem[c] >= memports)
               or (is_ctrl and cyc_ctrl[c] >= 1)):
            c += 1
        cyc_cnt[c] += 1
        if is_mem:
            cyc_mem[c] += 1
        if is_ctrl:
            cyc_ctrl[c] += 1
        if rd and rd != 'zero' and rd != 'x0':
            prod[rd] = c
        last = c
    return max(cyc_cnt) if cyc_cnt else 0


def main(path):
    blocks = []      # list of (symbol, [ (mn, rd, rs) ])
    cur, sym = [], None
    with open(path, 'r', errors='replace') as fh:
        for line in fh:
            m = LABEL.match(line.strip())
            if m:
                if cur:
                    blocks.append((sym, cur))
                cur, sym = [], m.group(2)
                continue
            m = INSN.match(line.rstrip('\n'))
            if not m:
                continue
            mn, ops = m.group(3), m.group(4)
            rd, rs = regs_of(mn, ops)
            cur.append((mn, rd, rs))
            if mn in CTRL_MN:          # a control transfer ends the block
                blocks.append((sym, cur))
                cur = []
    if cur:
        blocks.append((sym, cur))

    total = sum(len(b) for _, b in blocks)
    mem = sum(1 for _, b in blocks for i in b if i[0] in MEM_MN)
    ctrl = sum(1 for _, b in blocks for i in b if i[0] in CTRL_MN)
    print(f"blocks={len(blocks)}  instructions={total}  "
          f"mem={mem} ({100*mem/total:.1f}%)  ctrl={ctrl} ({100*ctrl/total:.1f}%)")
    lens = [len(b) for _, b in blocks if b]
    print(f"basic-block length: mean={sum(lens)/len(lens):.2f}  max={max(lens)}")

    print(f"\n{'width':>5} {'memports':>8} {'cycles':>8} {'CPI':>7} {'IPC':>7}")
    base = None
    for width, mp in ((2, 1), (2, 2), (3, 1), (3, 2), (4, 1), (4, 2), (4, 4), (6, 2)):
        cyc = sum(schedule(b, width, mp) for _, b in blocks)
        ipc = total / cyc
        if (width, mp) == (2, 1):
            base = ipc
        print(f"{width:>5} {mp:>8} {cyc:>8} {cyc/total:>7.3f} {ipc:>7.3f}")

    # calibrate: measured IPC_live at 2-wide / 1 mem port = 1.7525
    MEAS = 1.7525
    print(f"\ncalibration: model(2w,1mp) IPC={base:.3f}, measured={MEAS:.4f}, "
          f"k={MEAS/base:.3f}")
    print(f"{'width':>5} {'memports':>8} {'model IPC':>10} {'calibrated':>11} "
          f"{'ticks/iter':>11} {'score':>7}")
    DEAD, I = 26557, 289123
    for width, mp in ((2, 1), (3, 1), (3, 2), (4, 1), (4, 2), (4, 4)):
        cyc = sum(schedule(b, width, mp) for _, b in blocks)
        cal = (total / cyc) * (MEAS / base)
        ticks = DEAD + I / cal
        print(f"{width:>5} {mp:>8} {total/cyc:>10.3f} {cal:>11.3f} "
              f"{ticks:>11.0f} {1e6/ticks:>7.3f}")


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'firmware.dump')
