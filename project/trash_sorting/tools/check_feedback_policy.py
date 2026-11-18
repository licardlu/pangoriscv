"""Compare declared rejection hypotheses on saved DEVELOPMENT Q15 outputs only."""
import argparse, collections, ctypes as C, hashlib, json, os, subprocess, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'overnight'))
from replay_policy import Box, Target, overlap

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-dir',type=Path,required=True)
 p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 root=Path(__file__).resolve().parents[3];b=root/'build/overnight_20261116'
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);sw=a.source_dir.resolve()/'yolo/software'
 # A small declared hypothesis set; final test and its predictions are never opened.
 hypotheses=[('unchanged',.25,.65,1.01),('reject_hand_duplicate',.25,.50,1.01),
             ('scene_area_only',.25,.65,.85),('scene_confidence_030',.30,.65,1.01),
             ('scene_confidence_035',.35,.65,1.01),('scene_confidence_040',.40,.65,1.01),
             ('scene_confidence_045',.45,.65,1.01),('scene_confidence_only',.50,.65,1.01),
             ('reject_weak_scene',.50,.65,.85),('combined',.50,.50,.85)]
 reports={};identities={}
 for label,score,hand_iou,max_area in hypotheses:
  # Materialize temporary variants: the production headers use literal
  # thresholds, so passing unrelated -D flags would silently test nothing.
  config=out/label;config.mkdir()
  contact=(sw/'yolo_contact_policy.h').read_text(encoding='utf8')
  target=(sw/'yolo_target_policy.h').read_text(encoding='utf8')
  target=target.replace('#define YOLO_SCENE_MIN_WASTE_SCORE 0.30f',
                        '#define YOLO_SCENE_MIN_WASTE_SCORE 0.25f')
  old='overlap>=(area+hand_area-overlap)*.65f'
  assert contact.count(old)==1
  contact=contact.replace(old,'overlap>=(area+hand_area-overlap)*'+str(hand_iou)+'f')
  old='if(area>best_area || (area==best_area && object.score>best_score))'
  assert target.count(old)==1
  target=target.replace(old,'if(object.score<'+str(score)+'f || area>width*height*'+str(max_area)+'f)continue;\n        '+old)
  (config/'yolo_contact_policy.h').write_text(contact,encoding='utf8')
  (config/'yolo_target_policy.h').write_text(target,encoding='utf8')
  port=config/'policy.c';port.write_text('#include "yolo_contact_policy.h"\nyolo_target_t policy_select(const yolo_box_t*b,unsigned n,unsigned c,unsigned hand,float w,float h){return yolo_select_contact_target(b,n,c,hand,w,h);}\n',encoding='utf8')
  dll=out/(label+'.dll');cmd=[str(b/'cc_adapter.exe'),'-shared','-O2','-I'+str(config),'-I'+str(sw),str(port),'-o',str(dll)]
  env=os.environ.copy();env['TEMP']=env['TMP']=str(out);env['ZIG_GLOBAL_CACHE_DIR']=str(out/'zig-cache');env['ZIG_LOCAL_CACHE_DIR']=str(out/'zig-local')
  r=subprocess.run(cmd,capture_output=True,text=True,env=env);(out/(label+'_compile.log')).write_text(r.stdout+r.stderr);r.check_returncode()
  lib=C.CDLL(str(dll));f=lib.policy_select;f.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];f.restype=Target
  summary={}
  for split,numeric,photos,manifest in [('original','numeric_stage4_allval_exact_001','numeric_allval_001','dataset_stage4'),('new','numeric_stage4_newval_exact_001','numeric_newval_inventory_001','reserved_newval_001')]:
   pr=b/numeric/'predictions.json';inventory=b/photos/'inventory.json';truth=b/manifest/'manifest.json'
   identities[split]=dict(predictions_sha256=sha(pr),inventory_sha256=sha(inventory),manifest_sha256=sha(truth))
   gt={Path(r['prepared_image']).stem:r for r in json.loads(truth.read_text(encoding='utf8')) if r['split']=='val'}
   images={r['id']:r for r in json.loads(inventory.read_text(encoding='utf8'))};stats=collections.defaultdict(collections.Counter)
   for r in json.loads(pr.read_text(encoding='utf8')):
    image=images[r['id']];g=gt[Path(image['path']).stem];assert image['sha256']==g['image_sha256']
    detections=r['detections'];cb=(Box*len(detections))(*[Box(*d['box'],d['score'],d['category']) for d in detections])
    w,h=image['display_size'];target=f(cb,len(cb),4,4,w,h);selected=detections[target.object_index] if target.object_index>=0 else None
    waste=[[int(c),(cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h] for c,cx,cy,bw,bh in g['boxes'] if c<4]
    correct=bool(selected and any(selected['category']==v[0] and overlap(selected['box'],v[1:])>=.5 for v in waste))
    for cohort in ('all','has_waste' if waste else 'no_waste','source/'+g['source']):
     s=stats[cohort];s['images']+=1;s['selected']+=selected is not None
     s['correct']+=correct;s['false_selected']+=bool(selected and not waste)
   summary[split]=dict(stats)
  reports[label]=dict(parameters=dict(scene_min_score=score,hand_duplicate_iou=hand_iou,max_scene_area=max_area),cohorts=summary,variant_headers={p.name:sha(p) for p in config.glob('*.h')})
 report=dict(status='DEVELOPMENT_COMPARISON_ONLY',test_used=False,training_performed=False,board_accuracy_measured=False,
  hypotheses=reports,input_identities=identities,headers={p.name:sha(p) for p in sw.glob('yolo_*policy.h')})
 (out/'result.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
 for name,r in reports.items():print(name,{s:{k:v for k,v in cohorts.items() if k in ('all','no_waste','source/personal_电池') or 'glass' in k} for s,cohorts in r['cohorts'].items()},flush=True)
if __name__=='__main__':main()
