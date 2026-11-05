"""Build the separate RV32IM AI firmware without editing the CPU checkout."""
from pathlib import Path
import subprocess
import argparse
import hashlib
import json

import tool_paths

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--cpu-hz",type=int,default=27000000)
    parser.add_argument("--platform",choices=("legacy","vexii"),default="legacy")
    parser.add_argument("--gcc",type=Path,
                        help="RISC-V GCC bin 目录；默认读 RISCV_GCC_BIN")
    parser.add_argument("--sim-preload",action="store_true")
    parser.add_argument("--out",type=Path,
                        help="private build directory; default is the platform deployment directory")
    args=parser.parse_args()
    TOOLS=tool_paths.riscv_gcc_bin(args.gcc)
    if args.sim_preload and args.platform!="vexii":
        parser.error("--sim-preload is only valid for the Vexii simulation image")
    out=(args.out.resolve() if args.out else ROOT/(
        "gen/integration/vexii_firmware" if args.platform=="vexii"
        else "gen/integration/firmware"))
    out.mkdir(parents=True,exist_ok=True)
    prefix=TOOLS/"riscv-none-elf-"
    command=[str(prefix)+"gcc.exe","-march=rv32im","-mabi=ilp32","-Os",
             "-ffunction-sections","-fdata-sections","-ffreestanding",
             "-Wall","-Wextra","-Werror","-fstack-usage","-nostartfiles",
             "-I"+str(ROOT/"sw"),"-I"+str(ROOT/"gen/integration/packed"),
             "-DCPU_HZ="+str(args.cpu_hz),
             *(["-DVEXII_SIM_PRELOAD"] if args.sim_preload else []),
             *(["-DVEXII_PLATFORM","-DACC_BASE=0x10003100u"] if args.platform=="vexii" else []),
             "-T"+str(ROOT/"sw"/("vexii_platform.ld" if args.platform=="vexii" else "platform.ld")),
             "-Wl,--gc-sections,-Map="+str(out/"firmware.map"),
             *[str(ROOT/"sw"/p) for p in ("platform_start.S","platform_main.c",
                                        "yolo_forward.c","yolo_runtime.c","yolo_decode.c")],
             "-lm","-lc","-lgcc","-o",str(out/"firmware.elf")]
    subprocess.run(command,cwd=out,check=True)
    subprocess.run([str(prefix)+"size.exe",str(out/"firmware.elf")],check=True)
    subprocess.run([str(prefix)+"objcopy.exe","-O","binary",str(out/"firmware.elf"),
                    str(out/"firmware.bin")],check=True)
    binary=(out/"firmware.bin").read_bytes()
    limit=65536 if args.platform=="vexii" else 32768
    if len(binary)>limit:
        raise RuntimeError("Firmware exceeds target memory")
    binary+=bytes((-len(binary))%4)
    (out/"program.hex").write_text("".join(f"{int.from_bytes(binary[i:i+4],'little'):08x}\n"
                                         for i in range(0,len(binary),4)),encoding="ascii")
    (out/"manifest.json").write_text(json.dumps(dict(
        cpu_hz=args.cpu_hz,platform=args.platform,isa="rv32im",abi="ilp32",rom_bytes=len(binary),
        program_sha256=hashlib.sha256((out/"program.hex").read_bytes()).hexdigest(),
        model_sha256=json.loads((ROOT/"gen/integration/packed/memory_map.json").read_text())[
            "blob_sha256"],sim_preload=args.sim_preload,board_verified=False),
        indent=2),encoding="utf-8")
    # This is the statically visible application stack, not a proof about
    # libm/libgcc call chains. Keep room for those on the 16 KiB RAM target.
    usages=[]
    for file in out.glob("*.su"):
        for line in file.read_text().splitlines():
            parts=line.split("\t")
            if len(parts)>=3 and parts[1].isdigit():
                usages.append((int(parts[1]),parts[0].split(":")[-1]))
    if usages:
        print("Largest application stack frames:",sorted(usages,reverse=True)[:3])
    print(f"FIRMWARE_BUILD_PASS image={len(binary)}/{limit}; stack still needs target verification")


if __name__=="__main__":
    main()
