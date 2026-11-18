"""Replay a declared geometric fallback for confident narrow held objects.

No candidate source changes, test access, training or board access.
"""
import argparse
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
from collections import Counter,defaultdict
from replay_policy import Box,Target,overlap,sha

ROOT=Path(__file__).resolve().parents[4]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    sw=a.source_dir.resolve()/'yolo/software';b=ROOT/'build/overnight_20261116'
    source=(sw/'yolo_contact_policy.h').read_text(encoding='utf8')
    old='if(overlap<small*.1f || overlap>=(area+hand_area-overlap)*.65f ||'
    assert source.count(old)==1
    original='if(area<=mean_hand_area) {';assert source.count(original)==1
    reports={}
    for name,confidence,aspect in [('unchanged',0.,0.),('confident_narrow',.60,2.),('confident_contact',.70,1.)]:
        config=a.out/name;config.mkdir()
        text=source
        if name!='unchanged':
            text=text.replace(old,
                'float ow=object.x2-object.x1,oh=object.y2-object.y1;\n'
                '            float gapx=target_max(0,target_max(hand.x1-object.x2,object.x1-hand.x2));\n'
                '            float gapy=target_max(0,target_max(hand.y1-object.y2,object.y1-hand.y2));\n'
                '            int reliable=object.score>='+str(confidence)+'f && '
                'target_max(ow,oh)>='+str(aspect)+'f*target_min(ow,oh) && '
                'gapx<=(hand.x2-hand.x1)*.10f && gapy<=(hand.y2-hand.y1)*.10f;\n'
                '            if((overlap<small*.1f && !reliable) || overlap>=(area+hand_area-overlap)*.65f ||')
            text=text.replace(original,'if(area<=mean_hand_area && !reliable) {')
        (config/'yolo_contact_policy.h').write_text(text,encoding='utf8')
        (config/'policy.c').write_text('#include "yolo_contact_policy.h"\nyolo_target_t policy_select(const yolo_box_t*b,unsigned n,unsigned c,unsigned h,float w,float z){return yolo_select_contact_target(b,n,c,h,w,z);}\n',encoding='utf8')
        env=os.environ.copy();env['TEMP']=env['TMP']=str(config)
        env['ZIG_GLOBAL_CACHE_DIR']=str(a.out/'zig-cache');env['ZIG_LOCAL_CACHE_DIR']=str(a.out/'zig-local')
        cmd=[str(b/'cc_adapter.exe'),'-shared','-O2','-I'+str(config),'-I'+str(sw),str(config/'policy.c'),'-o',str(config/'policy.dll')]
        r=subprocess.run(cmd,capture_output=True,text=True,env=env);(config/'compile.log').write_text(r.stdout+r.stderr);r.check_returncode()
        lib=C.CDLL(str(config/'policy.dll'));f=lib.policy_select
        f.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float];f.restype=Target
        splitstats={};alldecisions={}
        for label,numeric,photos,manifest in [('original',b/'numeric_stage4_allval_exact_001',b/'numeric_allval_001',b/'dataset_stage4'),('new',b/'numeric_stage4_newval_exact_001',b/'numeric_newval_inventory_001',b/'reserved_newval_001')]:
            truth={Path(r['prepared_image']).stem:r for r in json.loads((manifest/'manifest.json').read_text(encoding='utf8')) if r['split']=='val'}
            images={r['id']:r for r in json.loads((photos/'inventory.json').read_text(encoding='utf8'))}
            stats=defaultdict(Counter);decisions={}
            for row in json.loads((numeric/'predictions.json').read_text(encoding='utf8')):
                im=images[row['id']];g=truth[Path(im['path']).stem];assert im['sha256']==g['image_sha256']
                boxes=[[*d['box'],d['score'],d['category']] for d in row['detections']]
                cb=(Box*len(boxes))(*[Box(*d[:5],int(d[5])) for d in boxes]);w,h=im['display_size']
                target=f(cb,len(cb),4,4,w,h);selected=boxes[target.object_index] if target.object_index>=0 else None
                gt=[[int(c),(x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h] for c,x,y,bw,bh in g['boxes'] if c<4]
                correct=bool(selected and any(int(selected[5])==v[0] and overlap(selected[:4],v[1:])>=.5 for v in gt))
                groups=['all','source/'+g['source'],'has_waste' if gt else 'no_waste']
                if '/glass/' in str(g.get('image','')).replace('\\','/').lower():groups.append('glass')
                for group in groups:
                    s=stats[group];s['images']+=1;s['selected']+=selected is not None;s['correct']+=correct;s['false_selected']+=bool(selected and not gt)
                decisions[Path(im['path']).stem]=dict(correct=correct,selected=selected,hand_seen=bool(target.hand_seen))
            splitstats[label]=dict(stats);alldecisions[label]=decisions
        (config/'decisions.json').write_text(json.dumps(alldecisions,indent=2),encoding='utf8')
        reports[name]=dict(confidence=confidence,aspect=aspect,cohorts=splitstats,variant_header_sha256=sha(config/'yolo_contact_policy.h'))
    (a.out/'result.json').write_text(json.dumps(dict(status='DEVELOPMENT_COMPARISON_ONLY',test_used=False,reports=reports,source_headers={p.name:sha(p) for p in sw.glob('yolo_*policy.h')}),ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({n:{s:{k:v for k,v in r.items() if k in ('all','no_waste','glass') or k.startswith('source/personal_')} for s,r in v['cohorts'].items()} for n,v in reports.items()}),flush=True)

if __name__=='__main__':main()
