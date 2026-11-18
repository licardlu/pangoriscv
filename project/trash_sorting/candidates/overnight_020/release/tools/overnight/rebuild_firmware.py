"""Compile and identify candidate firmware at the selected CPU clock before synthesis."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
ROOT = PROJECT.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--gcc-prefix", required=True)
    parser.add_argument("--install", action="store_true")
    parser.add_argument('--benchmark',action='store_true',help='80KiB application with official CoreMark and on-board page')
    parser.add_argument('--benchmark-reference',action='store_true',help='Stored CPU014 reference page; no CoreMark workload linked')
    parser.add_argument('--benchmark-demo',action='store_true',help='18-24 second animation; simulated 5.12-5.28 score, no CoreMark workload')
    parser.add_argument('--media',action='store_true',help='Read-only TF/JPEG player with three-page KEY0 navigation')
    parser.add_argument('--lto',action='store_true',help='Enable GCC link-time code optimization')
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
    if sum((args.benchmark,args.benchmark_reference,args.benchmark_demo))>1:parser.error('Choose live benchmark, stored reference, or simulated demo')
    page_enabled=args.benchmark or args.benchmark_reference or args.benchmark_demo
    if args.media and not page_enabled:parser.error('--media requires the 80KiB page application')
    source_dir = args.source_dir.resolve()
    demo_source='SIMULATED' in (source_dir/'yolo/software/benchmark_ui.c').read_text(encoding='utf8')
    if demo_source!=args.benchmark_demo:parser.error('Simulated UI source requires --benchmark-demo; mode and source must agree')
    if args.benchmark and 'benchmark_load_reference' in (source_dir/'yolo/software/benchmark_ui.c').read_text(encoding='utf8'):
        parser.error('This candidate provides the stored reference UI; use --benchmark-reference')
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
    standalone_boot=args.media and (sw/'model_boot.c').is_file()
    command = [args.gcc_prefix + "-gcc.exe", "-march="+('rv32im_zicsr_zifencei' if page_enabled else 'rv32im'), "-mabi=ilp32", "-Os",
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
    if args.benchmark:
        position=command.index('-lm')
        command[position:position]=['-I'+str(sw/'coremark'),
            *(str(sw/name) for name in ('benchmark.c','benchmark_ui.c','coremark_entry.c')),
            *(str(sw/'coremark'/name) for name in
              ('core_list_join.c','core_matrix.c','core_state.c','core_util.c'))]
    if args.benchmark_reference or args.benchmark_demo:
        command.insert(1,'-DBENCHMARK_REFERENCE_MODE')
        if args.benchmark_demo:command.insert(1,'-DBENCHMARK_DEMO_MODE')
        position=command.index('-lm')
        command[position:position]=[str(sw/'benchmark_ui.c')]
        if args.benchmark_reference:command.insert(position,str(sw/'benchmark_reference.c'))
    if args.linear_o2:
        command.insert(1, "-DYOLO_LINEAR_O2")
    if args.media:
        command.insert(1,'-DMEDIA_ENABLE')
        position=command.index('-lm')
        command[position:position]=[str(sw/name) for name in
            ('media_board.c','media_player.c','media_sdmmc.c','media_fat32.c','media_pmj.c')]
        if standalone_boot:command.insert(command.index('-lm'),str(sw/'model_boot.c'))
    if args.lto:command.insert(1,'-flto')
    if args.packed_add:
        command.insert(1, '-DYOLO_PACKED_ADD')
    with (out / "build.log").open("w", encoding="utf8") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, env=env)
        subprocess.run([args.gcc_prefix + "-size.exe", str(out / "firmware.elf")],
                       stdout=log, stderr=subprocess.STDOUT, check=True, env=env)
    subprocess.run([args.gcc_prefix + "-objcopy.exe", "-O", "binary",
                    str(out / "firmware.elf"), str(out / "firmware.bin")], check=True, env=env)
    binary = (out / "firmware.bin").read_bytes()
    ram_bytes=81920 if page_enabled else 65536
    if not binary or len(binary) > ram_bytes:
        raise ValueError("Invalid program image size")
    padded = binary.ljust(ram_bytes, b"\0")
    for lane in range(8):
        (out / f"firmware_lane{lane}.bin").write_text(
            "".join(f"{byte:08b}\n" for byte in padded[lane::8]), encoding="ascii")
    manifest = dict(status="SOURCE_AND_FIRMWARE_CANDIDATE_ONLY", raw_model_classes=args.classes,
                    ram_bytes=ram_bytes,benchmark_page=page_enabled,benchmark_mode='simulated_demo' if args.benchmark_demo else 'reference' if args.benchmark_reference else 'live' if args.benchmark else None,
                    benchmark_iterations=5000 if args.benchmark else None,
                    benchmark_reference_sha256=sha(sw/'benchmark_reference_record.json') if args.benchmark_reference else None,
                    benchmark_delay_seconds=15 if args.benchmark_reference else None,
                    benchmark_demo_seconds=[18,24] if args.benchmark_demo else None,
                    benchmark_demo_score_hundredths=[512,528] if args.benchmark_demo else None,
                    benchmark_is_real_measurement=False if args.benchmark_demo else None,
                    benchmark_text_words=880 if page_enabled else None,
                    benchmark_key='KEY0',benchmark_long_press_ms=2000 if args.benchmark_reference else None,
                    recognition_single_click=args.media, page_double_click_ms=350 if args.media else None,
                    effective_output_ids=list(range(4)) if args.classes in (4,5) else [0,2,3,4,5],
                    hand_locator_class=4 if args.classes==5 else None,
                    merge={} if args.classes in (4,5) else {"1":4}, single_label=args.classes in (4,5),
                    model_sha256=model['blob_sha256'],cpu_hz=args.cpu_hz,linear_o2=args.linear_o2,
                    packed_add=args.packed_add,media_enabled=args.media,lto=args.lto,
                    navigation_pages=['recognition','score','animation'] if args.media else ['recognition','score'],
                    standalone_model_boot=standalone_boot,boot_model_file='MODEL.BIN' if standalone_boot else None,
                    boot_model_ddr_crc_verified=standalone_boot,boot_diagnostic_command=20 if standalone_boot else None,
                    camera_stream_default=True, camera_input_compare_command=11,
                    camera_probe_command=12,
                    camera_target_policy=('hand_size_adaptive_contact_v2' if args.classes==5
                                          else 'largest_clipped_object_area'),
                    firmware_bytes=len(binary), firmware_sha256=sha(out / "firmware.bin"),
                    board_programmed=False, model_training_performed_by_this_build=False,
                    source_hashes={str(Path('project/trash_sorting/source/yolo/software') / path.relative_to(sw)): sha(path)
                        for path in sorted(sw.rglob('*'))
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
