"""After a completed continuation, finish both fixed validation replays once."""
import argparse,datetime,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--stage',type=int,choices=(5,6),default=5);a=ap.parse_args()
 stage='stage'+str(a.stage)
 b=ROOT/'build/overnight_20261116';tools=ROOT/'project/trash_sorting/tools/overnight'
 state=b/(stage+'_full_numeric_queue_001.json')
 with (b/(stage+'_full_numeric_queue_001.lock')).open('x') as f:f.write(str(os.getpid()))
 record=dict(status='waiting_'+stage+'_posttrain',pid=os.getpid(),steps=[])
 def save():
  record['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
  state.write_text(json.dumps(record,indent=2),encoding='utf8')
 python=ROOT/'build/trash_train_env/Scripts/python.exe';source=ROOT/'project/trash_sorting/candidates/overnight_020/source'
 env=os.environ.copy();env['PYTHONUTF8']='1';env['ZIG_GLOBAL_CACHE_DIR']=str(b/'zig_cache');env['ZIG_LOCAL_CACHE_DIR']=str(b/'zig_local')
 deadline=datetime.datetime(2026,11,16,1,15,tzinfo=datetime.timezone.utc).timestamp();save()
 try:
  while True:
   predecessor=json.loads((b/(stage+'_posttrain_001.json')).read_text(encoding='utf8'))
   if predecessor['status']=='completed':break
   if predecessor['status']=='failed':raise RuntimeError(stage+' posttrain failed; no downstream evaluation started')
   if time.time()>=deadline:raise RuntimeError(stage+' validation queue deadline')
   time.sleep(15)
  checkpoint=Path(predecessor['checkpoint']);digest=predecessor['checkpoint_sha256']
  def run(name,args):
   assert hashlib.sha256(checkpoint.read_bytes()).hexdigest()==digest
   item=dict(name=name,status='running',command=[str(python),*map(str,args)]);record['steps'].append(item);record['status']=name;save()
   with (b/(name+'.log')).open('x',encoding='utf8') as log:
    r=subprocess.run(item['command'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
   item.update(status='completed' if r.returncode==0 else 'failed',returncode=r.returncode);save()
   if r.returncode:raise RuntimeError('Failed '+name)
  for label,photos,manifest in [('allval',b/'numeric_allval_001',b/'dataset_stage4/manifest.json'),
                                ('newval',b/'numeric_newval_inventory_001',b/'reserved_newval_001/manifest.json')]:
   name='numeric_'+stage+'_'+label+'_exact_001';out=b/name
   run(name,[tools/'check_deployment.py','--deployment',b/('quant_'+stage+'_001'),'--yolo',b/'upstream/yolov5-7.0',
    '--cc',b/'cc_adapter.exe','--clang-host','--exact-q16-head','--out',out,
    '--checkpoint',checkpoint,'--expected-checkpoint-sha256',digest,'--source-dir',source,'--photos',photos,'--linear-o2'])
   name='quantized_'+stage+'_'+('val' if label=='allval' else label)+'_score_001'
   run(name,[tools/'score_numeric_validation.py','--numeric',out,'--photos',photos,'--manifest',manifest,
    '--policy-replay',b/'policy_replay_001','--source-dir',source,'--out',b/name])
  record['status']='completed';save()
 except BaseException as e:
  record.update(status='failed',error=repr(e));save();raise
if __name__=='__main__':main()
