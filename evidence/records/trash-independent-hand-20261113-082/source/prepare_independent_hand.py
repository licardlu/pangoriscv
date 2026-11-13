"""Build an audited hand-only train/val set without treating unaudited waste as negatives."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import yaml
from evaluate_crop_diagnostic import ROOT, sha, save


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    source=ROOT/'build/trash_additional_hands_20261113_052/prepared/dataset/manifest.json'
    rows=json.loads(source.read_text(encoding='utf8'));data=a.out/'dataset'
    for split in ('train','val'):
        (data/'images'/split).mkdir(parents=True);(data/'labels'/split).mkdir(parents=True)
    manifest=[];seen={}
    for r in rows:
        if r['split'] not in ('train','val') or r.get('repetition',0)!=0:
            continue
        scope=r.get('hand_annotation_status')
        if r['source'] not in ('personal_handheld','hagrid_hand_localisation','reviewed_hand_context') and scope not in ('visually reviewed absent','visible hands manually boxed and reviewed'):
            continue
        assert 'battery' not in str(r.get('group','')).lower()
        path=Path(r['prepared_image']);assert sha(path)==r['sha256']
        boxes=[[0,*b[1:]] for b in r['boxes'] if int(b[0])==4]
        if scope=='visually reviewed absent':assert not boxes
        elif not boxes:raise ValueError('Audited positive missing hands: '+str(path))
        if r['sha256'] in seen:
            prior=seen[r['sha256']]
            assert prior['split']==r['split'] and prior['boxes']==boxes
            continue
        key=path.stem;target=data/'images'/r['split']/path.name
        if target.exists():raise ValueError('Duplicate key '+key)
        try:os.link(path,target)
        except OSError:shutil.copyfile(path,target)
        (data/'labels'/r['split']/(key+'.txt')).write_text(''.join(' '.join(format(float(v),'.10g') for v in b)+'\n' for b in boxes),encoding='utf8')
        entry=dict(key=key,source=r['source'],split=r['split'],group=r['group'],boxes=boxes,sha256=r['sha256'],
                   original_sha256=r.get('original_sha256',r.get('sha256_pixels',r['sha256'])),prepared_image=str(target),
                   held_object=r.get('held_object'),annotation_scope='audited visible hands only; not a waste-negative annotation')
        manifest.append(entry);seen[r['sha256']]=entry
    train=[r for r in manifest if r['split']=='train'];val=[r for r in manifest if r['split']=='val']
    for field in ('group','sha256','original_sha256'):
        assert not {str(r[field]) for r in train}.intersection(str(r[field]) for r in val),'Train/val leak: '+field
    save(data/'manifest.json',manifest)
    (data/'data.yaml').write_text(yaml.safe_dump(dict(path=str(data),train='images/train',val='images/val',nc=1,names={0:'hand'}),sort_keys=False),encoding='utf8')
    result=dict(status='PASS_AUDITED_HAND_ONLY_DATA',source_manifest_sha256=sha(source),manifest_sha256=sha(data/'manifest.json'),
                counts=dict(Counter(r['split']+'/'+r['source'] for r in manifest)),
                positives=dict(Counter(r['split'] for r in manifest if r['boxes'])),
                negatives=dict(Counter(r['split'] for r in manifest if not r['boxes'])),
                split_group_sha_source_disjoint=True,unknown_hand_public_excluded=True,test_used=False,
                independent_model=True,script_sha256=sha(__file__))
    save(a.out/'preparation.json',result);print(json.dumps(result),flush=True)


if __name__=='__main__':main()
