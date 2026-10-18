#!/usr/bin/env python
"""ModelSim runner for tb/unit/tb_dcache_axi.sv -- the N13 two-way set-associative
data cache unit test.

Checks covered by the testbench (all printed as "ok"/"FAIL" lines):
  1) cold lookup miss  -> exactly one 8-beat INCR refill, then hit in set 0 way 0
  2) same-set other line -> set 0 way 1 refill
  3) LRU eviction: a third line in the same set must replace the older one
  4) 32 B line boundary / adjacent line index
  5) refill error response (RRESP != OKAY) keeps the line invalid and is
     reported to the CPU
  6) back-to-back lookups while a refill is still draining

Usage: python sim/run_dcache_tests.py [--modelsim DIR] [--out DIR] [--keep]
Exit code 0 only when every check passed.
"""
import argparse
import os
import tb_verdict
import random
import string
import subprocess
import sys
import time

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
    run_dir = args.out or os.path.join(repo, '.sim_runs', 'dcache-' + tag)
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

    log_path = os.path.join(run_dir, 'dcache.log')
    with open(log_path, 'w', encoding='utf-8', errors='replace') as log:
        rc, _ = run([vlib, 'work'], run_dir, env, log)
        if rc != 0:
            print('FAIL vlib rc=%d see %s' % (rc, log_path))
            return 1
        rtl = os.path.join(repo, 'rtl')
        files = [
            '-sv',
            '+incdir+' + os.path.join(rtl, 'core'),
            os.path.join(rtl, 'core', 'axi_read_engine.v'),
            os.path.join(rtl, 'core', 'axi_data_engine.v'),
            os.path.join(rtl, 'core', 'dcache_axi.v'),
            os.path.join(rtl, 'perips', 'axi_ram.v'),
            os.path.join(repo, 'tb', 'unit', 'tb_dcache_axi.sv'),
        ]
        rc, out = run([vlog, '-work', 'work'] + files, run_dir, env, log)
        if rc != 0:
            print('FAIL vlog rc=%d see %s' % (rc, log_path))
            return 1
        rc, out = run([vsim, '-c', '-do', 'run -all; quit -f', '-l', 'transcript.txt',
                       'work.tb_dcache_axi'], run_dir, env, log)

    text = open(log_path, encoding='utf-8', errors='replace').read()
    tr = os.path.join(run_dir, 'transcript.txt')
    if os.path.exists(tr):
        text += open(tr, encoding='utf-8', errors='replace').read()
    # review 2026-10-18: every log line is prefixed with '# ', so the old
    # startswith('FAIL') test could never fire and a failing testbench still
    # reported PASS.  Use the shared helper and require the success marker.
    ok, why = tb_verdict.verdict(text, 'TEST_PASS DCACHE')
    if not ok:
        print('FAIL dcache rc=%d %s' % (rc, why))
        for ln in (tb_verdict.failures(text) + tb_verdict.fatals(text))[:10]:
            print('  ' + ln)
        print('  log: ' + log_path)
        return 1
    print('PASS dcache_axi')
    print('SUMMARY 1/1 PASS')
    print('  log: ' + log_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
