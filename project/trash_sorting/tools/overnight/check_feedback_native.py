"""Compile actual candidate callbacks and workload tests; never access hardware."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source-dir',type=Path,required=True)
 p.add_argument('--out',type=Path,required=True);p.add_argument('--cc',type=Path,default=ROOT/'build/overnight_20261116/cc_adapter.exe')
 a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
 sw=a.source_dir.resolve()/'yolo/software';tests=ROOT/'project/trash_sorting/tests';legacy=ROOT/'project/trash_sorting/tools'
 env=os.environ.copy();env['TEMP']=env['TMP']=str(a.out);env['ZIG_GLOBAL_CACHE_DIR']=str(a.out/'zig-cache');env['ZIG_LOCAL_CACHE_DIR']=str(a.out/'zig-local')
 cases={
  'target':([legacy/'test_target_policy.c'],[],'TEST_PASS'),
  'contact':([legacy/'test_contact_policy.c'],[],'TEST_PASS'),
  'camera_gate':([tests/'test_camera_gate.c'],[],'TEST_PASS'),
  'bbox_mmio':([sw/'test_bbox_osd.c'],['-DBBOX_OSD_MMIO_TEST','-DYOLO_CLASSES=5','-DYOLO_SINGLE_LABEL=1'],'BBOX_OSD_MMIO_PASS'),
  'benchmark':([sw/'benchmark_ui.c',tests/'test_feedback_benchmark.c'],['-DBENCHMARK_UI_TEST','-DMEDIA_ENABLE'],'TEST_PASS'),
  'coremark':([sw/'benchmark.c',sw/'coremark_entry.c',tests/'test_feedback_coremark.c',
    *(sw/'coremark'/n for n in ('core_list_join.c','core_matrix.c','core_state.c','core_util.c'))],
    ['-DBENCHMARK_HOST_TEST','-I'+str(sw/'coremark')],'TEST_PASS'),
  'stereo_depth':([sw/'stereo_depth.c',tests/'test_stereo_depth.c'],[],'TEST_PASS'),
  'stereo_platform':([sw/'stereo_depth.c',tests/'test_stereo_platform.c'],['-Wno-unused-function','-Wno-unused-variable','-I'+str(sw.parent/'model')],'TEST_PASS')}
 results={}
 for name,(files,flags,marker) in cases.items():
  command=[str(a.cc.resolve()),'-O2','-Wall','-Wextra','-Werror','-UNDEBUG','-DCPU_HZ=54000000','-I'+str(sw),'-I'+str(tests),*flags,*map(str,files),'-o',str(a.out/(name+'.exe'))]
  build=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=180)
  (a.out/(name+'_build.log')).write_text(build.stdout+build.stderr,encoding='utf8');build.check_returncode()
  run=subprocess.run([str(a.out/(name+'.exe'))],cwd=a.out,env=env,capture_output=True,text=True,timeout=60)
  (a.out/(name+'_run.log')).write_text(run.stdout+run.stderr,encoding='utf8');run.check_returncode();assert marker in run.stdout,run.stdout
  results[name]=dict(command=command,output=run.stdout,files={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files})
  print(name,run.stdout.strip(),flush=True)
 report=dict(status='HOST_TESTS_PASS',scope='actual C callbacks/host workload only; not FPGA timing or camera accuracy',pnr_performed=False,board_modified=False,cases=results,
  source_sha256={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*sw.glob('*.c'),*sw.glob('*.h')]})
 (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')

if __name__=='__main__':main()
