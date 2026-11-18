"""Freeze the candidate application; generate bits only after final multi-corner STA."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf8")


def deployment_cpu_hz(frozen):
    top = (frozen / 'yolo/portable/052_yolo_camera_top.v').read_text(encoding='utf8')
    mode = re.search(r'parameter\s+AI_FAST_CLOCK\s*=\s*([012])', top)
    return {'0':27000000,'1':74250000,'2':54000000}[mode[1]] if mode else 27000000


def verify_firmware_sources(frozen):
    """Reject stale program ROM before starting an FPGA implementation."""
    cwd = frozen / "yolo/sources"
    firmware_manifest = cwd / "firmware-source-manifest.json"
    if not firmware_manifest.is_file():
        return
    firmware = json.loads(firmware_manifest.read_text(encoding="utf8"))
    for name, expected in firmware["source_hashes"].items():
        relative = Path(name).relative_to("project/trash_sorting/source")
        if sha(frozen / relative) != expected:
            raise ValueError("Firmware was not rebuilt after source change: " + name)
    binary = (cwd / "firmware.bin").read_bytes()
    if sha(cwd / "firmware.bin") != firmware["firmware_sha256"]:
        raise ValueError("Firmware binary identity mismatch")
    lanes = [bytes(int(line, 2) for line in
                   (cwd / f"firmware_lane{i}.bin").read_text().splitlines())
             for i in range(8)]
    ram_bytes=firmware.get('ram_bytes',65536)
    if ram_bytes not in (65536,81920) or any(len(lane) != ram_bytes//8 for lane in lanes):
        raise ValueError("Firmware lanes must each cover declared CPU RAM / 8")
    interleaved = bytes(lanes[i % 8][i // 8] for i in range(ram_bytes))
    if interleaved != binary + bytes(ram_bytes - len(binary)):
        raise ValueError("Firmware lanes do not match the compiled binary")
    model_map=json.loads((frozen/'yolo/model/memory_map.json').read_text(encoding='utf8'))
    nc=firmware.get('raw_model_classes',6)
    compiled_classes=[int(m[1]) for item in firmware['compiler_command']
                      if (m:=re.fullmatch(r'-DYOLO_CLASSES=(\d+)',item))]
    compiled_label=[int(m[1]) for item in firmware['compiler_command']
                    if (m:=re.fullmatch(r'-DYOLO_SINGLE_LABEL=([01])',item))]
    if ('-DYOLO_LINEAR_O2' in firmware['compiler_command']) != firmware.get('linear_o2', False):
        raise ValueError('Compiler/manifest linear optimization mismatch')
    if ('-DYOLO_PACKED_ADD' in firmware['compiler_command']) != firmware.get('packed_add', False):
        raise ValueError('Compiler/manifest packed ADD mismatch')
    if firmware.get('benchmark_mode')=='simulated_demo':
        if ('-DBENCHMARK_DEMO_MODE' not in firmware['compiler_command'] or
                firmware.get('benchmark_is_real_measurement') is not False or
                firmware.get('benchmark_demo_seconds')!=[18,24] or
                firmware.get('benchmark_demo_score_hundredths')!=[512,528]):
            raise ValueError('Simulated demo firmware identity or range mismatch')
    if compiled_classes!=[nc] or compiled_label!=[int(nc in (4,5))]:
        raise ValueError('Compiler/manifest class or decode policy mismatch')
    if nc==5 and (firmware.get('hand_locator_class')!=4 or
                  firmware.get('effective_output_ids')!=[0,1,2,3] or
                  firmware.get('single_label') is not True):
        raise ValueError('Hand must be an internal locator, never a fifth bin')
    if any(model_map['tensors'][i]['c']!=3*(5+nc) for i in model_map['outputs']):
        raise ValueError('Firmware/model head schema mismatch')
    model_hash=sha(frozen/'yolo/model/model.bin')
    if firmware.get('model_sha256',model_hash)!=model_hash or model_hash!=model_map['blob_sha256']:
        raise ValueError('Firmware/model data identity mismatch')
    top=(frozen/'yolo/portable/052_yolo_camera_top.v').read_text(encoding='utf8')
    schema=re.search(r'parameter\s+FOUR_BIN_CLASSES\s*=\s*([01])',top)
    if nc not in (4,5,6) or schema is None or int(schema[1])!=int(nc in (4,5)):
        raise ValueError('RTL/firmware class schema mismatch')
    compiled_hz = [int(m[1]) for item in firmware['compiler_command']
                   if (m := re.fullmatch(r'-DCPU_HZ=(\d+)', item))]
    expected_hz = deployment_cpu_hz(frozen)
    if compiled_hz != [expected_hz] or firmware.get('cpu_hz', expected_hz) != expected_hz:
        raise ValueError('RTL/firmware CPU clock mismatch; UART and timing would be invalid')
    if expected_hz == 54000000:
        import xml.etree.ElementTree as ET
        params = {p.findtext('name'):p.findtext('value') for p in
                  ET.parse(frozen/'yolo/ipcore/pll/pll.idf').getroot().find('param_list')}
        pll = (frozen/'yolo/ipcore/pll/pll.v').read_text()
        for key,value in [('STATIC_RATIOI','1'),('STATIC_RATIOM','2'),
                          ('STATIC_RATIOF','22'),('STATIC_RATIO3','22'),('STATIC_DUTY3','22')]:
            match=re.search(r'localparam\s+(?:integer|real)\s+'+key+r'\s*=\s*([0-9.]+)',pll)
            idf_key='STATIC_RATIO7' if key=='STATIC_RATIOF' else key
            if not match or float(match[1])!=float(value) or float(params[idf_key])!=float(value):
                raise ValueError('54 MHz PLL Verilog/IDF mismatch: '+key)
        if params['CLKOUT3_EN']!='true' or '.CLKOUT3        (clkout3' not in pll:
            raise ValueError('54 MHz PLL output is not enabled')


def timing_gate(text):
    if ("Timing analysis mode : multi corner" not in text or
            "Design Summary : All Constraints Met." not in text or
            "VIOLATED" in text or "Some Constraints Violated" in text):
        raise ValueError("Final multi-corner STA failed")
    result = {}
    for corner in ("Slow", "Fast"):
        for kind in ("Setup", "Hold", "Recovery", "Removal", "Minimum Pulse Width"):
            match = re.search(re.escape(f"{kind} Summary({corner} Corner):") +
                              r"(.*?)(?=\n\s*\w[^\n]*Summary\(|\nSlow Corner|\nFast Corner|\Z)",
                              text, re.S)
            if not match:
                raise ValueError(f"Missing {corner} {kind} summary")
            rows = []
            for line in match[1].splitlines():
                values = line.split()
                if len(values) < 5:
                    continue
                try:
                    slack, total = float(values[-4]), float(values[-3])
                    failing, endpoints = int(values[-2]), int(values[-1])
                except ValueError:
                    continue
                if slack < 0 or total < 0 or failing:
                    raise ValueError("Timing violation: " + line.strip())
                rows.append(dict(clocks=values[:-4], slack_ns=slack, endpoints=endpoints))
            if kind in ("Setup", "Hold"):
                for clock in ("sys_clk", "pix_clk", "cfg_clk", "clk_25M",
                              "cam1_sccb", "cam2_sccb", "ddrphy_sysclk"):
                    if not any(r["clocks"] == [clock, clock] and r["endpoints"] > 0
                               for r in rows):
                        raise ValueError(f"No constrained {corner} {kind} paths: {clock}")
            result[f"{corner}_{kind}"] = rows
    return result


def run_pds(pds, script, cwd, log):
    with log.open("w", encoding="utf8") as handle:
        process = subprocess.run([str(pds / "pds_shell.exe"), "-f", str(script)],
                                 cwd=cwd, stdout=handle, stderr=subprocess.STDOUT)
    text = log.read_text(errors="replace")
    if process.returncode or re.search(r"^\s*E:", text, re.M):
        raise RuntimeError(f"PDS failed; inspect {log}")


def accept_memories(cwd):
    compile_log = (cwd / "compile/run.log").read_text(errors="replace")
    voice_manifest = cwd.parents[1] / 'extensions/business/application/assets/audio_rom/voice_rom_manifest.json'
    voice_bytes = json.loads(voice_manifest.read_text(encoding='utf8'))['rom_bytes']
    voice_banks = (voice_bytes + 2047) // 2048
    if not 0 < voice_banks <= 100:
        raise ValueError('Voice ROM exceeds supported bank capacity')
    names = [f"firmware_lane{i}.bin" for i in range(8)] + [
        f"voice_pcm8.hex.bank{i:02d}.hex" for i in range(voice_banks)] + [
        "ui_light_bg.hex", "ui_light_palette.hex", "ui_light_status.hex"]
    if (cwd/'benchmark_font.hex').is_file():names.append('benchmark_font.hex')
    if (cwd/'media_font.hex').is_file():names+=['media_font.hex','media_labels.hex']
    if "Cannot open specified data" in compile_log:
        raise ValueError("A memory image was missing")
    for name in names:
        if not re.search(r"Loading memory data from file[^\n]*" + re.escape(name), compile_log):
            raise ValueError("Missing memory load evidence: " + name)
    return names


def routed_resources(text):
    """Use the actual routed resource table, including added hold-fix cells."""
    result = {}
    for label, key in (("Use of APM", "APM"), ("FF", "FF"), ("LUT", "LUT"),
                       ("Distributed RAM", "Distributed RAM"), ("Use of DRM", "DRM"),
                       ("Use of IO", "IO")):
        matches = re.findall(r"\|\s*"+re.escape(label)+r"\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|", text)
        # PDS lists CLMA and CLMS FF/LUT pools separately; both consume area.
        expected = 2 if key in ("FF", "LUT") else 1
        if len(matches) != expected:
            raise ValueError("Missing routed resource: " + label)
        result[key] = dict(used=sum(float(m[0]) for m in matches),
                           available=sum(float(m[1]) for m in matches))
    if any(v['used'] > v['available'] for v in result.values()):
        raise ValueError('Over-capacity routed resources')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="New build directory name")
    parser.add_argument("--pds", required=True, type=Path)
    parser.add_argument('--preflight-only',action='store_true',help='Fresh compile/synthesis/device-map only; no placement, bitstream or board changes')
    parser.add_argument("--seed", type=int, default=3)
    parser.add_argument('--route-seed', type=int, default=2,
                        help='Global routing seed; record independently of placement seed')
    parser.add_argument("--ai-fast-clock", action="store_true",
                        help="Freeze existing 74.25 MHz PLL as AI clock; requires matching firmware")
    parser.add_argument('--ai-clock-mode',type=int,choices=(0,1,2),
                        help='0=27, 1=74.25, 2=54 MHz; frozen candidate only')
    parser.add_argument("--firmware-dir", type=Path,
                        help="Overlay precompiled firmware into this new frozen build only")
    parser.add_argument("--model-dir", type=Path,
                        help="Freeze an independent packed model with its matching firmware")
    parser.add_argument("--source-dir", type=Path, default=PROJECT / "source",
                        help="Application source tree; use the handoff snapshot to rebuild a released variant")
    parser.add_argument("--reuse-placement", type=Path,
                        help="Reuse an immutable earlier build's mapped/placed DBs, without resynthesis")
    parser.add_argument('--reseed-placement', action='store_true',
                        help='Reuse frozen mapped inputs but redo placement; requires --reuse-placement')
    parser.add_argument('--optimize-multi-corner-timing', action='store_true',
                        help='Optimize all timing corners during PNR as well as final STA')
    parser.add_argument("--hold-margin-ps", type=int, default=200)
    parser.add_argument('--hold-clock-tree-margin-ps', type=int, choices=range(201), default=200,
                        help='Hold repair target for paths whose clocks do not cross SRB')
    parser.add_argument('--response-hold-min-ns', type=float,
                        help='Add a stricter same-clock minimum delay through response_data bit 208')
    parser.add_argument("--finalize-existing", action="store_true",
                        help="Recheck completed implementation without rerunning or overwriting it")
    parser.add_argument("--fast-router", choices=("TRUE", "FALSE"), default="TRUE")
    parser.add_argument("--share-router-control", choices=("TRUE", "FALSE"), default="TRUE")
    parser.add_argument("--slack-prior-global-router", choices=("TRUE", "FALSE"), default="FALSE",
                        help="Prioritize critical timing paths during global routing")
    parser.add_argument("--release-dir", type=Path, default=PROJECT / "candidates/overnight_020/release",
                        help="Candidate output directory; keep accepted release separate while testing")
    args = parser.parse_args()
    if args.response_hold_min_ns is not None and not .35 <= args.response_hold_min_ns <= 1.0:
        parser.error('--response-hold-min-ns must be .35..1.0 ns (stricter than the original hold arc)')
    if args.response_hold_min_ns is not None and args.reuse_placement:
        parser.error('Supplemental timing must be applied during fresh device mapping; do not append FDC after reusing a mapped DB')
    if Path(args.name).name != args.name or args.name in (".", ".."):
        parser.error("--name must be a directory name")
    if (args.ai_fast_clock or args.ai_clock_mode is not None or args.firmware_dir or args.model_dir) and args.reuse_placement:
        parser.error('A clock or firmware change requires fresh synthesis and placement')
    if args.ai_fast_clock and args.ai_clock_mode is not None:
        parser.error('Use either ai-fast-clock or ai-clock-mode')
    if args.reseed_placement and not args.reuse_placement:
        parser.error('--reseed-placement requires immutable --reuse-placement inputs')
    out = ROOT / "build" / args.name
    if args.finalize_existing:
        inputs = json.loads((out / "inputs.json").read_text(encoding="utf8"))
        args.optimize_multi_corner_timing=inputs.get('optimize_multi_corner_timing',False)
        frozen = out / "input"
        for relative, expected in inputs['files'].items():
            if sha(frozen / relative) != expected:
                raise ValueError('Frozen input changed: ' + relative)
        verify_firmware_sources(frozen)
        args.hold_margin_ps = inputs['hold_margin_ps']
        args.hold_clock_tree_margin_ps = inputs.get('hold_clock_tree_margin_ps', 200)
        args.response_hold_min_ns = inputs.get('response_hold_min_ns')
        args.fast_router = inputs['fast_router']
        args.share_router_control = inputs['share_router_control']
        args.slack_prior_global_router = 'TRUE' if inputs.get('slack_prior_in_global_router', False) else 'FALSE'
        return finalize(args, out, frozen, frozen / 'yolo/sources', inputs.get('reused_placement'))
    out.mkdir(parents=True, exist_ok=False)
    frozen = out / "input"
    reused = None
    if args.reuse_placement:
        previous = args.reuse_placement.resolve()
        prior = json.loads((previous / "inputs.json").read_text(encoding="utf8"))
        for relative, expected in prior["files"].items():
            original = previous / "input" / relative
            if sha(original) != expected:
                raise ValueError("Previous frozen source changed: " + relative)
            destination = frozen / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, destination)
        previous_cwd = previous / "input/yolo/sources"
        dbdir = out / "mapped_input"
        dbdir.mkdir()
        prior_map = previous_cwd / 'device_map/yolo_camera_top_map.adf'
        prior_pcf = previous_cwd / 'device_map/yolo_camera_top.pcf'
        if not prior_map.is_file():
            prior_map = previous / 'mapped_input/yolo_camera_top_map.adf'
            prior_pcf = previous / 'mapped_input/yolo_camera_top.pcf'
            prior_reuse = prior.get('reused_placement')
            if not prior_reuse:
                raise ValueError('Missing mapped database and reuse provenance')
            for path in (prior_map, prior_pcf):
                if sha(path) != prior_reuse['artifact_sha256'][path.name]:
                    raise ValueError('Previously reused mapped input changed: ' + path.name)
        for name, original in (
            ("yolo_camera_top_map.adf", prior_map),
            ("yolo_camera_top.pcf", prior_pcf),
            ("placed_input.adf", previous_cwd / "place_route/yolo_camera_top_plc.adf")):
            shutil.copy2(original, dbdir / name)
        for phase in ("compile", "synthesize", "device_map"):
            destination = frozen / "yolo/sources" / phase
            destination.mkdir(exist_ok=True)
            shutil.copy2(previous_cwd / phase / "run.log", destination / "run.log")
        reused = dict(source_build=str(previous),
                      artifact_sha256={p.name: sha(p) for p in dbdir.iterdir()},
                      copied_logs_from_previous=True,placement_reused=not args.reseed_placement)
    else:
        shutil.copytree(args.source_dir.resolve(), frozen)
    if args.model_dir:
        for name in ('model.bin', 'memory_map.json', 'deployment_model.h'):
            shutil.copy2(args.model_dir / name, frozen / 'yolo/model' / name)
    mode = 1 if args.ai_fast_clock else args.ai_clock_mode
    if mode is not None:
        top_path = frozen / 'yolo/portable/052_yolo_camera_top.v'
        text, count = re.subn(r'(parameter\s+AI_FAST_CLOCK\s*=\s*)[012]',rf'\g<1>{mode}',
                             top_path.read_text(encoding='utf8'))
        if count != 1:
            raise ValueError('Missing or ambiguous AI clock selection')
        top_path.write_text(text, encoding='utf8')
    if args.firmware_dir:
        if reused and sha(args.firmware_dir / 'firmware.bin') != sha(frozen / 'yolo/sources/firmware.bin'):
            raise ValueError('Mapped database contains old program ROM; changed firmware requires fresh synthesis')
        for name in ['firmware.bin', *(f'firmware_lane{i}.bin' for i in range(8))]:
            shutil.copy2(args.firmware_dir / name, frozen / 'yolo/sources' / name)
        shutil.copy2(args.firmware_dir / 'manifest.json',
                     frozen / 'yolo/sources/firmware-source-manifest.json')
    cwd = frozen / "yolo/sources"
    source_script = frozen / "yolo/build_pre_pnr.tcl"
    top = (frozen / "yolo/portable/052_yolo_camera_top.v").read_text(encoding="utf8")
    if not re.search(r"parameter\s+PERIPHERAL_TEST_MODE\s*=\s*0", top):
        raise ValueError("Expected live-camera application mode")
    if ".SERVO_REVERSED_MASK(4'b1111)" not in top:
        raise ValueError("Missing physically verified servo calibration")
    for i in range(8):
        if not (cwd / f"firmware_lane{i}.bin").is_file():
            raise ValueError("Missing firmware lane")
    verify_firmware_sources(frozen)
    response_constraint = None
    if args.response_hold_min_ns is not None:
        response_constraint = cwd / 'response_hold.fdc'
        response_constraint.write_text(
            '# Additional conservative data-path minimum; original clocks and periods unchanged.\n'
            'set response_hold_nets [get_nets {*u_cdc*response_data*208*}]\n'
            'puts "CONSERVATIVE_RESPONSE_HOLD_NET_COUNT [llength $response_hold_nets]"\n'
            'if {[llength $response_hold_nets] != 1} {error "Expected exactly one response_data bit 208 net"}\n'
            'set_min_delay -from [get_clocks {ddrphy_sysclk}] '
            '-through $response_hold_nets '
            f'-to [get_clocks {{ddrphy_sysclk}}] {args.response_hold_min_ns:.3f}\n', encoding='ascii')
        camera_constraints = cwd / 'camera.fdc'
        camera_constraints.write_text(camera_constraints.read_text(encoding='utf8') + '\n' +
                                      response_constraint.read_text(encoding='ascii'), encoding='utf8')
    inputs = {str(p.relative_to(frozen)): sha(p) for p in frozen.rglob("*") if p.is_file()}
    write_json(out / "inputs.json", dict(files=inputs, seed=args.seed, route_seed=args.route_seed,
               fast_router=args.fast_router, share_router_control=args.share_router_control,
               plc_decongestion=4, early_block_placement="Global",
               slack_prior_in_global_router=args.slack_prior_global_router == 'TRUE', pin_cost_increasing_speed=300,
               top="yolo_camera_top", cpu_hz=deployment_cpu_hz(frozen), servo_reversed_mask="1111",
               peripheral_test_mode=0, hold_margin_ps=args.hold_margin_ps,
               hold_clock_tree_margin_ps=args.hold_clock_tree_margin_ps,
               response_hold_min_ns=args.response_hold_min_ns,
               optimize_multi_corner_timing=args.optimize_multi_corner_timing,
               reused_placement=reused, model_sha256=sha(frozen / "yolo/model/model.bin")))
    script = out / "implement.tcl"
    entry = source_script.read_text(encoding="utf8")
    db_args = ""
    if reused:
        mapped = out / "mapped_input/yolo_camera_top_map.adf"
        placed = out / "mapped_input/placed_input.adf"
        pcf = out / "mapped_input/yolo_camera_top.pcf"
        entry = (f"set_arch -input_db_file {{{mapped.as_posix()}}}\n"
                 f"add_constraint {{{pcf.as_posix()}}}\n")
        db_args = f"-input_db_file {{{mapped.as_posix()}}} "
        if reused.get('placement_reused',True):
            db_args += f"-input_place_db_file {{{placed.as_posix()}}} "
    script.write_text(
        # PDS probes the Tcl before reopening its project in the host cwd.
        # Set its interpreter cwd too; the subprocess cwd remains sources/.
        f"cd {{{cwd.as_posix()}}}\n"
        f"set ::env(TRASH_YOLO_ROOT) {{{(frozen / 'yolo').as_posix()}}}\n" +
        # PDS scans compile options before executing the flow. Inline the
        # entry so it sees -system_verilog, including when registering IPs.
        entry + "\n" +
        f"pnr {db_args}-plc_decongestion 4 -early_block_placement Global "
        + ('-optimize_multi_corner_timing ' if args.optimize_multi_corner_timing else '') +
        f"-slack_prior_in_global_router {args.slack_prior_global_router} -pin_cost_increasing_speed 300 "
        f"-share_router_control_signal {args.share_router_control} "
        f"-fast_router {args.fast_router} "
        f"-gplace_seed {args.seed} -groute_seed {args.route_seed} -fix_hold_violation_iterations 300 "
        f"-fix_hold_violation_threshold {args.hold_margin_ps} -fix_hold_violation_in_route TRUE "
        "-fix_hold_violation_threshold_for_clock_path_cross_srb 200 "
        f"-fix_hold_violation_threshold_for_clk_tree {args.hold_clock_tree_margin_ps}\n"
        "report_timing\nputs FULL_APPLICATION_IMPLEMENTATION_COMPLETE\n", encoding="utf8")
    if args.preflight_only:
        script.write_text(f"cd {{{cwd.as_posix()}}}\nset ::env(TRASH_YOLO_ROOT) {{{(frozen/'yolo').as_posix()}}}\n"+entry+'\nputs PREFLIGHT_MAPPING_COMPLETE\n',encoding='utf8')
    print(f"FULL_APPLICATION_BUILD_START {out}", flush=True)
    run_pds(args.pds.resolve(), script, cwd, out / "implementation.log")
    if args.preflight_only:
        write_json(out/'preflight.json',dict(status='COMPILE_SYNTHESIS_MAPPING_COMPLETE',memory_loads=accept_memories(cwd),board_programmed=False,placement_performed=False))
        print('PREFLIGHT_MAPPING_PASS',flush=True)
        return
    finalize(args, out, frozen, cwd, reused)


def finalize(args, out, frozen, cwd, reused):
    print("Implementation finished; checking images, area and final STA", flush=True)
    memory_loads = accept_memories(cwd)
    resources = routed_resources((cwd / 'place_route/yolo_camera_top.prr').read_text(errors='replace'))
    summary = cwd / "multiseed_summary.csv"
    area_csv = out / 'routed_resource_usage.csv'
    with area_csv.open('w', newline='', encoding='utf8') as handle:
        writer = csv.writer(handle)
        writer.writerow(['Logic Utilization', *resources.keys()])
        writer.writerow(['Used', *(int(v['used']) if v['used'].is_integer() else v['used'] for v in resources.values())])
    budget_command = [__import__("sys").executable, str(ROOT / "tools/check_area_budget.py"),
                      "--from-used", str(area_csv), "--module", "trash_full_restored",
                      "--report", str(out / "area-gate.json")]
    subprocess.run(budget_command, check=True, stdout=subprocess.DEVNULL)
    timing = cwd / "report_timing/yolo_camera_top.rtr"
    if args.response_hold_min_ns is not None:
        implementation = (out / 'implementation.log').read_text(errors='replace')
        final_report = timing.read_text(errors='replace')
        if ('CONSERVATIVE_RESPONSE_HOLD_NET_COUNT 1' not in implementation or
                not re.search(r'Set[_ ]Min[_ ]Delay', final_report, re.I)):
            raise ValueError('Supplemental hold constraint was not proven in device mapping and final STA')
    shutil.copy2(summary, out / "final_multiseed_summary.csv")
    model_map=json.loads((frozen/'yolo/model/memory_map.json').read_text(encoding='utf8'))
    nc=(model_map['tensors'][model_map['outputs'][0]]['c']//3)-5
    firmware=json.loads((cwd/'firmware-source-manifest.json').read_text(encoding='utf8'))
    result = dict(memory_loads=memory_loads, resources=resources,
                  raw_model_classes=nc,four_bin_classes=int(nc in (4,5)),
                  hand_locator_class=4 if nc==5 else None,
                  camera_probe_command=firmware.get('camera_probe_command'),
                  linear_o2=firmware.get('linear_o2',False),
                  packed_add=firmware.get('packed_add',False),
                  benchmark_page=firmware.get('benchmark_page',False),ram_bytes=firmware.get('ram_bytes',65536),
                  benchmark_mode=firmware.get('benchmark_mode'),
                  benchmark_reference_sha256=firmware.get('benchmark_reference_sha256'),
                  benchmark_delay_seconds=firmware.get('benchmark_delay_seconds'),
                  benchmark_demo_seconds=firmware.get('benchmark_demo_seconds'),
                  benchmark_demo_score_hundredths=firmware.get('benchmark_demo_score_hundredths'),
                  benchmark_is_real_measurement=firmware.get('benchmark_is_real_measurement'),
                  recognition_single_click=firmware.get('recognition_single_click'),
                  page_double_click_ms=firmware.get('page_double_click_ms'),
                  benchmark_text_words=firmware.get('benchmark_text_words'),
                  benchmark_key=firmware.get('benchmark_key'),
                  benchmark_long_press_ms=firmware.get('benchmark_long_press_ms'),
                  standalone_model_boot=firmware.get('standalone_model_boot',False),
                  boot_model_file=firmware.get('boot_model_file'),
                  boot_model_ddr_crc_verified=firmware.get('boot_model_ddr_crc_verified',False),
                  boot_diagnostic_command=firmware.get('boot_diagnostic_command'),
                  classes=model_map.get('classes',['biodegradable','cardboard','glass','metal','paper','plastic']),
                  checkpoint_sha256=model_map.get('checkpoint_sha256'),
                  model_sha256=sha(frozen / "yolo/model/model.bin"),
                  peripheral_test_mode=0, servo_reversed_mask="1111", cpu_hz=deployment_cpu_hz(frozen),
                  source_build=str(out),
                  fast_router=args.fast_router == "TRUE",
                  share_router_control_signal=args.share_router_control == "TRUE",
                  plc_decongestion=4, early_block_placement="Global",
                  slack_prior_in_global_router=args.slack_prior_global_router == 'TRUE', pin_cost_increasing_speed=300,
                  hold_margin_ps=args.hold_margin_ps,reused_placement=reused,
                  hold_clock_tree_margin_ps=args.hold_clock_tree_margin_ps,
                  response_hold_min_ns=args.response_hold_min_ns,
                  optimize_multi_corner_timing=args.optimize_multi_corner_timing,
                  final_timing=timing_gate(timing.read_text(errors="replace")),
                  timing_pass=True, board_programmed=False, model_loaded=False,
                  physical_full_application_verified=False)
    if result['cpu_hz']==54000000:
        for corner in ('Slow','Fast'):
            for kind in ('Setup','Hold'):
                if not any(r['clocks']==['ai_clk54','ai_clk54'] and r['endpoints']>0
                           for r in result['final_timing'][f'{corner}_{kind}']):
                    raise ValueError('54 MHz AI clock paths were not analyzed')
    write_json(out / "acceptance.json", result)
    script = out / "generate.tcl"
    pnr = cwd / "place_route/yolo_camera_top_pnr.adf"
    script.write_text(f"cd {{{cwd.as_posix()}}}\n"
                      f"set_arch -input_db_file {{{pnr.as_posix()}}}\n"
                      f"gen_bit_stream -force_to_run -input_db_file {{{pnr.as_posix()}}}\n"
                      "puts FULL_APPLICATION_BITSTREAM_COMPLETE\n", encoding="ascii")
    run_pds(args.pds.resolve(), script, cwd, out / "bitstream.log")
    bit = cwd / "generate_bitstream/yolo_camera_top.sbit"
    if not bit.is_file() or not bit.stat().st_size:
        raise ValueError("Missing full application bitstream")
    result.update(bitstream=str(bit), bitstream_sha256=sha(bit))
    write_json(out / "acceptance.json", result)
    evidence = ROOT / "evidence/records/optimization" / args.name
    evidence.mkdir(parents=True, exist_ok=False)
    for p in (out / "inputs.json", out / "acceptance.json", out / "area-gate.json", area_csv,
              out / "implementation.log", out / "bitstream.log", timing,
              cwd / 'place_route/yolo_camera_top.prr'):
        shutil.copy2(p, evidence / p.name)
    shutil.copy2(out / "final_multiseed_summary.csv", evidence / "multiseed_summary.csv")
    for phase in ("compile", "synthesize", "device_map", "place_route"):
        shutil.copy2(cwd / phase / "run.log", evidence / f"{phase}.log")
    release = args.release_dir.resolve()
    release.mkdir(parents=True, exist_ok=True)
    shutil.copy2(bit, release / bit.name)
    write_json(release / "manifest.json", result)
    print(f"FULL_APPLICATION_BITSTREAM_READY {bit} SHA256={sha(bit)}", flush=True)


if __name__ == "__main__":
    main()
