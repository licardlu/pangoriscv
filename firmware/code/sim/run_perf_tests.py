#!/usr/bin/env python
"""ModelSim runner for tb/unit/tb_perf_regs.sv -- the N13/N14 performance
snapshot registers at 0x60002000.

Checks covered by the testbench (printed as "ok"/"FAIL" lines):
  1) before CTRL.SNAP every read returns the empty snapshot bank
  2) a known event mix produces exact counter values, including ARLEN=7 burst
     counts and eight R handshakes per refill
  3) the snapshot stays frozen while the live counters keep moving
  4) CTRL.CLEAR zeroes both banks and clears snapshot_valid
  5) unimplemented offsets, a CTRL write without WSTRB[0] and SNAP+CLEAR at the
     same time all answer SLVERR, while legal accesses answer OKAY

Usage: python sim/run_perf_tests.py [--modelsim DIR] [--out DIR] [--keep]
Exit code 0 only when every check passed.
"""
import argparse
import os
import tb_verdict
import random
import string
import subprocess
import sys

REPO_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # this package root
MODELSIM_DEFAULT = r'E:\donwload\win64'


def run(cmd, cwd, env, log):
    log.write('$ ' + ' '.join(cmd) + '\n')
    log.flush()
    p = subprocess.run(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, universal_newlines=True)
    log.write(p.stdout)
    log.flush()
    return p.returncode, p.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=REPO_DEFAULT)
    ap.add_argument('--modelsim', default=MODELSIM_DEFAULT)
    ap.add_argument('--out', default='')
    ap.add_argument('--case', default='all')
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    tag = ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    run_dir = args.out or os.path.join(repo, '.sim_runs', 'perf-' + tag)
    os.makedirs(run_dir, exist_ok=True)
    print('RUN_DIR ' + run_dir)

    env = dict(os.environ)
    for exe in ('vlib', 'vlog', 'vsim'):
        env['PATH'] = args.modelsim + os.pathsep + env.get('PATH', '')
    vlib = os.path.join(args.modelsim, 'vlib.exe')
    vlog = os.path.join(args.modelsim, 'vlog.exe')
    vsim = os.path.join(args.modelsim, 'vsim.exe')
    for exe in (vlib, vlog, vsim):
        if not os.path.exists(exe):
            print('FAIL missing tool ' + exe)
            return 1

    log_path = os.path.join(run_dir, 'perf.log')
    with open(log_path, 'w', encoding='utf-8', errors='replace') as log:
        rc, _ = run([vlib, 'work'], run_dir, env, log)
        if rc != 0:
            print('FAIL vlib rc=%d see %s' % (rc, log_path))
            return 1
        rtl = os.path.join(repo, 'rtl')
        files = [
            '-sv',
            '+incdir+' + os.path.join(rtl, 'core'),
            os.path.join(rtl, 'perips', 'perf_regs.v'),
            os.path.join(rtl, 'perips', 'axi_reg_slave.v'),
            os.path.join(repo, 'tb', 'unit', 'tb_perf_regs.sv'),
        ]
        rc, out = run([vlog, '-work', 'work'] + files, run_dir, env, log)
        if rc != 0:
            print('FAIL vlog rc=%d see %s' % (rc, log_path))
            return 1
        rc, out = run([vsim, '-c', '-do', 'run -all; quit -f', '-l', 'transcript.txt',
                       'work.tb_perf_regs'], run_dir, env, log)

    text = open(log_path, encoding='utf-8', errors='replace').read()
    tr = os.path.join(run_dir, 'transcript.txt')
    if os.path.exists(tr):
        text += open(tr, encoding='utf-8', errors='replace').read()
    # review 2026-10-18: every log line is prefixed with '# ', so the old
    # startswith('FAIL') test could never fire and a failing testbench still
    # reported PASS.  Use the shared helper and require the success marker.
    ok, why = tb_verdict.verdict(text, 'TEST_PASS PERF')
    if not ok:
        print('FAIL perf rc=%d %s' % (rc, why))
        for ln in (tb_verdict.failures(text) + tb_verdict.fatals(text))[:10]:
            print('  ' + ln)
        print('  log: ' + log_path)
        return 1
    print('PASS perf_regs')
    print('SUMMARY 1/1 PASS')
    print('  log: ' + log_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
