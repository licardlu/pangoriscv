"""Record explicit complete-object decisions after inspecting all 96 proposals."""
import hashlib
import json
from pathlib import Path
from collect_public_expansion import sheets


EXCLUDE = {
    13: 'Printed plate material uncertain; paper and foam policies differ.',
    15: 'Round bowl material uncertain from this view.',
    19: 'Second object severely truncated at lower-left image boundary.',
    22: 'Printed plate material uncertain.',
    23: 'Visible food residue cannot be completely labelled from contact sheet.',
    30: 'Round plate material uncertain.',
    34: 'Printed tray material uncertain.',
    41: 'Round plate material uncertain.',
    44: 'Additional printed plate material uncertain.',
    45: 'Two source extents appear to divide one edge-on open container; defer ambiguous extent.',
    48: 'Additional printed plate material uncertain.',
    51: 'Fish-shaped plate material uncertain.',
    59: 'Large unlabelled cardboard packaging at top of image.',
    60: 'Unlabelled syringe-like object below tray; policy uncertain.',
    64: 'Additional round plate material uncertain.',
    66: 'Additional plate and truncated foreground object are incompletely labelled.',
    69: 'Additional round plate material uncertain.',
    74: 'Additional round plate material uncertain.',
    78: 'Round plate material uncertain.',
    81: 'Cup/bowl material uncertain.',
    85: 'Printed tray and second unlabelled round object; material uncertain.',
    87: 'Open container severely truncated at left image edge.',
    89: 'Printed tray and second unlabelled round object; material uncertain.',
    90: 'Printed tray material uncertain.',
    93: 'Bowl material uncertain.',
    94: 'Bowl material uncertain.',
}


def main():
    root = Path('build/noon_continuation_20261118_001/research/organic_001/foam_review_001')
    out = root/'object_review_001'
    out.mkdir(exist_ok=False)
    rows = json.loads((root/'review_order.json').read_text(encoding='utf8'))
    assert len(rows) == 96
    ledger = {}; candidates = []
    for row in rows:
        n = row['review_index']; key = row['source_id']
        item = dict(review_index=n, reviewer='assistant_visual', source_sha256=row['image_sha256'])
        ledger[key] = item
        assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest() == row['image_sha256']
        if n in EXCLUDE:
            item.update(status='EXCLUDED_NOT_ADMITTED', reason=EXCLUDE[n])
            continue
        item.update(status='PENDING_FINAL_OVERLAY_REVIEW', boxes=row['proposed_boxes'],
            method='Visually checked complete foam tray/box in full 416px source view; union of near-identical source polygon and bbox for each single instance. No visible hand; no ambiguous secondary waste accepted.')
        candidates.append(row)
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    (out/'candidates.json').write_text(json.dumps(candidates,indent=2),encoding='utf8')
    sheets(candidates,out,'overlay')
    print(dict(selected=len(candidates),excluded=len(EXCLUDE),admitted=0),flush=True)


if __name__ == '__main__':
    main()
