import csv, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

rows = list(csv.DictReader(open('capture.csv')))
N = len(rows)
def bit(k): return [int(r[k]) for r in rows]
pc0 = [int(r['pc0'],16) for r in rows]
s0, s1 = 1200, 1720
idx = range(s0, s1)
fig, ax = plt.subplots(figsize=(13, 6.2), dpi=160)
ax.set_facecolor('white')
H = 1.0
ys = {'pc0': 6, 'commit0': 5, 'commit1': 4, 'lsel0': 3, 'lsel1': 2, 'ready': 1}
# pc0 as stepped line, level changes -> vertical edges
y = [ys['pc0'] + (0.35 if pc0[i] != (pc0[i-1] if i > 0 else pc0[i]) else 0) for i in idx]
ax.plot([i for i in idx], [ys['pc0'] + 0.35 for i in idx], color='#1a5fb4', lw=1.0)
# draw transitions for pc0
prev = None
for i in idx:
    v = pc0[i]
    if prev is not None and v != prev:
        ax.plot([i, i], [ys['pc0'] + 0.35, ys['pc0'] + 0.75], color='#1a5fb4', lw=0.8)
    prev = v
# bit signals
colors = {'commit0': '#c01c28', 'commit1': '#a51d2d', 'lsel0': '#26a269', 'lsel1': '#2ec27e', 'ready': '#5e5c64'}
for name, yy in ys.items():
    if name == 'pc0':
        continue
    b = bit(name)
    prev = 0
    for i in idx:
        v = b[i]
        if v != prev:
            ax.plot([i, i], [yy, yy + H*0.7], color=colors[name], lw=0.8)
        prev = v
    # segments
    start = s0
    cur = b[s0]
    for i in range(s0+1, s1+1):
        v = b[i] if i < N else cur
        if v != cur:
            ax.plot([start, i], [yy + (H*0.7 if cur else 0)]*2, color=colors[name], lw=1.2)
            start, cur = i, v
    ax.plot([start, s1], [yy + (H*0.7 if cur else 0)]*2, color=colors[name], lw=1.2)
ax.set_xlim(s0, s1)
ax.set_ylim(0.5, 8.0)
labels = ['ready', 'LANE_SEL_lane1', 'LANE_SEL_lane0', 'COMMIT_lane1', 'COMMIT_lane0', 'PC_lane0 (0x...)']
ax.set_yticks([1.35, 2.35, 3.35, 4.35, 5.35, 6.35])
ax.set_yticklabels(labels, fontsize=9)
ax.set_xlabel('sample index  (core_clk rising edge, 1 sample = 8.3016 ns)', fontsize=9)
ax.set_title('CoreMark on the RV32IMC core: on-chip ILA capture, 4095 samples @ 120.461538 MHz', fontsize=11)
ax.grid(axis='x', color='#dddddd', lw=0.4)
for s in ('top','right'):
    ax.spines[s].set_visible(False)
# annotate a few PC values
last = None
cnt = 0
for i in idx:
    if pc0[i] != last and pc0[i] != 0:
        if cnt % 7 == 0:
            ax.text(i, 7.15, f'{pc0[i]:05x}', fontsize=6, rotation=90, color='#1a5fb4', va='bottom')
        cnt += 1
    last = pc0[i]
plt.tight_layout()
plt.savefig('ila_wave.png', facecolor='white')
print('saved ila_wave.png')
