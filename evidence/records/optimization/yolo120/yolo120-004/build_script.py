"""Relocatable YOLO120 build; never programs a board. Outputs are immutable runs."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[1]
CPU = REPO / 'project/cpu120'
YOLO = REPO / 'extensions/yolo'
VIDEO = REPO / 'extensions/ui_reference/yolo'
HZ = 120461538


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


def write_json(p, obj):
    p.write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding='utf-8')


def tool_config():
    p = REPO / 'tools/local-tools.json'
    return json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}


def audit_cpu():
    record = json.loads((CPU/'release_manifest.json').read_text())
    missing, verified = [], []
    for entry in record['files']:
        p = CPU/entry['path']
        if not p.is_file():
            missing.append(entry['path'])
        elif sha(p) != entry['sha256']:
            raise ValueError('Frozen CPU file hash mismatch: '+entry['path'])
        else:
            verified.append(entry['path'])
    # Missing historical docs/reference tests do not invalidate the available
    # implementation inputs; disclose them instead of rewriting its manifest.
    if any(p.startswith(('rtl/', 'constraints/', 'configuration/')) for p in missing):
        raise ValueError('CPU implementation input missing')
    for line in (CPU/'sources.f').read_text().splitlines():
        if line.strip() and line.strip() not in verified:
            raise ValueError('CPU source not bound to supplied manifest: '+line)
    return dict(available_hashes_verified=len(verified), missing_archive_entries=missing,
                complete_release_verified=False, integrated_board_verified=False)


def firmware(out, prefix):
    out.mkdir()
    gcc = prefix+'-gcc'+('.exe' if os.name == 'nt' else '')
    objcopy = prefix+'-objcopy'+('.exe' if os.name == 'nt' else '')
    size = prefix+'-size'+('.exe' if os.name == 'nt' else '')
    sources = [YOLO/'sw'/p for p in ('platform_start.S', 'yolo_forward.c',
                                    'yolo_runtime.c', 'yolo_decode.c')]
    sources.append(PROJECT/'sw/platform_main.c')
    cmd = [gcc, '-march=rv32im', '-mabi=ilp32', '-Os', '-ffunction-sections',
           '-fdata-sections', '-ffreestanding', '-Wall', '-Wextra', '-Werror',
           '-fstack-usage', '-nostartfiles', '-DVEXII_PLATFORM',
           '-DACC_BASE=0x10003100u', f'-DCPU_HZ={HZ}u',
           '-I'+str(YOLO/'sw'), '-I'+str(YOLO/'gen/integration/packed'),
           '-T'+str(YOLO/'sw/vexii_platform.ld'),
           '-Wl,--gc-sections,-Map='+str(out/'firmware.map'),
           *map(str, sources), '-lm', '-lc', '-lgcc', '-o', str(out/'firmware.elf')]
    subprocess.run(cmd, cwd=out, check=True)
    subprocess.run([size, str(out/'firmware.elf')], check=True)
    subprocess.run([objcopy, '-O', 'binary', str(out/'firmware.elf'),
                    str(out/'firmware.bin')], check=True)
    data = (out/'firmware.bin').read_bytes()
    if not data or len(data) > 65536:
        raise ValueError('Invalid firmware RAM size')
    ram = data.ljust(65536, b'\0')
    for lane in range(8):
        name = f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin'
        (out/name).write_text(''.join(f'{v:08b}\n' for v in ram[lane::8]), encoding='ascii')
    (out/'program.hex').write_text(''.join(
        f'{int.from_bytes(ram[i:i+4], "little"):08x}\n' for i in range(0,65536,4)), encoding='ascii')
    (out/'data.hex').write_text('00000000\n', encoding='ascii')
    image = module(CPU/'tools/verify_image.py', 'verify_image').verify(out/'firmware.elf', out)
    image.update(cpu_hz=HZ, isa='rv32im', camera_stream_default=True, sim_preload=False,
                 model_sha256=sha(YOLO/'gen/integration/packed/model.bin'),
                 board_verified=False)
    write_json(out/'manifest.json', image)
    return image


def prepare(out, prefix, cpu_region=None):
    cpu_audit = audit_cpu()
    image = firmware(out/'firmware', prefix)
    source = out/'sources'
    source.mkdir()
    generator = module(YOLO/'scripts/generate_vexii_soc.py', 'generate_soc')
    generated = out/'generated'
    generator.generate(CPU, generated)
    inputs = []
    design = []

    def stage(p, name=None):
        p = p.resolve()
        target = source/(name or p.name)
        if target.exists():
            raise ValueError('Source basename collision: '+str(target))
        shutil.copy2(p, target)
        inputs.append(dict(path=p.relative_to(REPO).as_posix(), sha256=sha(p)))
        design.append(target)
        return target

    for line in (CPU/'sources.f').read_text().splitlines():
        if not line or line.startswith('#') or 'rtl/board/' in line or line.endswith('/MicroSoc.v'):
            continue
        p = CPU/line
        stage(generated/'TilelinkUartCtrl.v' if p.name=='TilelinkUartCtrl.v' else p)
    stage(generated/'vexii_ai_soc.v')
    shutil.copytree(CPU/'rtl/core/sections', source/'sections')
    for p in (CPU/'rtl/core').glob('*.vh'):
        shutil.copy2(p, source/p.name)
    for p in ('tlul_to_axil.v','conv_band_rt.v','requant_q15.v','mac_array.v',
              'ddr_axi_bridge.v','bridge_to_cdc.v','axi_cdc.v','camera_snapshot.v',
              'ddr_native_arbiter.v'):
        stage(YOLO/'rtl'/p)
    for p in sorted((PROJECT/'rtl').glob('*.v')):
        stage(p)
    pll = stage(CPU/'rtl/board/pango_pll.sv', 'ai_perf_pll.sv')
    text = pll.read_text().replace('module pango_pll(', 'module ai_perf_pll(', 1)
    if 'module ai_perf_pll(' not in text:
        raise ValueError('PLL template changed')
    pll.write_text(text, encoding='utf-8')
    for p in sorted((VIDEO/'sources').glob('*.v')):
        if int(p.name[:3]) >= 53:
            stage(p)
    shutil.copytree(VIDEO/'ipcore', out/'ipcore')
    for name in ('ddr3_test','pll','rd_fram_buf','wr_fram_buf'):
        design.append(out/'ipcore'/name/(name+'.idf'))
    for p in (out/'firmware').glob('*.bin'):
        if p.name.startswith('MicroSoc.'):
            shutil.copy2(p, out/p.name)
    for name in ('program.hex', 'data.hex'):
        shutil.copy2(out/'firmware'/name, out/name)
    # Use the unmodified video package's constraints, then constrain the new
    # independent AI PPLL at a conservative 8.3000 ns (actual 8.301405 ns).
    fdc = (VIDEO/'sources/camera.fdc').read_text(encoding='utf-8')
    # Define the configuration PLL output before the inherited clock-group
    # commands. The vendor GPLL is 27 * (2*22) / 48 = 24.75 MHz, 50% duty.
    fdc = fdc.replace('###==== BEGIN "Generated Clocks"', '''
create_generated_clock -name {clk_25M} -source [get_ports {sys_clk}] [get_pins {u_pll/u_gpll:CLKOUT2}] -multiply_by 44 -divide_by 48
# RTL divides by 2500 (101010 ns actual). PDS rejects periods >=100000 ns.
# Model an integer /2400 (96873 ns) for stricter intra-domain setup, preserving
# source-edge alignment. SCCB has no synchronous data exchange with /25M logic.
create_generated_clock -name {cam1_sccb} -source [get_pins {u_pll/u_gpll:CLKOUT2}] [get_pins {coms1_reg_config:clock_20k}] -master_clock [get_clocks {clk_25M}] -divide_by 2400
create_generated_clock -name {cam2_sccb} -source [get_pins {u_pll/u_gpll:CLKOUT2}] [get_pins {coms2_reg_config:clock_20k}] -master_clock [get_clocks {clk_25M}] -divide_by 2400
###==== BEGIN "Generated Clocks"''')
    # These historical names never existed. Keep the supported root-clock CDC
    # groups below; do not rely on silently ignored groups with empty targets.
    fdc = re.sub(r'^set_clock_groups -name (?:cfg_clk|pix_clk) .*\n', '', fdc, flags=re.M)
    fdc += '''
create_clock -name {ai_clk} [get_pins {ai_clock_pll/u_ppll:CLKOUT0}] -period {8.3000} -waveform {0.0000 4.1500}
set_clock_groups -name ai_to_video_async -asynchronous -group [get_clocks {ai_clk}] -group [get_clocks sys_clk -include_generated_clocks] -group [get_clocks {dvp1 dvp1_pixel dvp2 dvp2_pixel}]
set_clock_groups -name ai_to_ddr_async -asynchronous -group [get_clocks {ai_clk}] -group [get_clocks ref_clk -include_generated_clocks]
'''
    (out/'camera.fdc').write_text(fdc, encoding='utf-8')
    physical = []
    if cpu_region:
        # PDS User Guide pp.77-78: these are floorplan logical coordinates,
        # not the CLMA_x_y resource-name coordinates from the timing report.
        xmin, xmax, ymin, ymax = cpu_region
        if not (0 <= xmin < xmax and 0 <= ymin < ymax):
            raise ValueError('Invalid CPU region bounds')
        pcf = out/'cpu_region.pcf'
        pcf.write_text('def_region cpu_core_region '+
                       ' '.join(map(str, cpu_region))+'\n'+
                       'def_inst_region {ai/cpu/system_cpu_logic_core} cpu_core_region\n',
                       encoding='ascii')
        physical.append(pcf)
    # Every staged dependency, including encrypted IP and CPU includes, is hashed.
    snapshot = [dict(path=p.relative_to(out).as_posix(), sha256=sha(p))
                for d in (source, out/'ipcore', out/'firmware')
                for p in sorted(d.rglob('*')) if p.is_file()]
    write_json(out/'inputs.json', dict(cpu_audit=cpu_audit, firmware=image,
               sources=inputs, snapshot=snapshot, board_verified=False,
               constraints_sha256=sha(out/'camera.fdc'),
               cpu_region=cpu_region,
               physical_constraints=[dict(path=p.name, sha256=sha(p)) for p in physical],
               build_script_sha256=sha(Path(__file__))))
    (out/'sources.f').write_text('\n'.join(str(p) for p in design)+'\n', encoding='utf-8')
    q = lambda p: '{'+p.as_posix()+'}'
    return [*[f'add_design {q(p)}' for p in design],
            f'add_constraint {q(out/"camera.fdc")}',
            *[f'add_constraint {q(p)}' for p in physical],
            'set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676',
            f'compile -top_module yolo_camera_top -include_path {q(source)}',
            'synthesize -ads -selected_syn_tool_opt 2', 'dev_map']


def final_timing(text):
    """Gate on the final multi-corner report, never the hold-fix snapshot."""
    if ('Timing analysis mode : multi corner' not in text or
            'Design Summary : All Constraints Met.' not in text or
            'VIOLATED' in text or 'Some Constraints Violated' in text):
        raise ValueError('Final multi-corner timing did not pass')
    summaries = {}
    for corner in ('Slow', 'Fast'):
        for kind in ('Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width'):
            match = re.search(re.escape(f'{kind} Summary({corner} Corner):')+
                              r'(.*?)(?=\n\s*\w[^\n]*Summary\(|\nSlow Corner|\nFast Corner|\Z)',
                              text, re.S)
            if not match:
                raise ValueError(f'Missing final {corner} {kind} summary')
            rows = []
            for line in match[1].splitlines():
                values = line.split()
                if len(values) < 5:
                    continue
                try:
                    slack, total, failing, endpoints = (float(values[-4]), float(values[-3]),
                                                       int(values[-2]), int(values[-1]))
                except ValueError:
                    continue
                if slack < 0 or total < 0 or failing:
                    raise ValueError(f'Final {corner} {kind} violation: '+line.strip())
                rows.append(dict(clocks=values[:-4], slack_ns=slack, endpoints=endpoints))
            if kind in ('Setup', 'Hold'):
                for clock in ('ai_clk', 'cam1_sccb', 'cam2_sccb'):
                    if not any(row['clocks'] == [clock, clock] and row['endpoints'] > 0 for row in rows):
                        raise ValueError(f'{clock} has no constrained {corner} {kind} paths')
            summaries[f'{corner.lower()}_{kind.lower().replace(" ", "_")}'] = rows
    return summaries


def accept(out, synthesis_only):
    log = (out/'compile/run.log').read_text(errors='replace')
    names = [f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{i}.bin' for i in range(8)]
    if 'Cannot open specified data' in log or any(
            not re.search(r'Loading memory data from file[^\n]*'+re.escape(n), log) for n in names):
        raise ValueError('Eight firmware lanes were not loaded by PDS')
    mapped = (out/'device_map/run.log').read_text(errors='replace')
    resources = {name: dict(used=float(used), available=float(available))
                 for name, used, available in re.findall(
                     r'\|\s*(APM|FF|LUT|Distributed RAM|DRM|IO)\s*\|\s*'
                     r'([0-9.]+)\s*\|\s*([0-9.]+)\s*\|', mapped)}
    if len(resources) != 6 or any(v['used'] > v['available'] for v in resources.values()):
        raise ValueError('Missing or over-budget mapped resources')
    result = dict(resources=resources, cpu_hz=HZ, firmware_lanes_loaded=True,
                  board_verified=False, one_second_board_target_met=False,
                  routed=False, timing_pass=False, bitstream=None)
    write_json(out/'acceptance.json', result)
    if not synthesis_only:
        routed = (out/'place_route/run.log').read_text(errors='replace')
        if 'has been placed and routed successfully' not in routed:
            raise ValueError('Routing did not complete')
        result['routed'] = True
        write_json(out/'acceptance.json', result)
        result['final_timing'] = final_timing((out/'report_timing/yolo_camera_top.rtr').read_text(errors='replace'))
        bits = list(out.glob('**/*.sbit'))
        if len(bits) != 1 or not bits[0].stat().st_size:
            raise ValueError('Expected one nonempty bitstream')
        result.update(timing_pass=True, bitstream=str(bits[0]), bitstream_sha256=sha(bits[0]))
    write_json(out/'acceptance.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', default=datetime.now().strftime('%Y%m%d_%H%M%S'))
    parser.add_argument('--gcc-prefix')
    parser.add_argument('--pds')
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--synthesis-only', action='store_true')
    parser.add_argument('--cpu-region', nargs=4, type=int, metavar=('XMIN','XMAX','YMIN','YMAX'))
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name):
        parser.error('Build name must be a single directory name')
    config = tool_config()
    prefix = args.gcc_prefix or os.environ.get('RISCV_GCC_PREFIX') or config.get('gcc_prefix')
    if not prefix:
        parser.error('Supply --gcc-prefix (without trailing dash)')
    out = PROJECT/'build'/args.name
    out.mkdir(parents=True, exist_ok=False)
    lines = prepare(out, prefix, args.cpu_region)
    if not args.synthesis_only:
        lines += ['pnr -plc_decongestion 1 -share_router_control_signal TRUE '
                  '-fix_hold_violation_threshold 200 -fix_hold_violation_threshold_for_clk_tree 200 '
                  '-fix_hold_violation_threshold_for_clock_path_cross_srb 200 '
                  '-fix_hold_violation_iterations 300 -fix_hold_violation_in_route TRUE '
                  '-gplace_seed 2 -groute_seed 2', 'report_timing', 'gen_bit_stream']
    lines += ['puts "YOLO120_FLOW_COMPLETE"']
    flow = out/'flow.tcl'
    flow.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print('YOLO120_PREPARED '+str(out), flush=True)
    if args.run:
        pds = args.pds or os.environ.get('PDS_SHELL') or config.get('pds')
        if not pds:
            parser.error('Supply --pds')
        with (out/'shell.log').open('w', encoding='utf-8') as log:
            done = subprocess.run([pds, '-file', str(flow)], cwd=out,
                                  stdout=log, stderr=subprocess.STDOUT)
        text = (out/'shell.log').read_text(errors='replace')
        if done.returncode or 'YOLO120_FLOW_COMPLETE' not in text:
            raise RuntimeError('PDS did not complete: '+str(out/'shell.log'))
        print(json.dumps(accept(out, args.synthesis_only), indent=2))


if __name__ == '__main__':
    main()
