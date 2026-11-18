"""Freeze validation-only fixtures for arithmetic checks, not accuracy tuning."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageOps

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--manifest',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--all-validation',action='store_true',help='Include all original val images after the bucket-coverage fixtures')
    ap.add_argument('--allow-missing-bins',action='store_true',help='Validation subset may lack a waste class; record the subset without inventing coverage')
    a=ap.parse_args()
    rows=json.loads(a.manifest.read_text(encoding='utf8'))
    val=sorted((r for r in rows if r['split']=='val'),key=lambda r:Path(r['prepared_image']).stem)
    chosen=[]
    for category,case_id in zip(range(4),(1,23,38,76)):
        pool=[r for r in val if str(r['source']).startswith('personal') and
              any(int(b[0])==category for b in r['boxes'])]
        if not pool:pool=[r for r in val if any(int(b[0])==category for b in r['boxes'])]
        if not pool:
            if a.allow_missing_bins:continue
            raise ValueError(f'No validation example for {category}')
        chosen.append((case_id,pool[0]))
    if chosen and not any(case_id==1 for case_id,_ in chosen):chosen[0]=(1,chosen[0][1])
    hand=[r for r in val if r['boxes'] and all(int(b[0])==4 for b in r['boxes'])]
    if hand:chosen.append((90,hand[0]))
    empty=[r for r in val if not r['boxes']]
    if empty:chosen.append((91,empty[0]))
    selected_paths={r['prepared_image'] for _,r in chosen}
    public=[r for r in val if not str(r['source']).startswith('personal') and r['prepared_image'] not in selected_paths]
    if public:chosen.append((92,public[0]))
    if a.all_validation:
        existing={r['prepared_image'] for _,r in chosen}
        chosen.extend((case_id,r) for case_id,r in enumerate((r for r in val if r['prepared_image'] not in existing),100))
    assert len(chosen)==len({r['prepared_image'] for _,r in chosen})
    a.out.mkdir(parents=True,exist_ok=False)
    inventory=[];truth={}
    for case_id,row in chosen:
        image=Path(row['prepared_image'])
        digest=hashlib.sha256(image.read_bytes()).hexdigest()
        assert digest==row['image_sha256']
        with Image.open(image) as im:width,height=ImageOps.exif_transpose(im).size
        inventory.append(dict(id=case_id,path=str(image.resolve()),file=image.name,
                              sha256=digest,display_size=[width,height]))
        truth[str(case_id)]={k:row.get(k) for k in
            ('stem','split','source','group','group_id','boxes','width','height')}
    for name,value in (('inventory.json',inventory),('truth.json',truth)):
        (a.out/name).write_text(json.dumps(value,indent=2,ensure_ascii=False),encoding='utf8')
    (a.out/'provenance.json').write_text(json.dumps(dict(
        scope='validation-only numerical compatibility, not accuracy benchmark',
        selection='lexicographic first personal val example per bin, hand-only, empty if available, public',
        manifest_sha256=hashlib.sha256(a.manifest.read_bytes()).hexdigest(),
        cases=len(inventory)),indent=2),encoding='utf8')
    print(f'NUMERIC_FIXTURES_FROZEN {len(inventory)}')

if __name__=='__main__':main()
