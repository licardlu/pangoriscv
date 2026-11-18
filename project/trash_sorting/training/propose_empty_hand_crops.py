"""Prepare candidate background crops from whitelisted TRAIN hand-only frames.

Geometric hand exclusion is only a proposal. Every crop requires visual review;
none is automatically treated as an empty target or a new source photograph.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from audit_public_expansion import features
from collect_public_expansion import sheets


def read(p):return json.loads(Path(p).read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--full-source',action='store_true')
    p.add_argument('--out',type=Path,default=Path('build/empty_hand_background_20261118_001'))
    args=p.parse_args()
    manifest=Path('build/wastesense_review_20261118_001/dataset_001/manifest.json')
    out=args.out;out.mkdir(exist_ok=False)
    images=out/'candidates';images.mkdir()
    rows={r['image_sha256']:r for r in read(manifest) if r['split']=='train' and r['source']=='hagrid_hand_localisation'}
    if args.full_source:
        whitelist={r['original_sha256']:r for r in rows.values()}
        held={str(r.get('capture_group',r.get('group'))) for r in read(manifest) if r['split'] in ['val','test']}
        full=[]
        for source in read('build/public_expansion_20261117_001/hand_inventory.json'):
            if source['sha256'] not in whitelist:continue
            parent=whitelist[source['sha256']]
            assert parent['split']=='train' and parent['group'] not in held
            w,h=source['width'],source['height']
            full.append(dict(source='hagrid_hand_localisation',prepared_image=source['path'],
                image_sha256=source['sha256'],group=parent['group'],
                whitelist_prepared_sha256=parent['image_sha256'],
                boxes=[[4,(b['bbox'][0]+b['bbox'][2]/2)/w,(b['bbox'][1]+b['bbox'][3]/2)/h,b['bbox'][2]/w,b['bbox'][3]/h] for b in source['annotations']]))
        rows={r['image_sha256']:r for r in full}
    ordered=sorted(rows.values(),key=lambda r:hashlib.sha256(r['image_sha256'].encode()).hexdigest())
    proposals=[]
    for row in ordered:
        assert row['boxes'] and all(int(b[0])==4 for b in row['boxes'])
        image=Path(row['prepared_image']);assert sha(image)==row['image_sha256']
        with Image.open(image) as original:
            w,h=original.size
            hands=[(max(0,int((b[1]-b[3]/2)*w)-int(.06*w)),max(0,int((b[2]-b[4]/2)*h)-int(.06*h)),
                    min(w,int((b[1]+b[3]/2)*w)+int(.06*w)),min(h,int((b[2]+b[4]/2)*h)+int(.06*h))) for b in row['boxes']]
            left=min(b[0] for b in hands);top=min(b[1] for b in hands)
            right=max(b[2] for b in hands);bottom=max(b[3] for b in hands)
            options=[(0,0,left,h),(right,0,w,h),(0,0,w,top),(0,bottom,w,h)]
            options=[b for b in options if b[2]-b[0]>=140 and b[3]-b[1]>=120 and
                     .55<=(b[2]-b[0])/(b[3]-b[1])<=1.8 and
                     (b[2]-b[0])*(b[3]-b[1])>=w*h*.14]
            if not options:continue
            crop=max(options,key=lambda b:(b[2]-b[0])*(b[3]-b[1]))
            number=len(proposals)+1;key='hand_background_%03d'%number
            path=images/(key+'.jpg');original.convert('RGB').crop(crop).save(path,quality=95)
        fingerprint=features(path)
        if any(bin(fingerprint['phash']^r['phash']).count('1')<=6 for r in proposals):
            path.unlink();continue
        proposals.append(dict(id=key,path=str(path.resolve()),width=crop[2]-crop[0],height=crop[3]-crop[1],
            image_sha256=sha(path),**fingerprint,annotations=[],category_names={},
            parent_image=str(image.resolve()),parent_image_sha256=row['image_sha256'],
            parent_group=row.get('capture_group',row.get('group')),source=row['source'],
            whitelist_prepared_sha256=row.get('whitelist_prepared_sha256',row['image_sha256']),
            parent_boxes=row['boxes'],crop_xyxy=crop,known_hand_intersection=0,
            split='train',status='PROPOSAL_REQUIRES_VISUAL_EMPTY_CONFIRMATION',
            new_source_photograph=False))
        if len(proposals)==48:break
    (out/'inventory.json').write_text(json.dumps(proposals,indent=2),encoding='utf8')
    (out/'provenance.json').write_text(json.dumps(dict(manifest_sha256=sha(manifest),
        source_train_only=True,test_images_or_labels_opened=False,training_admission=0,
        note='Derived views only. Zero intersection with known hand boxes does not establish absence of missed hands or waste; inspect each crop.'),indent=2),encoding='utf8')
    sheets(proposals,out,'review')
    print('BACKGROUND_CROP_PROPOSALS',len(proposals),flush=True)


if __name__=='__main__':main()
