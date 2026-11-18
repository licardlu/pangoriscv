"""Validate an ordered, frozen training-only calibration replay."""
import hashlib
import json
from pathlib import Path


def frozen_calibration(reference, metadata, classes):
    if reference.get('classes')!=classes:
        raise ValueError('Frozen calibration class schema differs')
    records=reference.get('calibration_images')
    if not isinstance(records,list) or not records:
        raise ValueError('Frozen calibration list is empty or missing')
    paths=[];seen=set()
    for record in records:
        path=str(Path(record['path']).resolve())
        actual=metadata.get(path)
        if actual is None:
            raise ValueError('Frozen calibration image is absent from current train: '+path)
        for field in ('sha256','source','primary_calibration_class'):
            if record.get(field)!=actual[field]:
                raise ValueError('Frozen calibration identity differs: '+field+' '+path)
        if record.get('label_sha256',actual['label_sha256'])!=actual['label_sha256']:
            raise ValueError('Frozen calibration label identity differs: '+path)
        if actual['sha256'] in seen:
            raise ValueError('Frozen calibration repeats an image')
        seen.add(actual['sha256']);paths.append(Path(path))
    if {metadata[str(p)]['primary_calibration_class'] for p in paths}!=set(range(len(classes))):
        raise ValueError('Frozen calibration omits a primary class')
    return paths


def ordered_identity(paths,metadata):
    rows=[{k:metadata[str(p)][k] for k in ('path','sha256','label_sha256','primary_calibration_class')} for p in paths]
    return hashlib.sha256(json.dumps(rows,sort_keys=True,separators=(',',':')).encode()).hexdigest()
