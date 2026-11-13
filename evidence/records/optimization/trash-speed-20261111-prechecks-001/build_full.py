"""Freeze and build the full 27 MHz application; generate bits only after STA."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf8")


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
    if any(len(lane) != 8192 for lane in lanes):
        raise ValueError("Firmware lanes must each cover 64 KiB / 8")
    interleaved = bytes(lanes[i % 8][i // 8] for i in range(65536))
    if interleaved != binary + bytes(65536 - len(binary)):
        raise ValueError("Firmware lanes do not match the compiled binary")


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
    names = [f"firmware_lane{i}.bin" for i in range(8)] + [
        f"voice_pcm8.hex.bank{i:02d}.hex" for i in range(57)] + [
        "ui_light_bg.hex", "ui_light_palette.hex", "ui_light_status.hex"]
    if "Cannot open specified data" in compile_log:
        raise ValueError("A memory image was missing")
    for name in names:
        if not re.search(r"Loading memory data from file[^\n]*" + re.escape(name), compile_log):
            raise ValueError("Missing memory load evidence: " + name)
    return names


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="New build directory name")
    parser.add_argument("--pds", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=3)
    parser.add_argument("--fast-router", choices=("TRUE", "FALSE"), default="TRUE")
    parser.add_argument("--share-router-control", choices=("TRUE", "FALSE"), default="TRUE")
    parser.add_argument("--release-dir", type=Path, default=PROJECT / "bitstream/full_27mhz",
                        help="Candidate output directory; keep accepted release separate while testing")
    args = parser.parse_args()
    if Path(args.name).name != args.name or args.name in (".", ".."):
        parser.error("--name must be a directory name")
    out = ROOT / "build" / args.name
    out.mkdir(parents=True, exist_ok=False)
    frozen = out / "input"
    shutil.copytree(PROJECT / "source", frozen)
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
    inputs = {str(p.relative_to(frozen)): sha(p) for p in frozen.rglob("*") if p.is_file()}
    write_json(out / "inputs.json", dict(files=inputs, seed=args.seed,
               fast_router=args.fast_router, share_router_control=args.share_router_control,
               plc_decongestion=4, early_block_placement="Global",
               slack_prior_in_global_router=False, pin_cost_increasing_speed=300,
               top="yolo_camera_top", cpu_hz=27000000, servo_reversed_mask="1111",
               peripheral_test_mode=0, model_sha256=sha(frozen / "yolo/model/model.bin")))
    script = out / "implement.tcl"
    script.write_text(
        # PDS probes the Tcl before reopening its project in the host cwd.
        # Set its interpreter cwd too; the subprocess cwd remains sources/.
        f"cd {{{cwd.as_posix()}}}\n"
        f"set ::env(TRASH_YOLO_ROOT) {{{(frozen / 'yolo').as_posix()}}}\n" +
        # PDS scans compile options before executing the flow. Inline the
        # entry so it sees -system_verilog, including when registering IPs.
        source_script.read_text(encoding="utf8") + "\n" +
        f"pnr -plc_decongestion 4 -early_block_placement Global "
        f"-slack_prior_in_global_router FALSE -pin_cost_increasing_speed 300 "
        f"-share_router_control_signal {args.share_router_control} "
        f"-fast_router {args.fast_router} "
        f"-gplace_seed {args.seed} -groute_seed 2 -fix_hold_violation_iterations 300 "
        "-fix_hold_violation_threshold 200 -fix_hold_violation_in_route TRUE "
        "-fix_hold_violation_threshold_for_clock_path_cross_srb 200 "
        "-fix_hold_violation_threshold_for_clk_tree 200\n"
        "report_timing\nputs FULL_APPLICATION_IMPLEMENTATION_COMPLETE\n", encoding="utf8")
    print(f"FULL_APPLICATION_BUILD_START {out}", flush=True)
    run_pds(args.pds.resolve(), script, cwd, out / "implementation.log")
    print("Implementation finished; checking images, area and final STA", flush=True)
    memory_loads = accept_memories(cwd)
    mapped = (cwd / "device_map/run.log").read_text(errors="replace")
    resources = {name: dict(used=float(used), available=float(available))
                 for name, used, available in re.findall(
                     r"\|\s*(APM|FF|LUT|Distributed RAM|DRM|IO)\s*\|\s*"
                     r"([0-9.]+)\s*\|\s*([0-9.]+)\s*\|", mapped)}
    if len(resources) != 6 or any(v["used"] > v["available"] for v in resources.values()):
        raise ValueError("Missing or over-capacity resources")
    summary = cwd / "multiseed_summary.csv"
    budget_command = [__import__("sys").executable, str(ROOT / "tools/check_area_budget.py"),
                      "--from-used", str(summary), "--module", "trash_full_restored",
                      "--report", str(out / "area-gate.json")]
    subprocess.run(budget_command, check=True, stdout=subprocess.DEVNULL)
    timing = cwd / "report_timing/yolo_camera_top.rtr"
    shutil.copy2(summary, out / "final_multiseed_summary.csv")
    result = dict(memory_loads=memory_loads, resources=resources,
                  model_sha256=sha(frozen / "yolo/model/model.bin"),
                  peripheral_test_mode=0, servo_reversed_mask="1111", cpu_hz=27000000,
                  source_build=str(out),
                  fast_router=args.fast_router == "TRUE",
                  share_router_control_signal=args.share_router_control == "TRUE",
                  plc_decongestion=4, early_block_placement="Global",
                  slack_prior_in_global_router=False, pin_cost_increasing_speed=300,
                  final_timing=timing_gate(timing.read_text(errors="replace")),
                  timing_pass=True, board_programmed=False, model_loaded=False,
                  physical_full_application_verified=False)
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
    for p in (out / "inputs.json", out / "acceptance.json", out / "area-gate.json",
              out / "implementation.log", out / "bitstream.log", timing):
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
