"""Score saved public validation detections; no inference, tuning, or AP claim."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NAMES = ['kitchen', 'recyclable', 'hazardous', 'other']


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf8'))


def iou(a, b):
    area = lambda x:max(0, x[2]-x[0])*max(0, x[3]-x[1])
    overlap = max(0, min(a[2], b[2])-max(a[0], b[0]))*max(0, min(a[3], b[3])-max(a[1], b[1]))
    union = area(a)+area(b)-overlap
    return overlap/union if union > 0 else 0


def match(ds, gt):
    # Descending detection confidence; each GT used once; best unmatched
    # same-class IoU, inclusive0.5. No image-level label substitution.
    counts = [[0, 0, sum(g['category'] == k for g in gt)] for k in range(4)]
    used = set()
    for d in sorted(ds, key=lambda d:-d['score']):
        cls = d['category']
        if cls not in range(4) or d['score'] < .25-1e-7:
            raise ValueError('Unexpected decoder schema or floor')
        best, index = max(((iou(d['box'], g['box']), k) for k, g in enumerate(gt)
                           if k not in used and g['category'] == cls), default=(0, -1))
        if best >= .5:
            counts[cls][0] += 1; used.add(index)
        else: counts[cls][1] += 1
    return counts


def main():
    exact = dict(category=2, box=[0, 0, 20, 20], score=.9)
    assert match([exact, exact], [exact])[2] == [1, 1, 1]
    assert match([dict(exact, category=1)], [exact])[2] == [0, 0, 1]
    assert match([], [exact])[2] == [0, 0, 1]
    prep = read(ROOT/'preparation.json')
    numeric = read(ROOT/'numeric/result.json')
    truth = read(ROOT/'fixtures/truth.json')['images']
    inventory = read(ROOT/'fixtures/inventory.json')
    preds = read(ROOT/'numeric/predictions.json')
    assert numeric['status'] == 'PASS' and numeric['images'] == 1508
    assert numeric['truth_sha256'] == prep['truth_sha256'] == sha(ROOT/'fixtures/truth.json')
    assert prep['inventory_sha256'] == sha(ROOT/'fixtures/inventory.json')
    assert len(preds) == len(truth) == len(inventory) == 1508
    assert len({p['id'] for p in preds}) == 1508
    assert {p['id'] for p in preds} == {g['id'] for g in truth}
    by_id = {p['id']:p for p in preds}
    totals = [[0, 0, 0] for _ in range(4)]
    for row, inv in zip(truth, inventory):
        pred = by_id[row['id']]
        assert inv['id'] == row['id'] and pred['file'] == inv['file']
        assert sha(Path(inv['path'])) == inv['sha256']
        for dst, src in zip(totals, match(pred['detections'], row['gt'])):
            for k in range(3): dst[k] += src[k]
    def metric(c):
        tp, fp, gt = c
        return dict(TP=tp, FP=fp, FN=gt-tp, GT=gt, precision=tp/(tp+fp) if tp+fp else 0,
                    recall=tp/gt if gt else 0)
    result = dict(status='FIXED_PUBLIC_VAL_OPERATING_POINT_EVALUATED', images=1508,
                  model_sha256=numeric['model_sha256'], conf=.25, nms_iou=.45, max_detections=32, matching_iou=.5,
                  matching='Per-image descending-confidence, best unmatched same-class IoU>=.5',
                  per_class={n:metric(c) for n, c in zip(NAMES, totals)},
                  micro=metric([sum(c[k] for c in totals) for k in range(3)]),
                  numeric_sha256=sha(ROOT/'numeric/result.json'), predictions_sha256=sha(ROOT/'numeric/predictions.json'),
                  fixture_truth_sha256=sha(ROOT/'fixtures/truth.json'), script_sha256=sha(Path(__file__)),
                  split='val', test_used=False, board_programmed=False, model_selection_frozen=True,
                  limits=['Offline Q15 convolution oracle and actual C head/decoder, not FPGA/camera accuracy',
                          'Original public development validation, not new held-out physical instances',
                          'Fixed-threshold detection Precision/Recall, not AP or single-target game accuracy',
                          'Sparse deployment head discards low-confidence anchors, so complete AP is not reported',
                          'No changes to frozen model, confidence, policy or training after these results'])
    with (ROOT/'fixed_metrics.json').open('x', encoding='utf8') as f: json.dump(result, f, indent=2)
    print(json.dumps(result['per_class'], indent=2))


if __name__ == '__main__': main()
