"""Compare every committed demo canvas across 24 identical baseline/candidate runs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--python-zig',required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    source=a.source_dir.resolve();baseline=json.loads((source.parent/'baseline.json').read_text(encoding='utf8'))
    previous=ROOT/baseline['source'];test=ROOT/'project/trash_sorting/tests/test_overnight_demo.c'
    sw=source/'yolo/software';old=previous/'yolo/software'
    for name in ('benchmark.h','benchmark_text.h','benchmark_mmio.h'):
        assert sha(sw/name)==sha(old/name)
    env=os.environ.copy();env['ZIG_GLOBAL_CACHE_DIR']=str(out/'zig-cache')
    env['TEMP']=env['TMP']=str(out)
    for label,directory in [('baseline',old),('candidate',sw)]:
        binary=out/(label+'.exe')
        command=[a.python_zig,'-m','ziglang','cc','-O2','-UNDEBUG','-DBENCHMARK_UI_TEST',
            '-I'+str(sw),'-I'+str(test.parent),str(directory/'benchmark_ui.c'),str(test),'-o',str(binary)]
        r=subprocess.run(command,env=env,capture_output=True,text=True,timeout=180)
        (out/(label+'_compile.log')).write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode()
        r=subprocess.run([str(binary),str(out/(label+'_first.bin')),str(out/(label+'_all.bin'))],
            capture_output=True,text=True,timeout=30)
        (out/(label+'_run.log')).write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode()
        assert 'TEST_PASS' in r.stdout
    before=(out/'baseline_all.bin').read_bytes();after=(out/'candidate_all.bin').read_bytes()
    assert before==after and len(after)%3520==0 and len(after)>24*3520
    result=dict(status='ALL_COMMITTED_CANVASES_IDENTICAL_PASS',runs=24,
        commits=len(after)//3520,canvas_bytes=3520,compared_bytes=len(after),
        trace_sha256=sha(out/'candidate_all.bin'),
        baseline_source_sha256=sha(old/'benchmark_ui.c'),
        candidate_source_sha256=sha(sw/'benchmark_ui.c'),test_sha256=sha(test),
        pnr_performed=False,board_modified=False)
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':main()
