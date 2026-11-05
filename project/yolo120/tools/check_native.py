"""Native numerical regressions; uses an explicitly supplied host C compiler."""
import argparse
import os
from pathlib import Path
import subprocess

from build import PROJECT, YOLO, REPO, write_json


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc',required=True)
    p.add_argument('--out',type=Path,required=True)
    args=p.parse_args()
    out=args.out.resolve()
    if not out.is_relative_to(PROJECT/'build'):
        p.error('Output must be inside project/yolo120/build')
    out.mkdir(parents=True,exist_ok=False)
    env = os.environ.copy()
    env['PATH'] = str(Path(args.cc).resolve().parent) + os.pathsep + env.get('PATH', '')
    cases=[
        ('perf',[YOLO/'sw/yolo_runtime.c',YOLO/'tb/test_yolo_perf.c'],[],'CPU_PERF_CHECK_PASS'),
        ('runtime',[YOLO/'sw/yolo_runtime.c',YOLO/'tb/test_yolo_runtime.c'],[],'CPU_POSTOPS_PASS'),
        ('decode',[YOLO/'sw/yolo_runtime.c',YOLO/'sw/yolo_decode.c',YOLO/'tb/test_yolo_decode.c'],[],'DECODE_PASS'),
        ('bbox',[PROJECT/'sw/platform_main.c',REPO/'extensions/ui_reference/yolo/software/test_bbox_osd.c'],['-DBBOX_OSD_TEST'],'BBOX_OSD_PASS')]
    results=[]
    for name,sources,flags,marker in cases:
        exe=out/(name+'.exe')
        command=[args.cc,'-std=c11','-O2','-Wall','-Wextra','-Werror',
                 '-I'+str(YOLO/'sw'),*flags,*map(str,sources),'-lm','-o',str(exe)]
        result=subprocess.run(command,cwd=out,env=env,capture_output=True,text=True,errors='replace',timeout=120)
        log=result.stdout+result.stderr
        (out/(name+'.log')).write_text(log,encoding='utf-8')
        if result.returncode:
            raise RuntimeError(f'{name}: compiler exit {result.returncode}\n'+log)
        result=subprocess.run([str(exe)],cwd=out,env=env,capture_output=True,text=True,errors='replace',timeout=120)
        log+=result.stdout+result.stderr
        (out/(name+'.log')).write_text(log,encoding='utf-8')
        if result.returncode or marker not in log:
            raise RuntimeError(log)
        results.append(dict(case=name,passed=True,marker=marker))
        print(name+' PASS',flush=True)
    write_json(out/'result.json',dict(cases=results,scope='native numerical tests; no FPGA performance measurement'))


if __name__=='__main__':
    main()
