"""Replay saved validation detections through the actual candidate contact C policy."""
import argparse
from collections import Counter,defaultdict
import ctypes as C
import hashlib,json,os,subprocess
from pathlib import Path

class Box(C.Structure):
    _fields_=[(k,C.c_float) for k in ('x1','y1','x2','y2','score')]+[('category',C.c_uint32)]
class Target(C.Structure):
    _fields_=[('object_index',C.c_int),('hand_index',C.c_int),('hand_seen',C.c_uint)]+[(k,C.c_float) for k in ('x1','y1','x2','y2')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def overlap(a,b):
    area=lambda b:max(0,b[2]-b[0])*max(0,b[3]-b[1])
    v=area([max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])])
    return v/max(1e-12,area(a)+area(b)-v)
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--manifest',type=Path,required=True)
    ap.add_argument('--source-dir',type=Path,required=True)
    ap.add_argument('--evaluation',type=Path,action='append',required=True)
    ap.add_argument('--cc',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--split',choices=('val','test'),default='val',
                    help='Use test only after freezing the deployment selection')
    a=ap.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    root=Path(__file__).resolve().parents[4];sw=a.source_dir.resolve()/'yolo/software'
    test=root/'project/trash_sorting/tools/test_contact_policy.c'
    env=os.environ.copy();env['TEMP']=env['TMP']=str(a.out)
    commands=[]
    for name,flags in [('policy.dll',['-shared']),('policy_test.exe',[])]:
        cmd=[str(a.cc.resolve()),'-std=c11','-O2','-Wall','-Wextra','-Werror','-UNDEBUG',*flags,
             '-I'+str(sw),str(test),'-o',str(a.out/name)]
        r=subprocess.run(cmd,env=env,capture_output=True,text=True);commands.append(cmd)
        (a.out/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf8')
        if r.returncode:raise RuntimeError(r.stdout+r.stderr)
    r=subprocess.run([str(a.out/'policy_test.exe')],capture_output=True,text=True)
    assert r.returncode==0 and 'TEST_PASS' in r.stdout,r.stdout+r.stderr
    (a.out/'policy_test.log').write_text(r.stdout,encoding='utf8')
    lib=C.CDLL(str(a.out/'policy.dll'))
    lib.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float]
    lib.policy_select.restype=Target
    truth={Path(r['prepared_image']).stem:r for r in json.loads(a.manifest.read_text(encoding='utf8')) if r['split']==a.split}
    reports={};all_decisions={}
    for evaluation in a.evaluation:
        saved=json.loads((evaluation/'image_decisions.json').read_text(encoding='utf8'))
        assert set(saved)==set(truth),'Evaluation split identities differ'
        stats=defaultdict(Counter);decisions={}
        for stem,row in saved.items():
            gt=truth[stem];w,h=row['width'],row['height'];boxes=row['detections']
            assert len(boxes)<=32 and all(b[4]>=.25 for b in boxes)
            cb=(Box*len(boxes))(*[Box(*b[:5],int(b[5])) for b in boxes])
            t=lib.policy_select(cb,len(boxes),4,4,w,h)
            chosen=boxes[t.object_index] if t.object_index>=0 else None
            targets=[[int(b[0]),(b[1]-b[3]/2)*w,(b[2]-b[4]/2)*h,(b[1]+b[3]/2)*w,(b[2]+b[4]/2)*h] for b in gt['boxes'] if int(b[0])<4]
            right=bool(chosen and any(int(chosen[5])==b[0] and overlap(chosen[:4],b[1:])>=.5 for b in targets))
            class_right=bool(chosen and any(int(chosen[5])==b[0] for b in targets))
            group=str(gt.get('capture_group',gt.get('group_id',gt.get('group','unspecified'))))
            cohorts=['all','source/'+gt['source'],'public' if not gt['source'].startswith('personal') else 'personal',
                     'has_waste' if targets else 'no_waste','group/'+group]
            for cohort in cohorts:
                s=stats[cohort];s['images']+=1;s['selected']+=chosen is not None;s['hand_seen']+=bool(t.hand_seen)
                if targets:s['correct_class_and_iou050']+=right;s['correct_class']+=class_right
                else:s['false_selected']+=chosen is not None
            decisions[stem]=dict(source=gt['source'],group=group,selected=chosen,hand_seen=bool(t.hand_seen),
                                 expected_waste_classes=sorted({b[0] for b in targets}),correct_class_and_iou050=right,
                                 correct_class=class_right)
        reports[evaluation.name]=dict(cohorts=dict(stats),predictions_sha256=sha(evaluation/'image_decisions.json'),
            weights_sha256=json.loads((evaluation/'provenance.json').read_text(encoding='utf8'))['weights_sha256'])
        all_decisions[evaluation.name]=decisions
    paired={};names=list(all_decisions)
    for name in names[1:]:
        pairs=defaultdict(Counter)
        for stem,old in all_decisions[names[0]].items():
            new=all_decisions[name][stem]
            for cohort in ('all','source/'+old['source']):
                if old['expected_waste_classes']:
                    a1,b1=old['correct_class_and_iou050'],new['correct_class_and_iou050']
                    pairs[cohort]['gain' if b1 and not a1 else 'loss' if a1 and not b1 else 'both_correct' if a1 else 'both_wrong']+=1
                else:
                    a1,b1=old['selected'] is not None,new['selected'] is not None
                    pairs[cohort]['false_selection_removed' if a1 and not b1 else 'false_selection_added' if b1 and not a1 else 'both_false' if a1 else 'both_rejected']+=1
        paired[name]=dict(pairs)
    result=dict(status='PASS',scope='saved CPU floating '+a.split+' detections replayed through actual C selector; not INT8 or board-camera accuracy',
        manifest_sha256=sha(a.manifest),split=a.split,held_out_test_used=a.split=='test',confidence=.25,nms_iou=.45,max_det=32,
        headers={p.name:sha(p) for p in sw.glob('*policy.h')},commands=commands,reports=reports,paired_vs_first=paired)
    (a.out/'result.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf8')
    (a.out/'decisions.json').write_text(json.dumps(all_decisions,indent=2,ensure_ascii=False),encoding='utf8')
    print(json.dumps({name:report['cohorts'].get('no_waste') for name,report in reports.items()}),flush=True)
    print('TEST_PASS candidate C validation selection replay',flush=True)
if __name__=='__main__':main()
