"""Audit downloaded detection labels and build a reproducible grouped split.

No automatic relabeling of classification-only data. Source folders must contain
real YOLO box labels. Missing/corrupt/invalid images are excluded and logged.
Exact decoded duplicates and near duplicates (64-bit pHash distance <=4) share a
split. Physical object/session IDs are unavailable: this is NOT an instance-held-
out camera benchmark. The test set is never used to choose checkpoints.
"""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import random
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.fft import dctn
import yaml

NAMES = ['kitchen', 'recyclable', 'hazardous', 'other']
MAPS = {'codingbear': {0: 1, 1: 3, 2: 2, 3: 1, 4: 0, 5: 3, 6: 1, 7: 2, 8: 0, 9: 0, 10: 3, 11: 0},
        'sumn2u': {0: 1, 1: 3, 2: 1, 3: 1, 4: 1, 5: 1, 6: 0}}


def inspect(item):
    source, ip, lp = item
    try:
        if not lp.is_file():
            raise ValueError('missing label')
        with Image.open(ip) as im:
            im.verify()
        with Image.open(ip) as im:
            rgb = im.convert('RGB')
            rgb.load()
            w, h = rgb.size
            if min(w, h) < 32:
                raise ValueError('image too small')
            content = hashlib.sha256(np.array(rgb).tobytes() + str((w, h)).encode()).hexdigest()
            gray = np.array(rgb.resize((32, 32)).convert('L'), dtype=float)
            freq = dctn(gray, norm='ortho')[:8, :8].flatten()
            phash = int(''.join('1' if v > np.median(freq[1:]) else '0' for v in freq), 2)
        boxes = []
        for line in lp.read_text(encoding='utf-8-sig').splitlines():
            if not line.strip():
                continue
            vals = list(map(float, line.split()))
            if len(vals) != 5 or not np.isfinite(vals).all():
                raise ValueError('non-box or nonfinite label')
            cid, x, y, bw, bh = vals
            if cid != int(cid) or int(cid) not in MAPS[source]:
                raise ValueError('unknown class')
            if min(bw, bh) <= 0 or min(x-bw/2, y-bh/2) < -0.002 or max(x+bw/2, y+bh/2) > 1.002:
                raise ValueError('invalid box bounds')
            # Roundoff at image boundaries is clamped, without changing labels.
            x1, y1, x2, y2 = max(0., x-bw/2), max(0., y-bh/2), min(1., x+bw/2), min(1., y+bh/2)
            boxes.append([MAPS[source][int(cid)], (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1])
        return {'source': source, 'image': str(ip.resolve()), 'label': str(lp.resolve()),
                'width': w, 'height': h, 'sha256_pixels': content, 'phash': phash, 'boxes': boxes,
                'original_labels': lp.read_text(encoding='utf-8-sig')}
    except Exception as e:
        return {'source': source, 'image': str(ip.resolve()), 'error': str(e)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--raw', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--seed', type=int, default=20261111)
    ap.add_argument('--max-train-per-bin', type=int, default=800)
    a = ap.parse_args()
    if a.out.exists():
        raise SystemExit('Output exists; use a fresh output directory')
    a.out.mkdir(parents=True)
    tasks = []
    for source in MAPS:
        for ip in sorted((a.raw/source).rglob('*')):
            if ip.suffix.lower() not in {'.jpg', '.jpeg', '.png'} or ip.parent.name != 'images' and ip.parent.parent.name != 'images':
                continue
            parts = list(ip.parts)
            parts[parts.index('images')] = 'labels'
            tasks.append((source, ip, Path(*parts).with_suffix('.txt')))
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(inspect, tasks))
    bad = [r for r in results if 'error' in r]
    rows = [r for r in results if 'error' not in r and r['boxes']]
    label_sets = defaultdict(set)
    for r in rows:
        label_sets[r['sha256_pixels']].add(tuple(sorted({int(b[0]) for b in r['boxes']})))
    conflicts = {h for h, sets in label_sets.items() if len(sets)>1}
    conflicted_rows = [r for r in rows if r['sha256_pixels'] in conflicts]
    rows = [r for r in rows if r['sha256_pixels'] not in conflicts]
    print('Audited', len(results), 'valid labeled', len(rows), 'rejected', len(bad), flush=True)
    parent = list(range(len(rows)))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    def join(i, j):
        parent[find(i)] = find(j)
    exact, bands = {}, defaultdict(list)
    near_links = 0
    for i, r in enumerate(rows):
        if r['sha256_pixels'] in exact:
            join(i, exact[r['sha256_pixels']])
        else:
            exact[r['sha256_pixels']] = i
        # With <=4 different bits, at least one of five disjoint bands is equal.
        candidates = set()
        for b in range(5):
            candidates.update(bands[(b, (r['phash'] >> (b*13)) & (0x1fff if b<4 else 0xfff))])
        for j in candidates:
            if bin(r['phash'] ^ rows[j]['phash']).count('1') <= 4:
                join(i, j)
                near_links += 1
        for b in range(5):
            bands[(b, (r['phash'] >> (b*13)) & (0x1fff if b<4 else 0xfff))].append(i)
    groups = defaultdict(list)
    for i in range(len(rows)):
        groups[find(i)].append(i)
    rng = random.Random(a.seed)
    strata = defaultdict(list)
    for gid, members in groups.items():
        cls = Counter(int(b[0]) for i in members for b in rows[i]['boxes']).most_common(1)[0][0]
        strata[(rows[members[0]]['source'], cls)].append((gid, members))
    assigned = {}
    for stratum, gs in sorted(strata.items()):
        rng.shuffle(gs)
        for j, (gid, members) in enumerate(gs):
            split = 'test' if j < max(1, round(len(gs)*.15)) else 'val' if j < max(2, round(len(gs)*.30)) else 'train'
            for i in members:
                assigned[i] = split
    # Deduplicate identical pixels within each split, then cap dominant bins.
    output, counts, seen = [], Counter(), set()
    indices = list(range(len(rows)))
    rng.shuffle(indices)
    for i in indices:
        r, split = rows[i], assigned[i]
        key = r['sha256_pixels']
        if key in seen:
            continue
        seen.add(key)
        cls = Counter(int(b[0]) for b in r['boxes']).most_common(1)[0][0]
        if split == 'train' and counts[(split, cls)] >= a.max_train_per_bin:
            continue
        counts[(split, cls)] += 1
        r.update(split=split, group=find(i), primary_bin=cls)
        uid = r['source']+'_'+r['sha256_pixels'][:20]
        im_out = a.out/'images'/split/(uid+'.jpg')
        lab_out = a.out/'labels'/split/(uid+'.txt')
        im_out.parent.mkdir(parents=True, exist_ok=True)
        lab_out.parent.mkdir(parents=True, exist_ok=True)
        # Same aspect ratio and pixels (apart from JPEG) retained; YOLO letterboxes.
        with Image.open(r['image']) as im:
            rgb = im.convert('RGB')
            rgb.thumbnail((640, 640))
            rgb.save(im_out, quality=95)
        lab_out.write_text(''.join(str(int(b[0]))+' '+' '.join(f'{v:.7f}' for v in b[1:])+'\n' for b in r['boxes']))
        r['prepared_image'] = str(im_out.resolve())
        output.append(r)
    splits = {}
    for split in ['train', 'val', 'test']:
        ss = [r for r in output if r['split']==split]
        splits[split] = {'images': len(ss), 'images_by_primary_bin': {NAMES[k]: sum(r['primary_bin']==k for r in ss) for k in range(4)},
                         'boxes': dict(Counter(NAMES[int(b[0])] for r in ss for b in r['boxes']))}
        if any(splits[split]['boxes'].get(n, 0)==0 for n in NAMES):
            raise RuntimeError('Missing bin coverage: '+split)
    for s in ['train', 'val', 'test']:
        for t in ['train', 'val', 'test']:
            if s >= t:
                continue
            assert not ({r['group'] for r in output if r['split']==s} & {r['group'] for r in output if r['split']==t})
    (a.out/'data.yaml').write_text(yaml.safe_dump({'path': str(a.out.resolve()).replace('\\','/'), 'train': 'images/train', 'val': 'images/val', 'test': 'images/test', 'nc': 4, 'names': NAMES}), encoding='utf-8')
    (a.out/'manifest.json').write_text(json.dumps(output, indent=2), encoding='utf-8')
    report = {'seed': a.seed, 'audited': len(results), 'rejected': bad, 'empty_labeled': sum('error' not in r and not r['boxes'] for r in results),
              'conflicting_duplicate_images': [r['image'] for r in conflicted_rows],
              'unique_pixels': len(exact), 'visual_groups': len(groups), 'near_duplicate_links': near_links,
              'splits': splits, 'limitations': ['No physical instance/session IDs; visually dissimilar views may still show the same object.',
              'Public-image test results do not measure FPGA camera accuracy.', 'Negative empty scenes must be supplemented with board captures.']}
    (a.out/'audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report['splits'], indent=2), flush=True)
    # Deterministic random samples with boxes, not model predictions.
    canvas = Image.new('RGB', (1200, 4*240), 'white')
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 16)
    chosen = []
    for k in range(4):
        pool = [r for r in output if r['primary_bin']==k]
        for col, r in enumerate(rng.sample(pool, min(5,len(pool)))):
            im = Image.open(r['prepared_image']).convert('RGB')
            w,h = im.size
            d = ImageDraw.Draw(im)
            for cid,x,y,bw,bh in r['boxes']:
                d.rectangle(((x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h), outline='red', width=3)
            im.thumbnail((236,210))
            canvas.paste(im,(col*240,k*240))
            ImageDraw.Draw(canvas).text((col*240+2,k*240+214),NAMES[k]+' / '+r['source'],font=font,fill='black')
            chosen.append(r['image'])
    canvas.save(a.out/'samples.jpg')
    (a.out/'sample_sources.json').write_text(json.dumps(chosen, indent=2))


if __name__ == '__main__':
    main()
