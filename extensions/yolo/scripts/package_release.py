"""Package and verify the latest board-programmable camera/YOLO candidate.

This script never programs hardware.  It selects only a routed PDS build whose
timing report says "All Constraints Met", then copies the matching firmware,
model, memory map, constraints and bring-up instructions into one directory.
The package is intentionally marked board_verified=false until a real board
measurement is recorded.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "release" / (
    "board_candidate_" + datetime.now().strftime("%Y%m%d_%H%M%S")
)
PACKED = ROOT / "gen" / "integration" / "packed"
FIRMWARE = ROOT / "gen" / "integration" / "vexii_firmware"
PDS_ROOT = ROOT / "pds"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_cpu_clock(timing_text: str, cpu_hz: int) -> dict:
    clock_name = {
        27000000: "sys_clk",
        37125000: "ai_clk",
        81000000: "ai_clk",
        93461538: "ai_clk",
        120461538: "ai_clk",
    }[cpu_hz]
    summary = timing_text.split(" Clock Groups:", 1)[0]
    row = re.search(
        rf"^\s*{re.escape(clock_name)}\s+([0-9.]+)\s+\{{[^}}]+\}}\s+"
        r"(?:Declared|Generated\s+\([^)]+\))\s+(\d+)\s+(\d+)\s+\{",
        summary, re.M)
    if row is None:
        raise RuntimeError(f"CPU clock missing from routed STA: {clock_name}")
    period, loads = float(row[1]), int(row[2])
    # The vendor baseline constrains the 27 MHz oscillator to 37.000 ns.
    # Allow that conservative rounding, not a slower or unloaded fake clock.
    if abs(period - 1e9 / cpu_hz) > (1e9 / cpu_hz) * .01 or loads < 1000:
        raise RuntimeError(f"CPU clock is not correctly constrained: {period=}, {loads=}")
    return dict(name=clock_name, period_ns=period, clock_loads=loads)


def find_build(explicit: Path | None) -> Path:
    if explicit is not None:
        folder = explicit.resolve()
        if not (folder / "acceptance.json").is_file():
            raise FileNotFoundError(f"missing acceptance.json: {folder}")
        return folder
    candidates = []
    for folder in PDS_ROOT.glob("vexii_camera_*"):
        acceptance = folder / "acceptance.json"
        bitstreams = list(folder.glob("generate_bitstream/*.sbit"))
        timing = folder / "report_timing" / "yolo_camera_top.rtr"
        if not acceptance.is_file() or len(bitstreams) != 1 or not timing.is_file():
            continue
        try:
            metadata = load_json(acceptance)
        except json.JSONDecodeError:
            continue
        timing_text = timing.read_text(encoding="utf-8", errors="replace")
        if (
            metadata.get("routed") is True
            and metadata.get("timing_pass") is True
            and "Design Summary : All Constraints Met." in timing_text
        ):
            candidates.append(folder)
    if not candidates:
        raise RuntimeError("no routed/timing-accepted vexii_camera build found")
    return max(candidates, key=lambda p: p.stat().st_mtime)


def required_sources(build: Path) -> dict[str, Path]:
    source_dir = build / "sources"
    firmware = source_dir if (source_dir / "program.hex").is_file() else FIRMWARE
    mapping = {
        "bitstream.sbit": next(build.glob("generate_bitstream/*.sbit")),
        "firmware.bin": firmware / "firmware.bin",
        "firmware.hex": firmware / "program.hex",
        "firmware.elf": firmware / "firmware.elf",
        "model.bin": PACKED / "model.bin",
        "memory_map.json": PACKED / "memory_map.json",
        "camera.fdc": source_dir / "camera.fdc",
        "firmware_manifest.json": firmware / "manifest.json",
        "board_loader.py": ROOT / "scripts" / "board_loader.py",
        "loader_requirements.txt": ROOT / "scripts" / "loader_requirements.txt",
        "build_acceptance.json": build / "acceptance.json",
        "source_manifest.json": build / "manifest.json",
        "timing_report.rtr": build / "report_timing" / "yolo_camera_top.rtr",
        "timing_summary.txt": (
            build / "place_route" / "yolo_camera_top_timing_summary_after_hold_fix.txt"
        ),
    }
    missing = [f"{name}: {path}" for name, path in mapping.items() if not path.is_file()]
    if missing:
        raise FileNotFoundError("release inputs missing:\n" + "\n".join(missing))
    return mapping


def validate_inputs(build: Path, paths: dict[str, Path]) -> dict:
    acceptance = load_json(paths["build_acceptance.json"])
    firmware_manifest = load_json(paths["firmware_manifest.json"])
    build_manifest = load_json(paths["source_manifest.json"])
    memory_map = load_json(paths["memory_map.json"])
    bitstream = paths["bitstream.sbit"].resolve()
    timing = build / "report_timing" / "yolo_camera_top.rtr"
    timing_text = timing.read_text(encoding="utf-8", errors="replace")
    if acceptance.get("routed") is not True or acceptance.get("timing_pass") is not True:
        raise RuntimeError("selected build is not accepted for programming")
    if "Design Summary : All Constraints Met." not in timing_text:
        raise RuntimeError("selected build timing report is not accepted")
    if firmware_manifest.get("platform") != "vexii":
        raise RuntimeError("release firmware is not the Vexii image")
    cpu_hz = firmware_manifest.get("cpu_hz")
    if cpu_hz not in (27000000, 37125000, 81000000, 93461538, 120461538):
        raise RuntimeError("unsupported release CPU clock")
    if build_manifest.get("cpu_clock_hz") != cpu_hz:
        raise RuntimeError("PDS clock and firmware timing disagree")
    cpu_clock = validate_cpu_clock(timing_text, cpu_hz)
    if firmware_manifest.get("sim_preload") is True:
        raise RuntimeError("simulation-preloaded firmware cannot be released for hardware")
    if build_manifest.get("top") != "yolo_camera_top":
        raise RuntimeError("PDS snapshot is not the camera/YOLO board top")
    if build_manifest.get("board_verified") is not False:
        raise RuntimeError("PDS snapshot has inconsistent board-verification metadata")
    if build_manifest.get("firmware") != firmware_manifest:
        raise RuntimeError("PDS snapshot firmware metadata differs from current firmware")
    if Path(acceptance.get("bitstream", "")).resolve() != bitstream:
        raise RuntimeError("acceptance.json points at a different bitstream")
    if (build / "sources" / "firmware.bin").read_bytes() != paths["firmware.bin"].read_bytes():
        raise RuntimeError("PDS snapshot firmware binary differs from the selected firmware")
    snapshot_manifest = load_json(build / "sources" / "manifest.json")
    if snapshot_manifest != firmware_manifest:
        raise RuntimeError("PDS source snapshot does not carry the selected firmware manifest")
    for source in build_manifest.get("sources", []):
        snapshot = Path(source["snapshot"])
        if not snapshot.is_file() or sha256(snapshot) != source["sha256"]:
            raise RuntimeError(f"PDS source snapshot hash mismatch: {snapshot}")
    if firmware_manifest.get("model_sha256") != memory_map.get("blob_sha256"):
        raise RuntimeError("firmware/model metadata mismatch")
    if sha256(paths["firmware.hex"]) != firmware_manifest.get("program_sha256"):
        raise RuntimeError("firmware.hex does not match firmware manifest")
    if sha256(paths["model.bin"]) != memory_map.get("blob_sha256"):
        raise RuntimeError("model.bin does not match memory_map.json")
    if sha256(paths["bitstream.sbit"]) != acceptance.get("bitstream_sha256"):
        raise RuntimeError("bitstream does not match acceptance.json")
    return {
        "acceptance": acceptance,
        "firmware": firmware_manifest,
        "memory_map": memory_map,
        "timing_report": str(timing),
        "cpu_clock": cpu_clock,
    }


def board_instructions(manifest: dict) -> str:
    bitstream = "bitstream.sbit"
    return f"""# YOLO Camera Board Bring-up

This package is a **programming candidate**, not a board acceptance certificate.
`board_verified` remains `false` until the real MES2L676-100HP board is tested.

## Files

- `{bitstream}`: PDS bitstream for `PG2L100H-6IFBG676`
- `firmware.bin` / `firmware.hex`: matching {manifest["cpu_hz"]} Hz RV32IM firmware
- `model.bin`: matching six-class YOLO deployment blob
- `memory_map.json`: DDR addresses and CRC
- `camera.fdc`: exact constraints snapshot used by PDS

## Required order

1. Run the vendor DDR BIST and confirm `ddr_init_done`.
2. Program `{bitstream}` with the vendor JTAG tool.
3. Open the board UART at `115200 8N1` (the current firmware uses the Vexii
   UART protocol; this is not a Linux image).
4. From this package folder, load the model and verify its CRC:

   ```powershell
   & python `
     -m pip install -r loader_requirements.txt
   & python `
     board_loader.py --package-dir . --port COM13
   ```

   The model must be transferred after every FPGA/DDR reset because it is not
   stored in nonvolatile memory.
5. Test a known static image before enabling the camera:

   ```powershell
   # Run from this package folder. No source repository or PyTorch is required.
   & python `
     board_loader.py --package-dir . --port COM13 --skip-model `
     --image path/to/image.jpg
   ```
6. Test one camera snapshot:

   ```powershell
   & python `
     board_loader.py --package-dir . --port COM13 --skip-model --camera --frames 1
   ```

7. Record UART result, DDR status, camera init status and HDMI output. Only
   after these four observations pass may `board_verified` be changed.

The loader prints category, confidence and bounding box as JSON for both image
and camera commands. An empty detections list is a valid no-object result.
Malformed replies, bad CRCs and invalid category IDs are errors, not results.
After an interrupted transfer or firmware error, reset/reconnect and reload;
do not blindly replay a command that may already have changed DDR contents.

## Known boundaries

- The current video timing is 1280x720@60, not 1920x1080@60.
- PDS reports all modeled timing constraints met, but external camera/HDMI
  input/output delays are not independently measured on the board.
- The exact monitor compatibility is not verified. A monitor requiring
  1920x1080@60 may reject this 1280x720@60 output.
- The model classes are biodegradable, cardboard, glass, metal, paper and
  plastic; there is no hazardous-waste class.
- Mechanical sorting is not part of this candidate.
"""


def write_hashes(out: Path):
    lines = []
    for path in sorted(p for p in out.iterdir() if p.is_file() and p.name != "SHA256SUMS.txt"):
        lines.append(f"{sha256(path)}  {path.name}")
    (out / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")


def package(out: Path, build: Path) -> Path:
    paths = required_sources(build)
    checked = validate_inputs(build, paths)
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise FileExistsError(f"refusing to overwrite nonempty release directory: {out}")
    for name, source in paths.items():
        shutil.copy2(source, out / name)
    manifest = {
        "package": "pangu100pro-vexii-yolo-camera",
        "build": str(build),
        "package_dir": str(out.relative_to(ROOT).as_posix())
        if out.is_relative_to(ROOT)
        else str(out),
        "top": "yolo_camera_top",
        "device": "PG2L100H-6IFBG676",
        "cpu_hz": checked["firmware"]["cpu_hz"],
        "board_verified": False,
        "routed": True,
        "timing_pass": True,
        "external_io_delays_verified": False,
        "display_tested": False,
        "video_mode": "1280x720@60",
        "classes": [
            "biodegradable",
            "cardboard",
            "glass",
            "metal",
            "paper",
            "plastic",
        ],
        "files": {},
        "resource_usage": checked["acceptance"]["resources"],
        "model": {
            "bytes": checked["memory_map"]["blob_length"],
            "sha256": checked["memory_map"]["blob_sha256"],
            "crc32": checked["memory_map"]["blob_crc32"],
        },
    }
    for path in sorted(p for p in out.iterdir() if p.is_file()):
        manifest["files"][path.name] = {
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
    (out / "release_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (out / "BOARD_TEST.md").write_text(board_instructions(manifest), encoding="utf-8")
    write_hashes(out)
    return out


def verify(out: Path) -> None:
    manifest = load_json(out / "release_manifest.json")
    if manifest.get("board_verified") is not False:
        raise RuntimeError("release manifest must keep board_verified=false")
    for name, info in manifest["files"].items():
        path = out / name
        if not path.is_file():
            raise FileNotFoundError(path)
        if path.stat().st_size != info["bytes"] or sha256(path) != info["sha256"]:
            raise RuntimeError(f"hash/size mismatch: {name}")
    hashes = {}
    for line in (out / "SHA256SUMS.txt").read_text(encoding="ascii").splitlines():
        digest, name = line.split("  ", 1)
        hashes[name] = digest
    actual = {
        path.name for path in out.iterdir()
        if path.is_file() and path.name != "SHA256SUMS.txt"
    }
    if set(hashes) != actual:
        raise RuntimeError("SHA256SUMS file list does not match package contents")
    for name, digest in hashes.items():
        if sha256(out / name) != digest:
            raise RuntimeError(f"SHA256SUMS mismatch: {name}")
    print(f"RELEASE_VERIFY_PASS files={len(manifest['files'])} board_verified=false")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.out.resolve())
        return
    build = find_build(args.build)
    out = package(args.out.resolve(), build)
    print(f"RELEASE_PACKAGE_CREATED {out}")


if __name__ == "__main__":
    main()
