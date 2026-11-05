"""Compile the real Tcl source list in ModelSim; no PDS/P&R or device access.

This is an RTL syntax/interface compilation check, not DDR/IP timing sign-off.
"""
import os
from pathlib import Path
import argparse
import re
import subprocess

app = Path(__file__).resolve().parents[1]
yolo = app.parents[2] / 'yolo'
p = argparse.ArgumentParser()
p.add_argument('--modelsim', default=os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64'))
a = p.parse_args()
roots = {'pkg_dir': yolo, 'src_dir': yolo/'sources', 'business_dir': app}
files = []
for var, rest in re.findall(r'add_design \[file join \$(\w+) ([^\]]+)\]',
                            (yolo/'build_pre_pnr.tcl').read_text()):
    path = roots[var].joinpath(*rest.split())
    if path.suffix in ('.v', '.sv'):
        if not path.is_file():
            raise SystemExit('Missing RTL source: '+str(path))
        files.append(path)
build = app/'build'/'sim_yolo_top_compile'
build.mkdir(parents=True, exist_ok=True)
logs = []
for exe,args in [('vlib.exe',['work']),('vlog.exe',[
        '+incdir+'+str(yolo/'sources'/'include'),
        '+incdir+'+str(app/'rtl'), *map(str,files)])]:
    r = subprocess.run([str(Path(a.modelsim)/exe),*args],cwd=build,
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    logs.append(r.stdout)
    if r.returncode:
        print(r.stdout)
        raise SystemExit(r.returncode)
log='\n'.join(logs)
(app/'evidence'/'yolo_top_compile.log').write_text(log,encoding='utf-8')
if '** Error:' in log:
    raise SystemExit(log)
print(f'TEST_PASS real yolo_camera_top Tcl RTL list compiled: {len(files)} files; no PDS/P&R')
