"""Propose complete foam-object extents for explicit visual review, train only.

This source duplicates each instance with a polygon and a near-identical box.
Merge those extent proposals for review only; no images are admitted here.
"""
import argparse
import hashlib
import json
from pathlib import Path
from collect_public_expansion import sheets


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def xyxy(box):
    _, cx, cy, w, h = box
    return [cx-w/2, cy-h/2, cx+w/2, cy+h/2]


def iou(a, b):
    inter = max(0, min(a[2], b[2])-max(a[0], b[0])) * max(0, min(a[3], b[3])-max(a[1], b[1]))
    return inter / ((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-inter)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--count', type=int, default=96)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    assert 1 <= args.count <= 192
    root = Path('build/noon_continuation_20261118_001/research/organic_001/other_audit_002')
    rows = [r for r in read(root/'inventory.json') if r['admission'].startswith('PENDING_')
            and all(b[0] == 33 for b in r['source_boxes'])]
    rows.sort(key=lambda r: hashlib.sha256(r['id'].encode()).hexdigest())
    selected = []
    for index, row in enumerate(rows[:args.count], 1):
        extents = []
        for b in row['source_boxes']:
            candidate = xyxy(b)
            match = next((n for n, old in enumerate(extents) if iou(old, candidate) >= .85), None)
            if match is None:
                extents.append(candidate)
            else:
                old = extents[match]
                extents[match] = [min(old[0],candidate[0]), min(old[1],candidate[1]),
                                  max(old[2],candidate[2]), max(old[3],candidate[3])]
        boxes = [[3, (x1+x2)/2, (y1+y2)/2, x2-x1, y2-y1] for x1,y1,x2,y2 in extents]
        w,h = row['width'],row['height']
        selected.append(dict(row, source_id=row['id'], id=f"{index:03}_"+row['id'], review_index=index,
            proposed_boxes=boxes, category_names={'3':'other'},
            annotations=[dict(category_id=3,bbox=[x1*w,y1*h,(x2-x1)*w,(y2-y1)*h]) for x1,y1,x2,y2 in extents],
            annotation_status='PROPOSED_MERGED_EXTENTS_NOT_ADMITTED'))
    args.out.mkdir(parents=True,exist_ok=False)
    (args.out/'review_order.json').write_text(json.dumps(selected,indent=2),encoding='utf8')
    sheets(selected,args.out,'foam')
    print(dict(review_proposals=len(selected), admitted=0),flush=True)


if __name__ == '__main__':
    main()
