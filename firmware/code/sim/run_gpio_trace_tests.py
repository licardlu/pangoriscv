#!/usr/bin/env python
"""ModelSim runner for tb/integration/tb_gpio_trace.sv -- the plan's small
gpio_trace application (00_PLAN_SPEC.md:149).

The runner builds tests/example/gpio_trace for simulation with
  -DTRACE_STOP_COUNT=8   stop as soon as 8 input changes were captured
  -DTRACE_WINDOW_MS=5    5 ms acquisition window (27 MHz: 135000 cycles)
so that the firmware's own defaults stay the board values (64 entries / 5 s), and then
runs the testbench, which
  * injects 8 KEY transitions 100 cycles apart after the GPIO CTRL write,
  * decodes the UART and parses the 8 reported timestamps (hi/lo halves),
  * checks strictly increasing stamps, printed deltas equal to the real difference,
  * counts led[1] transitions on the pin wire (one per change),
  * checks the UART is silent while the acquisition window is open.

Usage: python sim/run_gpio_trace_tests.py [--repo DIR] [--modelsim DIR]
                                         [--toolchain-bin DIR] [--out DIR] [--keep]
Exit code 0 only when the testbench reports TEST_PASS T_GPIO_TRACE.
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
TOOLCHAIN_DEFAULT = (r'E:\file\pango\toolchains\openisa-1.0.0\gcc'
                     r'\riscv32-unknown-elf-gcc\bin')


def manifest_files(repo):
    """Resolve sim/native_axi_sources.f into absolute paths.

    The manifest is written with repository-relative entries, so passing it with -f
    only works when vlog happens to run from the repository root. vlib/vlog/vsim here
    run inside the throwaway run directory, so every entry (and every +incdir+ path) is
    resolved against the repository instead.
    """
    files = []
    path = os.path.join(repo, 'sim', 'native_axi_sources.f')
    with open(path, encoding='utf-8', errors='replace') as handle:
        for line in handle:
            item = line.strip()
            if not item or item.startswith('//') or item.startswith('#'):
                continue
            if item.startswith('+incdir+'):
                files.append('+incdir+' + os.path.join(repo, item[len('+incdir+'):]))
            elif item.startswith('+') or item.startswith('-'):
                files.append(item)
            else:
                files.append(os.path.join(repo, item))
    return files


def run(cmd, cwd, env, log):
    log.write('$ ' + ' '.join(str(c) for c in cmd) + '\n')
    log.flush()
    p = subprocess.run([str(c) for c in cmd], cwd=cwd, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       universal_newlines=True)
    log.write(p.stdout)
    log.flush()
    return p.returncode, p.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=REPO_DEFAULT)
    ap.add_argument('--modelsim', default=MODELSIM_DEFAULT)
    ap.add_argument('--toolchain-bin', default=TOOLCHAIN_DEFAULT)
    ap.add_argument('--out', default='')
    ap.add_argument('--max-cycles', type=int, default=3000000)
    ap.add_argument('--stop-count', type=int, default=8)
    ap.add_argument('--window-ms', type=int, default=5)
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    tag = ''.join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    run_dir = args.out or os.path.join(repo, '.sim_runs', 'gpio-trace-' + tag)
    os.makedirs(run_dir, exist_ok=True)
    print('RUN_DIR ' + run_dir)

    env = dict(os.environ)
    env['PATH'] = args.modelsim + os.pathsep + env.get('PATH', '')
    vlib = os.path.join(args.modelsim, 'vlib.exe')
    vlog = os.path.join(args.modelsim, 'vlog.exe')
    vsim = os.path.join(args.modelsim, 'vsim.exe')
    for exe in (vlib, vlog, vsim):
        if not os.path.exists(exe):
            print('FAIL missing tool ' + exe)
            return 1

    log_path = os.path.join(run_dir, 'gpio_trace.log')
    with open(log_path, 'w', encoding='utf-8', errors='replace') as log:
        # ---- firmware ---------------------------------------------------------
        build = [sys.executable, os.path.join(repo, 'tools', 'build_native_software.py'),
                 'gpio_trace',
                 '--toolchain-bin', args.toolchain_bin,
                 '--define', 'TRACE_STOP_COUNT=%d' % args.stop_count,
                 '--define', 'TRACE_WINDOW_MS=%d' % args.window_ms]
        rc, _ = run(build, repo, env, log)
        image_dir = os.path.join(repo, 'build', 'native_software', 'gpio_trace',
                                 'performance')
        prog = os.path.join(image_dir, 'program.hex')
        data = os.path.join(image_dir, 'data.hex')
        if rc != 0 or not os.path.exists(prog):
            print('FAIL firmware build rc=%d see %s' % (rc, log_path))
            return 1
        print('IMAGE ' + image_dir)

        rc, _ = run([vlib, 'work'], run_dir, env, log)
        if rc != 0:
            print('FAIL vlib rc=%d see %s' % (rc, log_path))
            return 1
        rtl = os.path.join(repo, 'rtl')
        files = [
            '-sv',
            '+incdir+' + os.path.join(rtl, 'core'),
            '+incdir+' + os.path.join(rtl, 'soc'),
        ] + manifest_files(repo) + [
            os.path.join(repo, 'tb', 'integration', 'tb_gpio_trace.sv'),
        ]
        rc, out = run([vlog, '-work', 'work'] + files, run_dir, env, log)
        if rc != 0:
            print('FAIL vlog rc=%d see %s' % (rc, log_path))
            return 1
        rc, _ = run([vsim, '-c', '-do', 'run -all; quit -f', '-l', 'transcript.txt',
                     'work.tb_gpio_trace',
                     '+PROG=' + prog, '+DATA=' + data,
                     '+MAX_CYCLES=%d' % args.max_cycles], run_dir, env, log)

    text = open(log_path, encoding='utf-8', errors='replace').read()
    tr = os.path.join(run_dir, 'transcript.txt')
    if os.path.exists(tr):
        text += open(tr, encoding='utf-8', errors='replace').read()
    # review 2026-10-18: log lines carry a '# ' prefix, so startswith('FAIL')
    # could never fire.  Strip the prefix through the shared helper.
    bad = [ln for ln in tb_verdict.failures(text)]
    bad = [ln for ln in bad if ln.startswith('FAIL') or ln.startswith('TRACE_ERROR')]
    fatal = tb_verdict.fatals(text)
    passed = tb_verdict.passed(text, 'TEST_PASS T_GPIO_TRACE')
    if bad or fatal or rc != 0 or not passed:
        print('FAIL gpio_trace rc=%d fails=%d' % (rc, len(bad)))
        for ln in (bad + fatal)[:12]:
            print('  ' + ln)
        for ln in text.splitlines():
            if ln.startswith('TRACE_SUMMARY'):
                print('  ' + ln)
        print('  log: ' + log_path)
        return 1
    print('PASS gpio_trace')
    for ln in text.splitlines():
        if ln.startswith('TRACE_SUMMARY'):
            print('  ' + ln)
    print('SUMMARY 1/1 PASS')
    print('  log: ' + log_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
