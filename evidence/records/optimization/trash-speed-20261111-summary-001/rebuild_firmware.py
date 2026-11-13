"""Compile and identify the active 27 MHz firmware before FPGA synthesis."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--gcc-prefix", required=True)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sw = PROJECT / "source/yolo/software"
    command = [args.gcc_prefix + "-gcc.exe", "-march=rv32im", "-mabi=ilp32", "-Os",
               "-ffunction-sections", "-fdata-sections", "-ffreestanding", "-Wall",
               "-Wextra", "-Werror", "-fstack-usage", "-nostartfiles",
               "-I" + str(sw), "-I" + str(PROJECT / "source/yolo/model"),
               "-DCPU_HZ=27000000", "-DVEXII_PLATFORM", "-DACC_BASE=0x10003100u",
               "-T" + str(sw / "vexii_platform.ld"),
               "-Wl,--gc-sections,-Map=" + str(out / "firmware.map"),
               *(str(sw / name) for name in ("platform_start.S", "platform_main.c",
                 "yolo_forward.c", "yolo_runtime.c", "yolo_decode.c")),
               "-lm", "-lc", "-lgcc", "-o", str(out / "firmware.elf")]
    with (out / "build.log").open("w", encoding="utf8") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([args.gcc_prefix + "-size.exe", str(out / "firmware.elf")],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run([args.gcc_prefix + "-objcopy.exe", "-O", "binary",
                    str(out / "firmware.elf"), str(out / "firmware.bin")], check=True)
    binary = (out / "firmware.bin").read_bytes()
    if not binary or len(binary) > 65536:
        raise ValueError("Invalid program image size")
    padded = binary.ljust(65536, b"\0")
    for lane in range(8):
        (out / f"firmware_lane{lane}.bin").write_text(
            "".join(f"{byte:08b}\n" for byte in padded[lane::8]), encoding="ascii")
    manifest = dict(status="SOURCE_AND_FIRMWARE_CANDIDATE_ONLY", raw_model_classes=6,
                    effective_output_ids=[0, 2, 3, 4, 5], merge={"1": 4},
                    camera_stream_default=True, camera_input_compare_command=11,
                    firmware_bytes=len(binary), firmware_sha256=sha(out / "firmware.bin"),
                    board_programmed=False, model_retrained=False,
                    source_hashes={str(path.relative_to(ROOT)): sha(path)
                        for path in sorted(sw.iterdir()) if path.suffix in (".c", ".h", ".S", ".ld")},
                    compiler_command=command)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
    if args.install:
        destination = PROJECT / "source/yolo/sources"
        for path in out.glob("*.bin"):
            shutil.copy2(path, destination / path.name)
        shutil.copy2(out / "manifest.json", destination / "firmware-source-manifest.json")
    print(json.dumps(dict(bytes=len(binary), sha256=manifest["firmware_sha256"],
                          installed=args.install)), flush=True)


if __name__ == "__main__":
    main()
