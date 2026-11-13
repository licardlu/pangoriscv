import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

rows = list(csv.DictReader(open('capture.csv')))
N = len(rows)
pc0 = [int(r['pc0'],16) for r in rows]
sig = {k: [int(r[k]) for r in rows] for k in ('commit0','commit1','lsel0','lsel1','ready')}
s0, s1 = 812, 952
fig, ax = plt.subplots(figsize=(12.5, 5.6), dpi=170)
names = [('pc0','PC_lane0', 6.0), ('commit0','COMMIT_lane0 (held 1)',4.7), ('commit1','COMMIT_lane1 (held 1)',3.8),
         ('lsel0','LANE_SEL_lane0',2.6), ('lsel1','LANE_SEL_lane1',1.6), ('ready','isReady',0.6)]
# bus row
base = 6.0
ax.plot([s0, s1+1], [base, base], color='#1a5fb4', lw=1.2, zorder=2)
prev = None; last_x = -99
for i in range(s0, s1+1):
    v = pc0[i]
    if prev is not None and v != prev:
        ax.plot([i, i], [base-0.28, base+0.28], color='#1a5fb4', lw=1.1, zorder=3)
        if i - last_x > 9 and v:
            ax.text(i, base+0.33, f'{v:05x}', fontsize=6.2, rotation=0, ha='center', va='bottom', color='#1a5fb4')
            last_x = i
    prev = v
# bits
for key, label, y in names[1:]:
    b = sig[key]
    for i in range(s0, s1+1):
        if b[i]:
            ax.add_patch(Rectangle((i, y), 1.0, 0.22, color='#c01c28' if 'commit' in key else ('#26a269' if 'lsel' in key else '#5e5c64'), lw=0, zorder=2))
    ax.plot([s0, s1+1], [y, y], color='#999999', lw=0.5, zorder=1)
ax.set_yticks([n[2]+0.15 for n in names])
ax.set_yticklabels([n[1] for n in names], fontsize=9)
ax.set_xlim(s0, s1+1); ax.set_ylim(-0.15, 7.0)
ax.set_xlabel('sample index (core_clk rising edge, 8.3016 ns per sample)', fontsize=9)
ax.set_title('On-chip ILA capture of the RV32IMC core running CoreMark (4095 samples @ 120.461538 MHz)', fontsize=10.5)
ax.grid(axis='x', color='#e5e5e5', lw=0.4)
for s in ('top','right','left'):
    ax.spines[s].set_visible(False)
ax.tick_params(axis='y', length=0)
plt.tight_layout()
plt.savefig('ila_wave.png', facecolor='white')
print('ok')
