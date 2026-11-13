"""Measure a full-application release without changing its model or clock."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import statistics
import struct
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]
sys.path.insert(0, str(ROOT / "extensions/yolo/scripts"))
from board_loader import load_deployment, parse_detections, transact, write_image
from board_perf import parse_profile


def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf8")


def summarize(runs):
    measured = [run for run in runs if not run["warmup"]]
    times = [max(run["wall_seconds"], run["device_seconds"]) for run in measured]
    if not times:
        raise ValueError("No measured frames")
    return dict(frames=len(times), mean_seconds=statistics.mean(times),
                median_seconds=statistics.median(times), minimum_seconds=min(times),
                maximum_seconds=max(times), fps=1 / statistics.mean(times),
                stages_mean_seconds={name: statistics.mean(
                    run["profile"]["stages"][name] for run in measured)
                    for name in ("capture", "forward", "decode", "display")},
                operators_by_kind_mean_seconds={name: statistics.mean(
                    run["profile"]["seconds_by_kind"].get(name, 0) for run in measured)
                    for name in measured[0]["profile"]["seconds_by_kind"]})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True)
    parser.add_argument("--release", type=Path, default=PROJECT / "bitstream/full_27mhz")
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--frames", type=int, default=10)
    parser.add_argument("--program", action="store_true", help="Program this release into SRAM first")
    parser.add_argument("--pds", type=Path)
    parser.add_argument("--upload-model", action="store_true")
    parser.add_argument("--camera-mode", type=int, choices=(0, 1),
                        help="Optional cmd10 mode, only supported by new candidate firmware")
    parser.add_argument("--verify-input", action="store_true",
                        help="Candidate cmd11: compare full old/new packed input CRC on one snapshot")
    parser.add_argument("--leave-controlled", action="store_true",
                        help="Leave command mode for another benchmark; default resumes recognition")
    args = parser.parse_args()
    if args.frames < 3 or (args.program and not args.pds):
        parser.error("Use >=3 frames and supply --pds with --program")
    acceptance = json.loads((args.release / "manifest.json").read_text(encoding="utf8"))
    bit = args.release / "yolo_camera_top.sbit"
    bit_sha = hashlib.sha256(bit.read_bytes()).hexdigest()
    if (not acceptance.get("timing_pass") or acceptance.get("peripheral_test_mode") != 0
            or acceptance.get("servo_reversed_mask") != "1111"
            or bit_sha != acceptance["bitstream_sha256"]):
        raise ValueError("Full release identity/timing gates failed")
    model_folder = args.release / 'model'
    if not (model_folder / 'model.bin').is_file():
        model_folder = Path(acceptance['source_build']) / 'input/yolo/model'
    model, blob = load_deployment(model_folder)
    if hashlib.sha256(blob).hexdigest() != acceptance["model_sha256"]:
        raise ValueError("Paired model mismatch")
    args.out.mkdir(parents=True, exist_ok=False)
    report = dict(started_utc=datetime.now(timezone.utc).isoformat(), runs=[], complete=False,
                  bitstream_sha256=bit_sha, model_sha256=acceptance["model_sha256"],
                  port=args.port, release=str(args.release.resolve()),
                  programmed_in_this_run=False, autonomous_resumed=False,
                  camera_mode=args.camera_mode,
                  metric="max(host request/reply, capture+forward+decode+display cycles/Hz)",
                  excludes="one-time model upload/CRC, speech, user answer and servo movement",
                  identity_note="Firmware cannot attest bitstream hash; program exact release first")
    save(args.out / "result.json", report)
    try:
        if args.program:
            subprocess.run([sys.executable, str(ROOT / "extensions/yolo/scripts/program_board.py"),
                            "--sbit", str(bit.resolve()), "--out", str(args.out / "jtag"),
                            "--pds", str(args.pds.resolve())], check=True)
            report["programmed_in_this_run"] = True
            save(args.out / "result.json", report)
        import serial
        with serial.Serial(args.port, 115200, timeout=120, write_timeout=10) as port:
            # Command-mode only. Never issue writes into the old autonomous loop.
            initial = transact(port, 8)
            if len(initial) != 4 * (8 + len(model["ops"])):
                raise ValueError("Unexpected timing profile payload")
            if args.upload_model:
                print("MODEL_UPLOAD_START", flush=True)
                write_image(port, model["blob_base"], blob)
            transact(port, 5)
            report["model_crc_verified"] = True
            if transact(port, 9, 63) != struct.pack("<I", 63):
                raise ValueError("Runtime flags mismatch")
            if args.camera_mode is not None:
                if transact(port, 10, args.camera_mode) != struct.pack("<I", args.camera_mode):
                    raise ValueError("Camera mode not accepted")
            if args.verify_input:
                raw = transact(port, 11)
                if len(raw) != 16:
                    raise ValueError("Invalid input comparison reply")
                old_crc, new_crc, old_cycles, new_cycles = struct.unpack("<4I", raw)
                report["input_equivalence"] = dict(legacy_crc32=f"0x{old_crc:08x}",
                    stream_crc32=f"0x{new_crc:08x}", passed=old_crc == new_crc,
                    legacy_preprocessing_seconds=old_cycles / acceptance['cpu_hz'],
                    stream_preprocessing_seconds=new_cycles / acceptance['cpu_hz'],
                    scope="same immutable snapshot, all 819200 bytes including letterbox and channel padding")
                if old_crc != new_crc:
                    raise ValueError("Old/new input mismatch")
                save(args.out / "result.json", report)
                print("CAMERA_INPUT_EQUIVALENCE_PASS", report["input_equivalence"], flush=True)
            for index in range(args.frames + 1):
                started = time.monotonic()
                raw = transact(port, 6)
                elapsed = time.monotonic() - started
                detections = parse_detections(raw,model.get('classes'))
                raw_profile = transact(port, 8)
                profile = parse_profile(raw_profile, model)
                if profile["cpu_hz"] != acceptance['cpu_hz'] or profile["flags"] != 63:
                    raise ValueError("Unexpected full-application clock or flags")
                if any(op["cycles"] <= 0 for op in profile["operators"]):
                    raise ValueError("Missing operator cycles")
                device = sum(profile["stages"].values())
                if abs(device - elapsed) > max(.2, .05 * elapsed):
                    raise ValueError("Device/host timing mismatch")
                if sum(op["seconds"] for op in profile["operators"]) > profile["stages"]["forward"]:
                    raise ValueError("Operator times exceed forward stage")
                (args.out / f"frame{index:02}.bin").write_bytes(raw)
                (args.out / f"frame{index:02}_profile.bin").write_bytes(raw_profile)
                report["runs"].append(dict(warmup=index == 0, wall_seconds=elapsed,
                    device_seconds=device, detections=detections, profile=profile))
                save(args.out / "result.json", report)
                print(f"FRAME {index} warmup={index == 0} seconds={elapsed:.6f} "
                      f"stages={profile['stages']}", flush=True)
            report["summary"] = summarize(report["runs"])
            report["complete"] = True
            if not args.leave_controlled:
                transact(port, 7)
                report["autonomous_resumed"] = True
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        report["completed_utc"] = datetime.now(timezone.utc).isoformat()
        save(args.out / "result.json", report)
    print(json.dumps(report["summary"], ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
