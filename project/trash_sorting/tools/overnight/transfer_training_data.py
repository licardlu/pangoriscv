"""Export/import exact paused-run photos and labels without duplicate JPEGs.

Uses Python standard library only. No training, label inference or final-test
access. Import rewrites paths and recreates effective replay hardlinks.
"""
import argparse
from collections import Counter
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import zipfile

MANIFEST_SHA = '86ea104719d0694bb52c1ab5b4576b7db3f4ef216fffc214755802fec4c38cba'
NAMES = ['kitchen', 'recyclable', 'hazardous', 'other', 'hand']
META = 'project/trash_sorting/training/handoff_metadata/paused_background_20261120'
EVIDENCE = 'evidence/records/optimization/allnetwork_background_20epoch_20261120_001'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(4*1024*1024), b''):
            value.update(chunk)
    return value.hexdigest()


def json_bytes(value):
    return json.dumps(value, ensure_ascii=False, indent=2).encode('utf8')


def save(path, value):
    path.write_bytes(json_bytes(value)+b'\n')


def export_pack(a):
    root = a.repo.resolve()
    original = (root/META/'manifest.original.json.gz').read_bytes()
    assert digest(gzip.decompress(original)) == MANIFEST_SHA
    rows = json.loads(gzip.decompress(original))
    assert Counter(r['split'] for r in rows) == {'train': 19260, 'val': 1929}
    unique, records, members = {}, [], {}
    # Every label is taken from the path actually consumed by the loader.
    # Some manifest source-label paths predate remapping to native five classes.
    for row in rows:
        image = Path(row['prepared_image'])
        label = image.parent.parent.parent/'labels'/row['split']/(image.stem+'.txt')
        assert image.is_file() and label.is_file(), (str(image), str(label))
        label_data = label.read_bytes()
        assert digest(label_data) == row['label_sha256'], str(label)
        image_id = row['image_sha256']
        if image_id not in unique:
            assert file_sha(image) == image_id, str(image)
            unique[image_id] = image
            if len(unique) % 500 == 0:
                print('CHECKED_SOURCE_PHOTOS', len(unique), 11278, flush=True)
        relative = f"{row['split']}/{image.name}"
        label_member = f"labels/{row['split']}/{image.stem}.txt"
        assert label_member not in members
        members[label_member] = label_data
        records.append(dict(image_sha256=image_id, relative_image=relative,
                            label_member=label_member, label_sha256=digest(label_data)))
    assert len(unique) == 11278
    train = {r['image_sha256'] for r in rows if r['split']=='train'}
    val = {r['image_sha256'] for r in rows if r['split']=='val'}
    assert len(train)==9349 and len(val)==1929 and not train & val
    assert not a.archive.exists(), 'Refuse to overwrite existing package'
    a.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(a.archive, 'x', compression=zipfile.ZIP_STORED, allowZip64=True) as pack:
        for i, (image_id, path) in enumerate(unique.items(), 1):
            pack.write(path, 'photos/'+image_id+path.suffix.lower())
            if i % 500 == 0:
                print('EXPORT_PHOTOS', i, len(unique), flush=True)
        for member, data in members.items():
            pack.writestr(member, data)
        index = dict(schema='paused-training-data-v1', original_manifest_sha256=MANIFEST_SHA,
                     photos={key:'photos/'+key+path.suffix.lower() for key,path in unique.items()},
                     rows=records, unique_train=9349, unique_val=1929,
                     train_draws=19260, val_draws=1929,
                     note='9349 train files include derived views. Replay aliases are not new photos.')
        pack.writestr('index.json', json_bytes(index))
        pack.writestr('manifest.original.json.gz', original)
        pack.writestr('calibration.original.json', (root/EVIDENCE/'calibration_reference.json').read_bytes())
        pack.write(Path(__file__), 'transfer_training_data.py')
        pack.writestr('README.txt', ('This package contains the exact11278 unique train/val images and21189 labels.\n'
            'No final-test images. Use transfer_training_data.py import --archive PACKAGE.zip --out NEW_FOLDER.\n'
            'Import validates SHA256, restores19260 train replay paths/1929 val paths, and rewrites data.yaml.\n'
            'Raw image redistribution rights follow original sources; transfer privately for project continuation.\n').encode('utf8'))
    checksum = file_sha(a.archive)
    a.archive.with_suffix(a.archive.suffix+'.sha256').write_text(checksum+'  '+a.archive.name+'\n', encoding='utf8')
    save(a.archive.with_suffix(a.archive.suffix+'.json'), dict(status='EXPORTED_EXACT_DATA_PACKAGE',
         archive=str(a.archive.resolve()), sha256=checksum, bytes=a.archive.stat().st_size,
         unique_train=9349, unique_val=1929, train_draws=19260, val_draws=1929,
         original_manifest_sha256=MANIFEST_SHA, final_test_included=False))
    print('EXPORTED', checksum, a.archive.stat().st_size, flush=True)


def read_index(pack):
    assert len(pack.namelist()) == len(set(pack.namelist())), 'Duplicate zip members'
    index = json.loads(pack.read('index.json'))
    original = pack.read('manifest.original.json.gz')
    assert index['schema'] == 'paused-training-data-v1'
    assert index['original_manifest_sha256'] == digest(gzip.decompress(original)) == MANIFEST_SHA
    rows = json.loads(gzip.decompress(original))
    assert len(rows) == len(index['rows']) == 21189
    for row, reference in zip(rows, index['rows']):
        assert row['image_sha256'] == reference['image_sha256']
        path = reference['relative_image']
        assert path.startswith(row['split']+'/') and len(Path(path).parts)==2
        assert '..' not in Path(path).parts and not Path(path).is_absolute()
        assert reference['label_member'] == 'labels/'+str(Path(path).with_suffix('.txt')).replace('\\','/')
        assert reference['label_sha256'] == row['label_sha256']
    for image_id, member in index['photos'].items():
        assert len(image_id)==64 and all(c in '0123456789abcdef' for c in image_id)
        assert member.startswith('photos/'+image_id+'.') and len(Path(member).parts)==2
    assert set(index['photos']) == {r['image_sha256'] for r in rows}
    return index, rows


def check_member(pack, member, expected, destination=None):
    value = hashlib.sha256()
    output = destination.open('xb') if destination else None
    try:
        with pack.open(member) as stream:
            for chunk in iter(lambda: stream.read(4*1024*1024), b''):
                value.update(chunk)
                if output:
                    output.write(chunk)
    finally:
        if output:
            output.close()
    assert value.hexdigest()==expected, member


def verify_or_import(a):
    importing = a.command == 'import'
    if importing:
        assert not a.out.exists(), 'Choose a fresh output directory; never overwrite existing data'
        a.out.mkdir(parents=True)
        out = a.out.resolve()
        blobs = out/'photo_store'
        blobs.mkdir()
    if a.sha256:
        assert file_sha(a.archive)==a.sha256.lower(), 'Whole package SHA256 mismatch'
    with zipfile.ZipFile(a.archive) as pack:
        index, rows = read_index(pack)
        for i, (image_id, member) in enumerate(index['photos'].items(), 1):
            check_member(pack, member, image_id, blobs/Path(member).name if importing else None)
            if i % 500 == 0:
                print('VERIFIED_PHOTOS', i, len(index['photos']), flush=True)
        paths = {'train': [], 'val': []}
        by_identity = {}
        copied_aliases = 0
        for row, ref in zip(rows, index['rows']):
            label_data = pack.read(ref['label_member'])
            assert digest(label_data)==ref['label_sha256']
            if importing:
                target = out/'images'/ref['relative_image']
                label = out/ref['label_member']
                target.parent.mkdir(parents=True, exist_ok=True)
                label.parent.mkdir(parents=True, exist_ok=True)
                source = blobs/Path(index['photos'][ref['image_sha256']]).name
                try:
                    os.link(source, target)
                except OSError:
                    shutil.copyfile(source, target)
                    copied_aliases += 1
                label.write_bytes(label_data)
                row['original_transfer_prepared_image'] = row['prepared_image']
                row['original_transfer_label'] = row.get('label')
                row.update(prepared_image=target.as_posix(), label=label.as_posix(), stem=target.stem)
                paths[row['split']].append(target.as_posix())
                if row['split']=='train':
                    by_identity.setdefault(row['image_sha256'], (target.as_posix(), row['label_sha256']))
        if importing:
            for split in paths:
                (out/(split+'.txt')).write_text('\n'.join(paths[split])+'\n', encoding='utf8')
            (out/'data.yaml').write_text('path: '+json.dumps(out.as_posix())+'\ntrain: train.txt\nval: val.txt\nnc: 5\nnames: '+json.dumps(NAMES)+'\n', encoding='utf8')
            save(out/'manifest.json', rows)
            (out/'manifest.original.json.gz').write_bytes(pack.read('manifest.original.json.gz'))
            calibration = json.loads(pack.read('calibration.original.json'))
            for item in calibration['calibration_images']:
                path, label_sha = by_identity[item['sha256']]
                assert label_sha == item['label_sha256']
                item['original_transfer_path'] = item['path']
                item['path'] = path
            assert len(calibration['calibration_images'])==160
            save(out/'calibration_reference.json', calibration)
            save(out/'transfer_result.json', dict(status='PASS_IMPORTED_HASH_VERIFIED',
                 unique_train=9349, unique_val=1929, train_draws=len(paths['train']), val_draws=len(paths['val']),
                 copied_aliases_instead_of_hardlinks=copied_aliases, calibration_images=160,
                 original_manifest_sha256=MANIFEST_SHA, rewritten_manifest_sha256=file_sha(out/'manifest.json'),
                 note='Paths changed intentionally. Original plan manifest/calibration hashes must be rebased with provenance; do not bypass checks.',
                 final_test_included=False, training_started=False))
    print('PASS_IMPORTED' if importing else 'PASS_PACKAGE_VERIFIED', '11278 photos,21189 labels', flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    export = sub.add_parser('export')
    export.add_argument('--repo', type=Path, required=True)
    export.add_argument('--archive', type=Path, required=True)
    for command in ['verify', 'import']:
        parser = sub.add_parser(command)
        parser.add_argument('--archive', type=Path, required=True)
        parser.add_argument('--sha256')
        if command=='import':
            parser.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    export_pack(args) if args.command=='export' else verify_or_import(args)


if __name__ == '__main__':
    main()
