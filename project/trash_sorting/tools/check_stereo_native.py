"""Run candidate host callbacks/math/demo tests, no FPGA or serial access."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--python-zig',type=Path,required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    sw=a.source_dir.resolve()/'yolo/software';tests=ROOT/'project/trash_sorting/tests'
    commands=[]
    cases={
        'stereo_depth':([sw/'stereo_depth.c',tests/'test_stereo_depth.c'],[]),
        'stereo_platform':([sw/'stereo_depth.c',tests/'test_stereo_platform.c'],[
            '-Wno-unused-function','-Wno-unused-variable','-I'+str(sw.parent/'model')]),
        'demo':([sw/'benchmark_ui.c',tests/'test_overnight_demo.c'],[
            '-DBENCHMARK_UI_TEST','-DBENCHMARK_DEMO_MODE','-I'+str(tests)])}
    for name,(files,flags) in cases.items():
        exe=out/(name+'.exe')
        command=[str(a.python_zig.resolve()),'-m','ziglang','cc','-O2','-Wall','-Wextra',
            '-Werror','-UNDEBUG','-DCPU_HZ=54000000','-I'+str(sw),*flags,
            *map(str,files),'-o',str(exe)]
        build=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/(name+'_build.log')).write_text(build.stdout+build.stderr,encoding='utf8')
        build.check_returncode()
        run=subprocess.run([str(exe)],capture_output=True,text=True,timeout=60)
        (out/(name+'.log')).write_text(run.stdout+run.stderr,encoding='utf8')
        run.check_returncode()
        if 'TEST_PASS' not in run.stdout:raise ValueError(run.stdout)
        commands.append(command);print(run.stdout.strip(),flush=True)
    (out/'result.json').write_text(json.dumps(dict(status='HOST_TESTS_PASS',
        cases=list(cases),commands=commands,pnr_performed=False,board_modified=False,
        physical_distance_verified=False,
        source_hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest()
            for f in [*sw.glob('*.c'),*sw.glob('*.h'),*(tests/('test_'+n+'.c')
            for n in ('stereo_depth','stereo_platform','overnight_demo'))]}),indent=2),encoding='utf8')


if __name__=='__main__':main()
