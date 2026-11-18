"""Render the actual candidate RTL with the canvas produced by its native C UI."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
from PIL import Image

def main():
 p=argparse.ArgumentParser();p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--native-exe',type=Path);p.add_argument('--compiler-python',default=sys.executable);p.add_argument('--sim-dir',type=Path,default=Path('D:/FPGA_Project/Modelism/win64'));a=p.parse_args()
 root=Path(__file__).resolve().parents[4];source=a.source_dir.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 sw=source/'yolo/software';tests=root/'project/trash_sorting/tests';rtl=source/'extensions/business/application/rtl'
 env=os.environ.copy();env['TEMP']=env['TMP']=str(out)
 cmd=[a.compiler_python,'-m','ziglang','cc','-O2','-UNDEBUG','-DBENCHMARK_UI_TEST','-I'+str(sw),'-I'+str(tests),str(sw/'benchmark_ui.c'),str(tests/'test_overnight_demo.c'),'-o',str(out/'demo.exe')]
 def run(cmd,cwd=root,timeout=180):
  r=subprocess.run(cmd,cwd=cwd,env=env,capture_output=True,text=True,timeout=timeout)
  with (out/'checks.log').open('a',encoding='utf8') as f:f.write(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(r.stdout+r.stderr)
  return r.stdout
 if a.native_exe:
  shutil.copy2(a.native_exe,out/'demo.exe')
  (out/'native_identity.json').write_text(json.dumps({'reused_native_binary':True,'sha256':hashlib.sha256((out/'demo.exe').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((sw/'benchmark_ui.c').read_bytes()).hexdigest(),'test_sha256':hashlib.sha256((tests/'test_overnight_demo.c').read_bytes()).hexdigest()},indent=2))
 else:run(cmd)
 assert 'TEST_PASS' in run([str(out/'demo.exe'),str(out/'cells.bin')])
 data=(out/'cells.bin').read_bytes();assert len(data)==3520
 (out/'dashboard_cells.hex').write_text(''.join(f'{int.from_bytes(data[i:i+4],"little"):08x}\n' for i in range(0,len(data),4)),encoding='ascii')
 shutil.copy2(source/'yolo/sources/benchmark_font.hex',out/'benchmark_font.hex')
 tools=a.sim_dir.resolve()
 run([str(tools/'vlib.exe'),str(out/'work')])
 run([str(tools/'vlog.exe'),'-sv','-work',str(out/'work'),str(rtl/'benchmark_page.sv'),str(tests/'tb_overnight_dashboard.sv')])
 log=run([str(tools/'vsim.exe'),'-c','-lib','work','tb_benchmark_dashboard','-do','run -all; quit -f'],cwd=out)
 assert 'TEST_PASS' in log and 'TEST_FAIL' not in log,log
 Image.open(out/'dashboard.ppm').save(out/'dashboard.png')
 print('TEST_PASS simulated C canvas and actual RTL render:',out/'dashboard.png',flush=True)
if __name__=='__main__':main()
