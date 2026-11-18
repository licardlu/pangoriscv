"""Run actual benchmark-page CPU/pixel navigation boundary simulation only."""
import argparse,hashlib,json,subprocess
from pathlib import Path


def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--source-dir',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
 a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
 root=Path(__file__).resolve().parents[3]
 rtl=a.source_dir.resolve()/'extensions/business/application/rtl/benchmark_page.sv'
 test=root/'project/trash_sorting/tests/tb_benchmark_navigation_boundary.sv'
 sim=Path('D:/FPGA_Project/Modelism/win64')
 def run(name,*args):
  r=subprocess.run([str(sim/name),*map(str,args)],cwd=a.out,capture_output=True,text=True,timeout=60)
  with (a.out/'checks.log').open('a',encoding='utf8')as f:f.write(r.stdout+r.stderr)
  r.check_returncode();return r.stdout+r.stderr
 run('vlib.exe','work');run('vlog.exe','-sv',rtl,test)
 output=run('vsim.exe','-c','tb_benchmark_navigation_boundary','-do','onerror {quit -code 1}; run -all; quit -code 0')
 passed='TEST_PASS benchmark navigation boundary' in output and '** Fatal' not in output
 report=dict(status='BENCHMARK_BOUNDARY_PASS' if passed else 'BENCHMARK_BOUNDARY_FAILED',
             files={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in (rtl,test)},
             pnr_performed=False,board_modified=False)
 (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
 if not passed:raise RuntimeError(output)
 print('TEST_PASS benchmark late navigation request boundary',flush=True)


if __name__=='__main__':main()
