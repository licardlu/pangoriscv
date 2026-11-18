"""Render a fixed, previously unreviewed source-train batch for manual review.

No model predictions, held-out images, or automatic training admission.
"""
import hashlib
import json
from pathlib import Path

from collect_public_expansion import sheets


def main():
    root = Path('build/noon_continuation_20261118_001/research/handheld_mirrors_001/mju_train_001/audit_002')
    read = lambda p: json.loads(p.read_text(encoding='utf8'))
    prior = {r['source_id'] for r in read(root/'review_order.json')}
    rows = [r for r in read(root/'inventory.json')
            if r['admission'] == 'PENDING_FOURBIN_HAND_FULLINSTANCE_REVIEW'
            and r['id'] not in prior]
    rows.sort(key=lambda r: hashlib.sha256(r['id'].encode()).hexdigest())
    selected = []
    for i, r in enumerate(rows[:96], 1):
        assert r['source_split'] == 'train'
        assert hashlib.sha256(Path(r['path']).read_bytes()).hexdigest() == r['image_sha256']
        selected.append(dict(r, source_id=r['id'], id=f'R{i:03}_'+r['id'], review_index=i))
    out = root/'remaining_review_001'
    out.mkdir(exist_ok=False)
    (out/'review_order.json').write_text(json.dumps(selected, indent=2), encoding='utf8')
    sheets(selected, out, 'remaining')
    result = dict(status='REVIEW_ONLY_NOT_ADMITTED', remaining_unreviewed=len(rows),
                  rendered=len(selected), source_split='train', training_admitted=0,
                  selection='Fixed SHA256(source_id) order, excluding earlier120reviewed identities',
                  test_valid_contents_read=False)
    (out/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(result, flush=True)


if __name__ == '__main__':
    main()
