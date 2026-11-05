"""Verify a complete independent HDMI frame and actual serialized UART text."""
import argparse
import re
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
sys.path.insert(0, str(PROJECT/'tools'))
from build import VIDEO, REPO, sha, tool_config, write_json


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--name',required=True)
    a=p.parse_args()
    pll_v=VIDEO/'ipcore/pll/pll.v'
    pll_idf=VIDEO/'ipcore/pll/pll.idf'
    source=pll_v.read_text(encoding='utf-8')
    idf=pll_idf.read_text(encoding='utf-8')
    for name, expected in (('STATIC_RATIO0',16),('STATIC_DUTY0',16)):
        vm=re.search(r'localparam\s+(?:integer|real)\s+'+name+r'\s*=\s*(\d+)',source)
        im=re.search(r'<name>'+name+r'</name>\s*<value>(\d+)</value>',idf)
        if not vm or not im or int(vm[1])!=expected or int(im[1])!=expected:
            raise RuntimeError(f'{name} must be {expected} in both PLL Verilog and IDF')
    out=PROJECT/'build'/a.name
    if out.parent != PROJECT/'build':
        p.error('Use one new directory name')
    out.mkdir(parents=True,exist_ok=False)
    evidence=REPO/'evidence/records/optimization/yolo120'/a.name
    evidence.mkdir(parents=True,exist_ok=False)
    tools=Path(tool_config()['modelsim'])
    sources=[HERE/'hdmi_startup_tb.sv',HERE/'hdmi_startup_top.v',
        *[VIDEO/'sources'/n for n in ('057_iic_dri.v','059_ms7210_ctl.v','065_sync_vg.v')]]
    commands=[[tools/'vlib.exe','work'],[tools/'vlog.exe','-sv',*sources],
        [tools/'vsim.exe','-c','-quiet','-onfinish','exit','hdmi_startup_tb','-do',
         'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']]
    log=''
    for command in commands:
        r=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,
            text=True,errors='replace',timeout=180)
        log+=r.stdout+r.stderr
        (evidence/'simulation.log').write_text(log,encoding='utf-8')
        if r.returncode or '** Error' in log or '** Fatal' in log:
            raise RuntimeError(log[-5000:])
    marker='TEST_PASS hdmi_startup'
    if marker not in log:
        raise RuntimeError('Missing positive pass marker: '+log[-2500:])
    status_sources=[HERE/'hdmi_status_tb.sv',HERE/'hdmi_startup_top.v']
    status_commands=[[tools/'vlib.exe','status_work'],
        [tools/'vlog.exe','-work','status_work','-sv',*status_sources],
        [tools/'vsim.exe','-c','-quiet','-onfinish','exit','status_work.hdmi_status_tb','-do',
         'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']]
    for command in status_commands:
        r=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,
            text=True,errors='replace',timeout=180)
        log+=r.stdout+r.stderr
        (evidence/'simulation.log').write_text(log,encoding='utf-8')
        if r.returncode or '** Error' in log or '** Fatal' in log:
            raise RuntimeError(log[-5000:])
    if 'TEST_PASS hdmi_status' not in log:
        raise RuntimeError('Missing status scanner pass marker: '+log[-2500:])
    avi_sources=[HERE/'hdmi_avi_tb.sv',VIDEO/'sources/059_ms7210_ctl.v']
    avi_commands=[[tools/'vlib.exe','avi_work'],
        [tools/'vlog.exe','-work','avi_work','-sv',*avi_sources],
        [tools/'vsim.exe','-c','-quiet','-onfinish','exit','avi_work.hdmi_avi_tb','-do',
         'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']]
    for command in avi_commands:
        r=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,
            text=True,errors='replace',timeout=180)
        log+=r.stdout+r.stderr
        (evidence/'simulation.log').write_text(log,encoding='utf-8')
        if r.returncode or '** Error' in log or '** Fatal' in log:
            raise RuntimeError(log[-5000:])
    if 'TEST_PASS hdmi_avi' not in log:
        raise RuntimeError('Missing AVI packet pass marker: '+log[-2500:])
    write_json(evidence/'result.json',dict(passed=True,board_verified=False,
        pll_ratio0=16,pll_duty0=16,expected_pixel_period_ns=13.468013468,
        expected_pixel_high_ns=6.734006734,pll_parameter_sources_match=True,
        status_scan_read_only_verified=True,
        avi_packet_checksum_verified=True, avi_vic=4, avi_picture_aspect='16:9',
        files=[dict(path=str(f.relative_to(REPO)),sha256=sha(f))
               for f in dict.fromkeys([*sources,*status_sources,*avi_sources])]))
    print(marker)


if __name__=='__main__':
    main()
