"""Compile and identify the active 27 MHz firmware before FPGA synthesis."""
import argparse
import hashlib
import json
import os
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
    parser.add_argument("--linear-o2", action="store_true",
                        help='Opt-in O2 for CPU linear operators; board timing must verify benefit')
    parser.add_argument('--packed-add', action='store_true',
                        help='Opt-in exact int32 product tables for bounded Q24 ADD ratios')
    parser.add_argument("--classes", type=int, choices=(4,5,6), default=6)
    parser.add_argument("--source-dir", type=Path, default=PROJECT/'source',
                        help='Application source tree, including a portable release snapshot')
    parser.add_argument("--model-dir", type=Path,
                        help='Independent candidate packed model; does not replace the active model')
    parser.add_argument("--cpu-hz", type=int, choices=(27000000,54000000,74250000), default=27000000)
    args = parser.parse_args()
    source_dir = args.source_dir.resolve()
    model_dir = (args.model_dir or source_dir/'yolo/model').resolve()
    if args.install and model_dir != (source_dir/'yolo/model').resolve():
        parser.error('Stage the matching model before installing its firmware; independent candidates are compile-only')
    model_header=model_dir/'deployment_model.h'
    model_map=model_dir/'memory_map.json'
    model=json.loads(model_map.read_text(encoding='utf8'))
    if any(model['tensors'][i]['c']!=3*(5+args.classes) for i in model['outputs']):
        raise ValueError('Firmware class count and packed model differ')
    if sha(model_dir/'model.bin') != model['blob_sha256']:
        raise ValueError('Packed model identity mismatch')
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    # Windows GCC may resolve TEMP through an inaccessible short user path.
    # Keep subprocess scratch and DLL lookup local to this explicit build.
    temp = out/'temp'
    temp.mkdir()
    env = os.environ.copy()
    env['TMP'] = env['TEMP'] = str(temp)
    env['PATH'] = str(Path(args.gcc_prefix).resolve().parent)+os.pathsep+env.get('PATH','')
    sw = source_dir / "yolo/software"
    command = [args.gcc_prefix + "-gcc.exe", "-march=rv32im", "-mabi=ilp32", "-Os",
               "-ffunction-sections", "-fdata-sections", "-ffreestanding", "-Wall",
               "-Wextra", "-Werror", "-fstack-usage", "-nostartfiles",
               "-I" + str(sw), "-I" + str(model_dir),
               f"-DCPU_HZ={args.cpu_hz}", "-DVEXII_PLATFORM", "-DACC_BASE=0x10003100u",
               f"-DYOLO_CLASSES={args.classes}", f"-DYOLO_SINGLE_LABEL={int(args.classes in (4,5))}",
               "-T" + str(sw / "vexii_platform.ld"),
               "-Wl,--gc-sections,-Map=" + str(out / "firmware.map"),
               *(str(sw / name) for name in ("platform_start.S", "platform_main.c",
                 "yolo_forward.c", "yolo_runtime.c", "yolo_decode.c")),
               "-lm", "-lc", "-lgcc", "-o", str(out / "firmware.elf")]
    if args.linear_o2:
        command.insert(1, "-DYOLO_LINEAR_O2")
    if args.packed_add:
        command.insert(1, '-DYOLO_PACKED_ADD')
    with (out / "build.log").open("w", encoding="utf8") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, env=env)
        subprocess.run([args.gcc_prefix + "-size.exe", str(out / "firmware.elf")],
                       stdout=log, stderr=subprocess.STDOUT, check=True, env=env)
    subprocess.run([args.gcc_prefix + "-objcopy.exe", "-O", "binary",
                    str(out / "firmware.elf"), str(out / "firmware.bin")], check=True, env=env)
    binary = (out / "firmware.bin").read_bytes()
    if not binary or len(binary) > 65536:
        raise ValueError("Invalid program image size")
    padded = binary.ljust(65536, b"\0")
    for lane in range(8):
        (out / f"firmware_lane{lane}.bin").write_text(
            "".join(f"{byte:08b}\n" for byte in padded[lane::8]), encoding="ascii")
    manifest = dict(status="SOURCE_AND_FIRMWARE_CANDIDATE_ONLY", raw_model_classes=args.classes,
                    effective_output_ids=list(range(4)) if args.classes in (4,5) else [0,2,3,4,5],
                    hand_locator_class=4 if args.classes==5 else None,
                    merge={} if args.classes in (4,5) else {"1":4}, single_label=args.classes in (4,5),
                    model_sha256=model['blob_sha256'],cpu_hz=args.cpu_hz,linear_o2=args.linear_o2,
                    packed_add=args.packed_add,
                    camera_stream_default=True, camera_input_compare_command=11,
                    camera_probe_command=12,
                    camera_target_policy=('hand_size_adaptive_contact_v2' if args.classes==5
                                          else 'largest_clipped_object_area'),
                    firmware_bytes=len(binary), firmware_sha256=sha(out / "firmware.bin"),
                    board_programmed=False, model_training_performed_by_this_build=False,
                    source_hashes={str(Path('project/trash_sorting/source/yolo/software') / path.name): sha(path)
                        for path in sorted(sw.iterdir())
                        if path.suffix in (".c", ".h", ".S", ".ld", ".json")},
                    compiler_command=command)
    # Canonical frozen-source keys even when compiling an independent candidate.
    for path in (model_header,model_map):
        manifest['source_hashes']['project/trash_sorting/source/yolo/model/'+path.name]=sha(path)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf8")
    if args.install:
        destination = source_dir / "yolo/sources"
        for path in out.glob("*.bin"):
            shutil.copy2(path, destination / path.name)
        shutil.copy2(out / "manifest.json", destination / "firmware-source-manifest.json")
    print(json.dumps(dict(bytes=len(binary), sha256=manifest["firmware_sha256"],
                          installed=args.install)), flush=True)


if __name__ == "__main__":
    main()
