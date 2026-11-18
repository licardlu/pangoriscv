"""Materialize reviewed manifest draws without treating aliases as new images."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
from PIL import Image


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    rows=json.loads(a.manifest.read_text(encoding='utf8'))
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    (out/'images/train').mkdir(parents=True);(out/'labels/train').mkdir(parents=True)
    counts=Counter();unique={};draws=[]
    for row in rows:
        if row['split']!='train':
            continue
        digest=row['image_sha256'];image=Path(row['prepared_image'])
        if digest not in unique:
            assert sha(image)==digest
            # YOLO repairs malformed JPEGs in place. Reject them before creating
            # hardlinks, otherwise that repair also changes the source identity.
            with Image.open(image) as source_image:
                if source_image.format == 'JPEG':
                    with image.open('rb') as source_file:
                        source_file.seek(-2,2)
                        if source_file.read()!=b'\xff\xd9':
                            raise ValueError('JPEG lacks EOI; repair to a separate file and freeze its actual SHA before training: '+str(image))
                source_image.verify()
            unique[digest]=row
        else:
            assert unique[digest]['boxes']==row['boxes']
        counts[digest]+=1
        stem='draw_'+digest+'_'+str(counts[digest])
        dest=out/'images/train'/(stem+image.suffix)
        try:os.link(image,dest)
        except OSError:shutil.copyfile(image,dest)
        label=out/'labels/train'/(stem+'.txt')
        for c,x,y,w,h in row['boxes']:
            assert c in range(5) and w>0 and h>0
            assert min(x-w/2,y-h/2)>=-1e-5 and max(x+w/2,y+h/2)<=1+1e-5
        label.write_text(''.join(str(int(b[0]))+' '+' '.join('%.8f'%v for v in b[1:])+'\n' for b in row['boxes']),encoding='ascii')
        draws.append(dict(row,prepared_image=str(dest),label=str(label),label_sha256=sha(label),
                          stem=stem,replay_of=str(image),replay_draw=counts[digest]))
    other=[r for r in rows if r['split']!='train']
    manifest=draws+other
    assert len(draws)==len({r['prepared_image'] for r in draws})
    assert [r for r in manifest if r['split']!='train']==other
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    for split in ('train','val'):
        (out/(split+'.txt')).write_text(''.join(r['prepared_image']+'\n' for r in manifest if r['split']==split),encoding='utf8')
    (out/'data.yaml').write_text('path: '+out.as_posix()+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: [kitchen, recyclable, hazardous, other, hand]\n',encoding='utf8')
    report=dict(status='FROZEN_REVIEWED_DRAWS',source_manifest_sha256=sha(a.manifest),
                training_draws=len(draws),unique_file_identities=len(unique),
                alias_paths_are_not_new_photographs=True,val_test_metadata_unchanged=True,
                final_test_image_or_label_files_read=False,
                source_draws=dict(Counter(r['source'] for r in draws)),
                manifest_sha256=sha(out/'manifest.json'))
    (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report),flush=True)


if __name__=='__main__':main()
