"""Freeze the candidate using validation fitness, before running held-out tests."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--stage', action='append', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--evidence', type=Path, required=True)
    a = ap.parse_args()
    if a.out.exists() or (a.evidence/'selection.json').exists():
        raise SystemExit('Candidate/selection already exists; use a fresh name')
    choices = []
    for stage in a.stage:
        provenance = json.loads((stage/'provenance.json').read_text())
        if provenance['status'] != 'completed' or provenance.get('evaluate'):
            raise ValueError('Not a completed training stage: '+str(stage))
        progress = json.loads((stage/'progress.json').read_text())
        ckpt = stage/'weights/best.pt'
        choices.append({'stage':str(stage.resolve()), 'checkpoint':str(ckpt.resolve()),
                        'validation_fitness':progress['best_fitness'],
                        'checkpoint_sha256':hashlib.sha256(ckpt.read_bytes()).hexdigest(),
                        'epochs_completed':progress['epoch'], 'epochs_requested':provenance['epochs'],
                        'input_weights_sha256':provenance['weights_sha256']})
    if len({json.loads((s/'provenance.json').read_text())['data_sha256'] for s in a.stage}) != 1:
        raise ValueError('Different validation datasets across stages')
    chosen = max(choices, key=lambda r:r['validation_fitness'])
    a.out.mkdir(parents=True)
    shutil.copyfile(chosen['checkpoint'], a.out/'four_bins_yolov5n_320.pt')
    selection = {'selected_unix':time.time(), 'criterion':'upstream validation fitness = .1*mAP50 + .9*mAP50:95',
                 'choices':choices, 'selected':chosen, 'candidate':str((a.out/'four_bins_yolov5n_320.pt').resolve()),
                 'classes':['kitchen','recyclable','hazardous','other'],
                 'bin_colors':['green','blue','red','gray'], 'business_bin_codes':[1,4,2,3],
                 'input_size':[320,320], 'raw_head_channels':27,
                 'deployment_status':'floating-point candidate; INT8 packing, firmware/OSD mapping, FPGA verification pending',
                 'test_used_for_selection':False}
    (a.out/'manifest.json').write_text(json.dumps(selection,indent=2),encoding='utf-8')
    (a.out/'README.md').write_text('# Four-bin YOLOv5n 320 candidate\n\n'
        'Classes: 0 kitchen (green), 1 recyclable (blue), 2 hazardous (red), 3 other (gray).\n'
        'Existing application bin codes/keys: model class 0->1, 1->4, 2->2, 3->3. Do not use class+1.\n'
        'Paper and cardboard both map to recyclable. This model predicts bin categories, not individual materials.\n\n'
        'Floating point checkpoint for pinned YOLOv5 v7.0. Not a replacement FPGA weight blob.\n'
        'Existing firmware assumes six raw classes / 33 head channels; this candidate has four / 27.\n'
        'See docs/verification/trash-retraining-20261111.md for sources, tests and limits.\n',encoding='utf-8')
    a.evidence.mkdir(parents=True,exist_ok=True)
    (a.evidence/'selection.json').write_text(json.dumps(selection,indent=2),encoding='utf-8')
    print(json.dumps(selection,indent=2),flush=True)


if __name__=='__main__':
    main()
