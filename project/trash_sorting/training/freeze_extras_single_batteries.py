"""Save the 38 visually checked single-battery boxes for a future data experiment."""
import hashlib
import json
import os
from pathlib import Path


def read(path):return json.loads(Path(path).read_text(encoding='utf8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,v):Path(path).write_text(json.dumps(v,indent=2),encoding='utf8')


def main():
    root=Path('build/extras_battery_candidates_20261118_001').resolve()
    proposals=read(root/'single_battery_box_proposals.json');assert len(proposals)==38
    lookup={r['id']:r for r in read(root/'inventory.json')}
    out=root/'reviewed_dataset_001';out.mkdir(exist_ok=False)
    images=out/'images/train';labels=out/'labels/train';images.mkdir(parents=True);labels.mkdir(parents=True)
    additions=[];ledger={}
    for proposal in proposals:
        r=lookup[proposal['id']]
        assert r['admission']=='REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW' and sha(r['path'])==r['image_sha256']
        x,y,w,h=proposal['annotations'][0]['bbox']
        if r['id']=='battery182':x,y,w,h=27,34,199,106
        image=images/('extras_'+r['id']+Path(r['path']).suffix);os.link(r['path'],image)
        boxes=[[2,(x+w/2)/r['width'],(y+h/2)/r['height'],w/r['width'],h/r['height']]]
        assert x>=0 and y>=0 and x+w<=r['width'] and y+h<=r['height']
        label=labels/(image.stem+'.txt');label.write_text('2 '+' '.join('%.8f'%v for v in boxes[0][1:])+'\n',encoding='ascii')
        ledger[r['id']]=dict(status='VISUALLY_REVIEWED_COMPLETE_SINGLE_BATTERY_BOX',reviewer='assistant_visual',
            source_sha256=r['image_sha256'],proposal=[*proposal['annotations'][0]['bbox']],final_xywh=[x,y,w,h],
            reason='One complete visible battery, no hand or other unlabelled object; foreground proposal overlay individually inspected.'+
                (' Manually tightened shadow-heavy foreground box.' if r['id']=='battery182' else ''))
        additions.append(dict(source='extras_reviewed_single_battery',origin='extras_manual_20261118',split='train',
            stem=image.stem,prepared_image=str(image),image_sha256=sha(image),width=r['width'],height=r['height'],
            boxes=boxes,label=str(label),label_sha256=sha(label),source_file=r['source_file'],
            source_url='https://www.kaggle.com/datasets/shettysharanyaa/extras',
            group='extras_all_batteries_train_only',capture_group='extras_all_batteries_train_only',
            annotation_status=ledger[r['id']]['status'],phash=r['phash'],sha256_pixels=r['sha256_pixels'],
            new_source_image=True,physical_object_identity_unknown=True))
    basepath=Path('build/battery_orientation_20261118_001/dataset_001/manifest.json');base=read(basepath)
    assert not {r['image_sha256'] for r in additions}.intersection(r['image_sha256'] for r in base)
    rows=base+[dict(r,extras_draw=n) for n in range(4) for r in additions]
    assert [r for r in rows if r['split']!='train']==[r for r in base if r['split']!='train']
    save(out/'manifest.json',rows);save(out/'additions.json',additions);save(root/'single_battery_review_ledger.json',ledger)
    for split in ('train','val'):
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in rows if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    save(out/'result.json',dict(status='REVIEWED_FUTURE_DATA_ONLY_NOT_TRAINED',base_manifest_sha256=sha(basepath),
        source='shettysharanyaa/extras v1',new_source_files=38,new_label_boxes=38,
        derived_images_added=0,draws_per_added_file=4,source_split='Entire new source kept train only; no fabricated independent validation.',
        previous_candidate_exclusions_included_in_identity_audit=True,
        unique_train_files=len({r['image_sha256'] for r in rows if r['split']=='train'}),draws_per_epoch=sum(r['split']=='train' for r in rows),
        val_test_metadata_unchanged=True,final_test_files_read=False,
        source_metadata_sha256=sha('build/noon_continuation_20261118_001/research/shettysharanyaa_extras_metadata.json'),
        archive_sha256=read(root/'acquisition.json')['archive_sha256'],
        limitations=['Mostly product images/renderings, no new hand-held or camera-station photographs.',
            'Distinct file hashes do not prove distinct physical objects; upstream photographer provenance incomplete.',
            'Must evaluate without replacing current frozen experiments or claiming an accuracy improvement.']))
    print(read(out/'result.json'),flush=True)


if __name__=='__main__':main()
