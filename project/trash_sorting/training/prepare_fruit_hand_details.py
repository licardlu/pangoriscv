"""Prepare enlarged full frames for explicit hand/object annotation review."""
import argparse
import json
from pathlib import Path
from PIL import Image


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--indices',type=int,nargs='+',default=[22,23,28,32,98,110])
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    root=Path('build/noon_continuation_20261118_001/research/organic_001/fruit_audit_002')
    rows=json.loads((root/'review_order.json').read_text(encoding='utf8'))
    out=args.out or root/'hand_details_001';out.mkdir(exist_ok=False)
    layout={}
    for n in args.indices:
        row=rows[n-1]
        with Image.open(row['path']) as raw:
            im=raw.convert('RGB');im.thumbnail((960,960));im=im.resize((960,960))
            im.save(out/(str(n)+'.jpg'),quality=96)
            layout[n]=dict(id=row['id'],display_size=list(im.size),source_sha256=row['image_sha256'])
    (out/'layout.json').write_text(json.dumps(layout,indent=2),encoding='utf8')


if __name__=='__main__':main()
