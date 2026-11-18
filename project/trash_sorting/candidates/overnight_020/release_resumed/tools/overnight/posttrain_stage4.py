"""Once a formal continuation run closes, evaluate and quantize it once."""
import argparse,datetime,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--stage',type=int,choices=(4,5,6),default=4);a=ap.parse_args()
 stage='stage'+str(a.stage)
 b=ROOT/'build/overnight_20261116';tools=ROOT/'project/trash_sorting/tools/overnight'
 state=b/(stage+'_posttrain_001.json');lock=b/(stage+'_posttrain_001.lock')
 with lock.open('x',encoding='ascii') as f:f.write(str(os.getpid()))
 python=ROOT/'build/trash_train_env/Scripts/python.exe';source=ROOT/'project/trash_sorting/candidates/overnight_020/source'
 previous=b/'runs'/('continuation_stage4_002' if a.stage==4 else 'continuation_'+stage+'_001');deadline=datetime.datetime(2026,11,16,1,0,tzinfo=datetime.timezone.utc).timestamp()
 record=dict(status='waiting_for_completed_training',pid=os.getpid(),steps=[])
 def save():
  record['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
  state.write_text(json.dumps(record,indent=2),encoding='utf8')
 env=os.environ.copy();env['PYTHONUTF8']='1'
 env['ZIG_GLOBAL_CACHE_DIR']=str(b/'zig_cache');env['ZIG_LOCAL_CACHE_DIR']=str(b/'zig_local')
 save()
 try:
  while True:
   p=json.loads((previous/'provenance.json').read_text(encoding='utf8'))
   if p['status']=='completed':break
   if p['status']=='failed':raise RuntimeError('Predecessor training failed')
   if time.time()>=deadline:raise RuntimeError('No closed training run by 09:00')
   time.sleep(15)
  checkpoint=previous/'weights/best.pt';digest=hashlib.sha256(checkpoint.read_bytes()).hexdigest()
  record.update(status='evaluating',checkpoint=str(checkpoint),checkpoint_sha256=digest);save()
  def run(name,args):
   assert hashlib.sha256(checkpoint.read_bytes()).hexdigest()==digest,'Checkpoint changed after training'
   item=dict(name=name,status='running',command=[str(python),*map(str,args)]);record['steps'].append(item);save()
   with (b/(name+'.log')).open('x',encoding='utf8') as log:
    r=subprocess.run(item['command'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
   item.update(status='completed' if r.returncode==0 else 'failed',returncode=r.returncode);save()
   if r.returncode:raise RuntimeError('Failed step '+name)
  for name,data in [(stage+'_original_val',b/'dataset_stage4/data.yaml'),(stage+'_newval',b/'reserved_newval_001/data.yaml')]:
   run(name,[b/'train_device.py','--yolo',b/'upstream/yolov5-7.0','--data',data,
      '--weights',checkpoint,'--project',b/'evaluation','--name',name,'--evaluate','val','--threads','2'])
  for label,manifest,names in [('original',b/'dataset_stage4/manifest.json',('baseline006_original_val','stage3_original_val','stage4_original_val')+(() if a.stage==4 else (stage+'_original_val',))),
                               ('new',b/'reserved_newval_001/manifest.json',('baseline006_newval_002','stage3_newval_002','stage4_newval')+(() if a.stage==4 else (stage+'_newval',)))]:
   args=[tools/'replay_policy.py','--manifest',manifest,'--source-dir',source,'--cc',b/'cc_adapter.exe',
         '--out',b/('policy_'+stage+'_'+label+'_001')]
   for name in names:args+=['--evaluation',b/'evaluation'/name]
   run('policy_'+stage+'_'+label+'_001',args)
  record['status']='quantizing';save()
  run('quant_'+stage+'_001',[tools/'prepare_deployment.py','--out',b/('quant_'+stage+'_001'),
       '--yolo',b/'upstream/yolov5-7.0','--data',b/'dataset_stage4',
       '--checkpoint',checkpoint,'--expected-checkpoint-sha256',digest,'--include-hand'])
  record['status']='checking_numeric';save()
  run('numeric_'+stage+'_exact_001',[tools/'check_deployment.py','--deployment',b/('quant_'+stage+'_001'),
      '--yolo',b/'upstream/yolov5-7.0','--cc',b/'cc_adapter.exe','--clang-host','--exact-q16-head',
      '--out',b/('numeric_'+stage+'_exact_001'),'--checkpoint',checkpoint,'--expected-checkpoint-sha256',digest,
      '--source-dir',source,'--photos',b/'numeric_fixtures_001','--linear-o2'])
  record['status']='completed';save()
 except BaseException as e:
  record.update(status='failed',error=repr(e));save();raise
if __name__=='__main__':main()
