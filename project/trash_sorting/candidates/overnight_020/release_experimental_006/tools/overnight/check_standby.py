"""Render the actual standby RTL at two phases, including control checks."""
import argparse,os,shutil,subprocess
from pathlib import Path
from PIL import Image
def main():
 p=argparse.ArgumentParser();p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--sim-dir',type=Path,default=Path('D:/FPGA_Project/Modelism/win64'));a=p.parse_args()
 root=Path(__file__).resolve().parents[4];source=a.source_dir.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 for name in ('media_font.hex','media_labels.hex'):shutil.copy2(source/'yolo/sources'/name,out/name)
 env=os.environ.copy();env['TEMP']=env['TMP']=str(out)
 for exe,args in [('vlib.exe',['work']),('vlog.exe',['-sv',str(source/'extensions/media/media_display.sv'),str(root/'project/trash_sorting/tests/tb_overnight_standby.sv')]),('vsim.exe',['-c','tb_overnight_standby','-do','run -all; quit -f'])]:
  r=subprocess.run([str(a.sim_dir/exe),*args],cwd=out,env=env,capture_output=True,text=True,timeout=180)
  with (out/'checks.log').open('a',encoding='utf8') as f:f.write(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 assert 'TEST_PASS' in r.stdout and 'TEST_FAIL' not in r.stdout,r.stdout
 for name in ('standby0','standby1'):Image.open(out/(name+'.ppm')).save(out/(name+'.png'))
 print('TEST_PASS standby actual RTL two-phase render',flush=True)
if __name__=='__main__':main()
