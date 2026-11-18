"""Record explicit manual boxes in the saved source review sheet coordinates."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from collect_public_expansion import sheets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decisions', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path('build/mostafa_waste_review_20261118_001')
    decisions = json.loads(args.decisions.read_text(encoding='utf8'))
    rows, ledger = [], {}
    for category, selected in decisions.items():
        source = json.loads((root/category/'inventory.json').read_text(encoding='utf8'))
        lookup = {r['id']: (i, r) for i, r in enumerate(source)}
        for stem, rectangles in selected.items():
            key = 'mostafa_waste_'+stem
            index, row = lookup[key]
            sheet = root/category/('unreviewed_%02d.jpg' % (index//24+1))
            im = Image.open(row['path'])
            assert hashlib.sha256(Path(row['path']).read_bytes()).hexdigest() == row['image_sha256']
            im.thumbnail((350, 270))
            ox = index%4*360+(360-im.width)//2
            oy = index%24//4*320
            boxes, annotations = [], []
            for c, x1, y1, x2, y2 in rectangles:
                assert c in range(5) and ox-1 <= x1 < x2 <= ox+im.width+1 and oy-1 <= y1 < y2 <= oy+im.height+1, (key, (ox, oy, im.size), rectangles)
                a, b = max(0, (x1-ox)/im.width), max(0, (y1-oy)/im.height)
                d, e = min(1, (x2-ox)/im.width), min(1, (y2-oy)/im.height)
                boxes.append([c, (a+d)/2, (b+e)/2, d-a, e-b])
                annotations.append(dict(category_id=c, bbox=[a*row['width'], b*row['height'], (d-a)*row['width'], (e-b)*row['height']]))
            assert boxes
            rows.append(dict(row, boxes=boxes, annotations=annotations,
                category_names={str(i): n for i,n in enumerate(['kitchen','recyclable','hazardous','other','hand'])},
                status='MANUALLY_OUTLINED_PENDING_FINAL_OVERLAY_REVIEW'))
            ledger[key] = dict(source_sha256=row['image_sha256'], display_rectangles=rectangles,
                source_sheet=str(sheet), source_sheet_sha256=hashlib.sha256(sheet.read_bytes()).hexdigest(),
                coordinate_space='saved_1440x1920_source_review_sheet', reviewer='assistant_visual')
    args.out.mkdir(exist_ok=False)
    (args.out/'inventory.json').write_text(json.dumps(rows, indent=2), encoding='utf8')
    (args.out/'ledger.json').write_text(json.dumps(ledger, indent=2), encoding='utf8')
    sheets(rows, args.out, 'overlay')
    print(dict(manually_annotated_images=len(rows), boxes=sum(len(r['boxes']) for r in rows), training_admitted=0), flush=True)


if __name__ == '__main__':
    main()
