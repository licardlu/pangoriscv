"""Continue once a completed predecessor has closed its run, without duplication."""
import argparse,datetime,hashlib,json,os,subprocess,time
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);a=p.parse_args()
 root=a.root.resolve();base=root/'build/overnight_20261116';state=base/'stage4_queue.json'
 lock=base/'stage4_queue.lock'
 with lock.open('x',encoding='utf8') as f:f.write(str(os.getpid()))
 previous=base/'runs/continuation_stage3_001';python=root/'build/trash_train_env/Scripts/python.exe'
 deadline=datetime.datetime(2026,11,16,0,0,tzinfo=datetime.timezone.utc).timestamp()
 def save(**v):state.write_text(json.dumps(dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),**v),indent=2),encoding='utf8')
 while True:
  provenance=json.loads((previous/'provenance.json').read_text(encoding='utf8'))
  if provenance['status']=='completed':break
  if provenance['status']=='failed':save(status='predecessor_failed');return
  if time.time()>deadline:save(status='deadline_before_start');return
  save(status='waiting_for_stage3');time.sleep(15)
 weights=previous/'weights/best.pt'
 cmd=[str(python),str(base/'train_device.py'),'--yolo',str(base/'upstream/yolov5-7.0'),'--data',str(base/'dataset_stage4/data.yaml'),'--weights',str(weights),'--project',str(base/'runs'),'--name','continuation_stage4_001','--epochs','8','--imgsz','320','--freeze','2','--freeze-bn','--batch','16','--threads','4','--device','cpu','--lr0','0.00005']
 save(status='training',command=cmd,weights_sha256=hashlib.sha256(weights.read_bytes()).hexdigest())
 env=os.environ.copy();env['PYTHONUTF8']='1'
 with (base/'stage4_training.log').open('w',encoding='utf8') as log:r=subprocess.run(cmd,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
 save(status='completed' if r.returncode==0 else 'failed',returncode=r.returncode,command=cmd)
if __name__=='__main__':main()
