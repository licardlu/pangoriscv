"""Apply a declared development gate to a completed, paired C-selector replay.

Read saved decisions and validation metadata only; no test files, inference,
weight fitting, threshold search, or hardware access.
"""
import argparse
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('replay','manifest','out'):p.add_argument('--'+key,type=Path,required=True)
    for key in ('baseline','control','mined'):p.add_argument('--'+key,required=True)
    a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
    report=json.loads((a.replay/'result.json').read_text(encoding='utf8'))
    assert report['status']=='PASS' and report['split']=='val' and not report['held_out_test_used']
    assert report['manifest_sha256']==sha(a.manifest)
    truth={Path(r['prepared_image']).stem:r for r in json.loads(a.manifest.read_text(encoding='utf8')) if r['split']=='val'}
    decisions=json.loads((a.replay/'decisions.json').read_text(encoding='utf8'))
    positive={k for k,r in truth.items() if any(int(b[0])<4 for b in r['boxes'])}
    background=set(truth)-positive
    battery={k for k,r in truth.items() if r['source']=='personal_\u7535\u6c60'}
    glass={k for k,r in truth.items() if r['source']=='sumn2u' and '/glass/' in str(r.get('image','')).replace('\\','/').lower()}
    assert len(truth)==1929 and len(positive)==1793 and len(background)==136 and len(battery)==60 and len(glass)==242
    scores={}
    for name in (a.baseline,a.control,a.mined):
        rows=decisions[name];assert set(rows)==set(truth)
        scores[name]=dict(correct_positive=sum(rows[k]['correct_class_and_iou050'] for k in positive),
                          false_background=sum(rows[k]['selected'] is not None for k in background),
                          correct_personal_battery=sum(rows[k]['correct_class_and_iou050'] for k in battery),
                          correct_public_glass=sum(rows[k]['correct_class_and_iou050'] for k in glass),
                          weights_sha256=report['reports'][name]['weights_sha256'])
    high=('correct_positive','correct_personal_battery','correct_public_glass')
    def dominates(left,right):
        good=all(left[k]>=right[k] for k in high) and left['false_background']<=right['false_background']
        strict=any(left[k]>right[k] for k in high) or left['false_background']<right['false_background']
        return good and strict
    mined=scores[a.mined]
    pass_gate=dominates(mined,scores[a.baseline]) and dominates(mined,scores[a.control])
    paired={}
    for name in (a.baseline,a.control):
        old,new=decisions[name],decisions[a.mined]
        paired[name]=dict(positive_gains=[k for k in positive if new[k]['correct_class_and_iou050'] and not old[k]['correct_class_and_iou050']],
                         positive_losses=[k for k in positive if old[k]['correct_class_and_iou050'] and not new[k]['correct_class_and_iou050']],
                         background_removed=[k for k in background if old[k]['selected'] and not new[k]['selected']],
                         background_added=[k for k in background if new[k]['selected'] and not old[k]['selected']])
        for key in paired[name]:paired[name][key].sort()
    result=dict(status='PAIRED_DEVELOPMENT_FLOAT_COMPARISON_COMPLETED',
                scope='Repeated development val float/C replay; not independent test, Q15, FPGA, or camera accuracy',
                denominators=dict(positive=len(positive),background=len(background),personal_battery=len(battery),public_glass=len(glass)),
                metrics=scores,paired=paired,proceed_to_fixed_calibration=pass_gate,
                decision='ALLOW_FIXED_CALIBRATION_AND_Q15_GATE_ONLY' if pass_gate else 'REJECT_EXPERIMENT_KEEP_ORIGINAL_STAGE4',
                criterion='Mined must be no worse in all four counts and strictly better in at least one, versus BOTH original stage4 and matched control',
                manifest_sha256=sha(a.manifest),replay_report_sha256=sha(a.replay/'result.json'),
                replay_decisions_sha256=sha(a.replay/'decisions.json'),script_sha256=sha(__file__),
                policy_headers=report['headers'],training_performed=False,test_files_opened=False,hardware_accessed=False)
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('paired','policy_headers')},indent=2),flush=True)
    print('TEST_PASS paired development gate evaluated (a rejected model is not a tool failure)',flush=True)


if __name__=='__main__':main()
