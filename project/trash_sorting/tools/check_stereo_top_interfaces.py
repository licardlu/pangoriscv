"""Elaborate candidate logic against extracted IP interfaces; no PDS or board.

The four generated IP bodies are deliberately omitted. Their parameter/port
declarations come from the actual wrappers. This checks wiring, not IP behavior.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def interface(path):
    text = path.read_text(encoding='utf8')
    text = re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.S)
    match = re.search(r'\bmodule\s+(\w+)\b.*?\);', text, re.S)
    if not match:
        raise ValueError('Missing module header: ' + str(path))
    header = match[0]
    if not re.search(r'\b(input|output|inout)\b', header):
        declarations = re.findall(
            r'^\s*(?:(?:localparam|parameter|input|output|inout)\b)[^;]*;',
            text[match.end():], re.M)
        if not declarations:
            raise ValueError('Missing non-ANSI ports: ' + str(path))
        header += '\n' + '\n'.join(declarations)
    return match[1], header + '\nendmodule\n'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--rtl-result', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--modelsim', type=Path, default=Path('D:/FPGA_Project/Modelism/win64'))
    p.add_argument('--pango-sim', type=Path, default=ROOT.parent / 'pds/PDS_2022.2-SP6.1/arch/vendor/pango/verilog/simulation')
    a = p.parse_args()
    out = a.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    source = a.source_dir.resolve(); yolo = source/'yolo'
    rtl = json.loads(a.rtl_result.read_text(encoding='utf8'))
    files = [Path(path) for path in rtl['top_files']]
    for path in files:
        if digest(path) != rtl['top_files'][str(path)]:
            raise ValueError('RTL changed since simulation: ' + str(path))
    wrappers = [yolo/'ipcore'/name/(name+'.v') for name in
                ('ddr3_test', 'pll', 'rd_fram_buf', 'wr_fram_buf')]
    declarations = [interface(path) for path in wrappers]
    stub = out/'generated_ip_interfaces.v'
    stub.write_text('// INTERFACE CHECK ONLY: no generated IP behavior.\n' +
                    '\n'.join(text for _,text in declarations), encoding='utf8')
    names = sorted(set(re.findall(r'\bGTP_\w+\b', '\n'.join(
        path.read_text(encoding='latin1') for path in files))))
    primitives = [a.pango_sim.resolve()/(name+'.v') for name in names]
    for path in primitives:
        if not path.is_file():
            raise ValueError('Missing real primitive model: ' + str(path))
    def run(exe, *args):
        command = [str(a.modelsim.resolve()/exe), *map(str,args)]
        result = subprocess.run(command, cwd=out, text=True, capture_output=True, timeout=180)
        with (out/'checks.log').open('a', encoding='utf8') as log:
            log.write('COMMAND '+repr(command)+'\n'+result.stdout+result.stderr)
        if result.returncode or re.search(r'\*\* (?:Error|Fatal)', result.stdout+result.stderr):
            raise RuntimeError(result.stdout+result.stderr)
        return result.stdout+result.stderr
    run('vlib.exe','work')
    run('vlog.exe','-sv',
        '+incdir+'+str(yolo/'sources/include'),
        '+incdir+'+str(source/'extensions/business/application/rtl'),
        '+incdir+'+str(source/'extensions/media/third_party/core_mmc/src_v'),
        *primitives, stub, *files)
    output = run('vopt.exe','yolo_camera_top','-o','interface_checked')
    if 'Optimized design name is interface_checked' not in output:
        raise RuntimeError('Missing positive elaboration marker: '+output)
    # Historical unused FIFO/MMC outputs are intentional. Reject all other
    # warnings, including input omissions and width or implicit-net warnings.
    optional={
        '047_axi_cdc.v':{'wlevel'},
        'media_decode_pipeline.sv':{'wlevel'},
        'media_subsystem.sv':{'outport_'+name+'_o' for name in
            ('awvalid','awaddr','awid','awlen','awburst','wvalid','wdata',
             'wstrb','wlast','bready','arvalid','araddr','arid','arlen',
             'arburst','rready')} | {'intr_o','mmc_dat_out_en_o','mmc_dat_out_o'}}
    warnings=[line for line in output.splitlines() if '** Warning:' in line]
    for line in warnings:
        allowed=next((ports for name,ports in optional.items() if name+'(' in line),None)
        missing=re.search(r"Missing connection for port '([^']+)'",line)
        if allowed is None or not (
            ('(vopt-2718)' in line and missing and missing[1] in allowed) or
            ('(vopt-2685)' in line and 'Too few port connections' in line)):
            raise RuntimeError('Unreviewed elaboration warning: '+line)
    (out/'result.json').write_text(json.dumps(dict(
        status='TOP_INTERFACE_ELABORATION_PASS',
        checked_top='yolo_camera_top', rtl_files=len(files),
        top_files={str(path):digest(path) for path in files},
        omitted_generated_ip_bodies={str(path):digest(path) for path in wrappers},
        real_primitive_models={str(path):digest(path) for path in primitives},
        reviewed_unused_output_warnings=warnings,
        scope='actual application logic with extracted generated-IP interfaces',
        generated_ip_behavior_verified=False, full_system_simulation=False,
        pnr_performed=False, board_modified=False), indent=2), encoding='utf8')
    print('TEST_PASS top interfaces elaborated; generated IP behavior not simulated')


if __name__ == '__main__':
    main()
