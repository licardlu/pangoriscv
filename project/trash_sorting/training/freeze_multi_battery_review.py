"""Freeze 21 reviewed battery images/73 boxes as future training additions.

The final overlay was visually checked. No active dataset or experiment changes.
Distinct file identities do not establish independent cameras or physical items.
"""
import hashlib
import json
import os
from pathlib import Path


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2)+'\n', encoding='utf8')


def main():
    root = Path('build/extras_battery_candidates_20261118_001').resolve()
    inventory = {r['id']: r for r in read(root/'inventory.json')}
    source = root/'multi_review_001/annotated_001'
    ledger = read(source/'ledger.json')
    assert len(ledger) == 21 and sum(len(r['boxes']) for r in ledger.values()) == 73
    out = root/'reviewed_multi_additions_001'
    images,labels = out/'images/train',out/'labels/train'
    images.mkdir(parents=True,exist_ok=False); labels.mkdir(parents=True)
    prior = read(root/'reviewed_dataset_001/manifest.json')
    known = {r['image_sha256'] for r in prior}
    rows = []
    for key, entry in ledger.items():
        r = inventory[key]
        assert r['admission'] == 'REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW'
        assert sha(r['path']) == entry['source_sha256'] == r['image_sha256']
        assert r['image_sha256'] not in known
        image = images/('extras_multi_'+key+Path(r['path']).suffix)
        os.link(r['path'],image)
        label = labels/(image.stem+'.txt')
        for c,cx,cy,w,h in entry['boxes']:
            assert c == 2 and w > 0 and h > 0
            assert -1e-9 <= cx-w/2 < cx+w/2 <= 1+1e-9
            assert -1e-9 <= cy-h/2 < cy+h/2 <= 1+1e-9
        label.write_text(''.join(str(b[0])+' '+' '.join('%.8f'%v for v in b[1:])+'\n'
                                 for b in entry['boxes']),encoding='ascii')
        actual = [[float(x) for x in line.split()] for line in label.read_text().splitlines()]
        assert all(abs(a-b) < 1e-7 for aa,bb in zip(actual,entry['boxes']) for a,b in zip(aa,bb))
        entry.update(status='VISUALLY_REVIEWED_COMPLETE_MULTI_BATTERY_BOXES',
                     final_overlay_sha256=sha(source/(key+'.jpg')),
                     review='All visible battery bodies and attached leads boxed, no visible hand; final source-overlay checked.')
        rows.append(dict(source='extras_reviewed_multi_battery', origin='extras_manual_20261118',
            split='train', stem=image.stem, prepared_image=str(image), image_sha256=sha(image),
            width=r['width'],height=r['height'],boxes=entry['boxes'],primary_bin=2,
            label=str(label),label_sha256=sha(label),
            source_url=entry['source_url'],source_file=r['source_file'],
            group='extras_all_batteries_train_only',capture_group='extras_all_batteries_train_only',
            annotation_status=entry['status'],phash=r['phash'],sha256_pixels=r['sha256_pixels'],
            new_source_image=True,physical_object_identity_unknown=True,
            independent_camera_capture=False))
    save(out/'manifest.json',rows);save(out/'review_ledger.json',ledger)
    save(out/'result.json',dict(status='FROZEN_REVIEWED_ANNOTATIONS_NOT_YET_TRAINED',
        source_files=21,battery_boxes=73,hand_boxes=0,derived_images=0,new_camera_captures=0,
        original_inventory_sha256=sha(root/'inventory.json'),
        original_review_ledger_sha256=sha(source/'ledger.json'),
        final_ledger_sha256=sha(out/'review_ledger.json'),manifest_sha256=sha(out/'manifest.json'),
        parent_source_license='MIT per Kaggle extras v1 metadata; upstream photograph provenance incomplete.',
        current_experiments_changed=False,final_test_files_read=False,
        limitations=['Mostly product pictures and renderings, not camera-station or hand-held data.',
                    'Distinct image file hashes do not prove independent physical objects.',
                    'Entire extras source stays train only; zero new validation scenes.']))
    print(read(out/'result.json'),flush=True)


if __name__ == '__main__':
    main()
