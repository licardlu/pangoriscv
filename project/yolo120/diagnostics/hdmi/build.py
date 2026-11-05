"""Build the independent 720p60 HDMI diagnostic; never programs hardware."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
sys.path.insert(0, str(PROJECT/'tools'))
from build import VIDEO, sha, tool_config, write_json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--name', required=True)
    a = p.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', a.name):
        p.error('Use one new build directory name')
    out = PROJECT/'build'/a.name
    out.mkdir(parents=True, exist_ok=False)
    src = out/'sources'
    src.mkdir()
    inputs = [HERE/'hdmi_startup_top.v', *[VIDEO/'sources'/n for n in
        ('057_iic_dri.v', '059_ms7210_ctl.v', '065_sync_vg.v')]]
    for f in inputs:
        shutil.copy2(f, src/f.name)
    shutil.copytree(VIDEO/'ipcore/pll', out/'ipcore/pll')
    # Only copy actual top-level pins; no invented locations or voltages.
    allowed = {'sys_clk', 'pix_clk', 'vs_out', 'hs_out', 'de_out',
        'r_out', 'g_out', 'b_out', 'rstn_out', 'iic_tx_scl', 'iic_tx_sda', 'uart_txd'}
    constraints = []
    for line in (VIDEO/'sources/camera.fdc').read_text(encoding='utf-8').splitlines():
        m = re.match(r'define_attribute \{p:([^}\[]+)', line)
        if m and m[1] in allowed:
            constraints.append(line)
    pins = '\n'.join(constraints)
    if any(not re.search(r'\{p:'+re.escape(n)+r'(?:\[\d+\])?\} \{PAP_IO_LOC\}', pins)
           for n in allowed):
        raise ValueError('Missing known pin constraint')
    constraints += [
        'create_clock -name sys_clk [get_ports {sys_clk}] -period 37.037037',
        'create_generated_clock -name pix_clk -source [get_ports {sys_clk}] '
        '[get_pins {u_pll/u_gpll:CLKOUT0}] -multiply_by 44 -divide_by 16',
        'create_generated_clock -name cfg_clk -source [get_ports {sys_clk}] '
        '[get_pins {u_pll/u_gpll:CLKOUT1}] -multiply_by 44 -divide_by 119',
        # Status/reset crossings terminate at explicit double synchronizers.
        'set_false_path -from [get_clocks cfg_clk] -to [get_clocks sys_clk]',
    ]
    (out/'hdmi.fdc').write_text('\n'.join(constraints)+'\n', encoding='utf-8')
    q = lambda path: '{'+path.as_posix()+'}'
    design = list(src.glob('*.v')) + [out/'ipcore/pll/pll.idf']
    flow = [*[f'add_design {q(f)}' for f in design],
        f'add_constraint {q(out/"hdmi.fdc")}',
        'set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676',
        f'compile -top_module hdmi_startup_top -include_path {q(src)}',
        'synthesize -ads -selected_syn_tool_opt 2', 'dev_map',
        'pnr -fix_hold_violation_iterations 100 -fix_hold_violation_in_route TRUE '
        '-gplace_seed 2 -groute_seed 2',
        'report_timing', 'gen_bit_stream', 'puts "HDMI_DIAG_FLOW_COMPLETE"']
    (out/'flow.tcl').write_text('\n'.join(flow)+'\n', encoding='utf-8')
    write_json(out/'inputs.json', dict(purpose='independent HDMI diagnostic, not YOLO',
        files=[dict(path=str(f), sha256=sha(f)) for f in inputs],
        constraints_sha256=sha(out/'hdmi.fdc')))
    with (out/'shell.log').open('w', encoding='utf-8') as log:
        done = subprocess.run([tool_config()['pds'], '-file', str(out/'flow.tcl')],
            cwd=out, stdout=log, stderr=subprocess.STDOUT)
    shell = (out/'shell.log').read_text(errors='replace')
    timing = (out/'report_timing/hdmi_startup_top.rtr').read_text(errors='replace')
    if (done.returncode or 'HDMI_DIAG_FLOW_COMPLETE' not in shell or
            'Timing analysis mode : multi corner' not in timing or
            'Design Summary : All Constraints Met.' not in timing or 'VIOLATED' in timing or
            'Clock pin' in shell and 'has no clock' in shell):
        raise RuntimeError('Diagnostic implementation or final STA failed; inspect '+str(out))
    bits = list(out.glob('**/*.sbit'))
    if len(bits) != 1:
        raise ValueError('Expected one diagnostic SRAM image')
    result = dict(purpose='HDMI diagnostic, not YOLO120', timing_pass=True,
        bitstream=str(bits[0]), bitstream_sha256=sha(bits[0]), board_verified=False)
    write_json(out/'acceptance.json', result)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
