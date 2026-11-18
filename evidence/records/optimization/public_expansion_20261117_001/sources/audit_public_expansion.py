"""Reject historical and internal duplicates using metadata; never open test photos."""
import argparse, collections, hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.fft import dctn

def features(path):
    with Image.open(path) as im:
        rgb=im.convert('RGB');w,h=rgb.size
        pixel=hashlib.sha256(np.array(rgb).tobytes()+str((w,h)).encode()).hexdigest()
        freq=dctn(np.array(rgb.resize((32,32)).convert('L'),dtype=float),norm='ortho')[:8,:8].flatten()
        ph=int(''.join('1' if v>np.median(freq[1:]) else '0' for v in freq),2)
    return dict(sha256_pixels=pixel,phash=ph)

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);a=p.parse_args();root=a.root.resolve()
    repo=Path(__file__).resolve().parents[3]
    known=[]
    for name in ['overnight_20261116/dataset_stage4','continuation_023_dataset_001']:
        known+=json.loads((repo/'build'/name/'manifest.json').read_text(encoding='utf8'))
    # Existing stored features include final test. Test files are never opened.
    cache_path=root/'historical_feature_cache.json'
    cache=json.loads(cache_path.read_text()) if cache_path.exists() else {}
    for r in known:
        if 'phash' not in r and r['split']!='test':
            path=Path(r['prepared_image']);key=str(path)
            if key not in cache:cache[key]=features(path)
            r={**r,**cache[key]}
        if 'phash' in r:cache.setdefault('old_'+str(r['phash']),r)
    cache_path.write_text(json.dumps(cache),encoding='utf8')
    old=[r for k,r in cache.items() if k.startswith('old_')]
    phashes=[int(r['phash']) for r in old]
    pixels={r['sha256_pixels'] for r in old if r.get('sha256_pixels')}
    files={r.get('image_sha256',r.get('sha256')) for r in known}
    files.update(r.get('original_sha256') for r in known if r.get('original_sha256'))
    held_groups={str(r.get('capture_group',r.get('group'))) for r in known if r['split'] in ('val','test')}
    rows=[]
    for f in ['taco_inventory.json','battery_inventory.json','hand_inventory.json']:
        if not (root/f).exists():continue
        rows += [r for r in json.loads((root/f).read_text(encoding='utf8')) if 'error' not in r]
    output=[];accepted=[]
    for row in rows:
        row={**row,**features(row['path'])}
        distances=[bin(row['phash']^v).count('1') for v in phashes]
        nearest=min(distances);index=distances.index(nearest)
        duplicate=next((r['id'] for r in accepted if r['sha256_pixels']==row['sha256_pixels'] or bin(r['phash']^row['phash']).count('1')<=6),None)
        held_subject=row.get('source')=='hagrid' and 'hagrid_subject_'+str(row.get('subject_id')) in held_groups
        reason='held_subject' if held_subject else 'historical_exact' if row['sha256'] in files or row['sha256_pixels'] in pixels else 'historical_near' if nearest<=6 else 'candidate_duplicate' if duplicate else None
        row.update(dedup_status='REJECT' if reason else 'NOVEL_CANDIDATE',dedup_reason=reason,
                   historical_nearest_distance=nearest,historical_nearest_stem=old[index].get('stem'),
                   historical_nearest_split=old[index]['split'],candidate_duplicate=duplicate)
        output.append(row)
        if not reason:accepted.append(row)
    (root/'dedup_inventory.json').write_text(json.dumps(output,indent=2),encoding='utf8')
    report=dict(total=len(rows),by_source={s:dict(collections.Counter(r['dedup_reason'] or 'novel' for r in output if r['source']==s)) for s in sorted({r['source'] for r in rows})},
                historical_metadata_rows=len(known),historical_unique_feature_rows=len(old),historical_non_test_features_computed=len([k for k in cache if not k.startswith('old_')]),held_out_test_images_opened=0,phash_threshold=6)
    (root/'dedup_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
if __name__=='__main__':main()
