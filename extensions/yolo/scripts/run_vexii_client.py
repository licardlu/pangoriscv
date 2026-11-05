"""Check the CPU-to-native-DDR integration with independent clock domains."""
import argparse
from pathlib import Path
import subprocess
from generate_vexii_soc import ROOT, CPU, OUT
from generate_vexii_camera import generate
import tool_paths

RUN = ROOT / "sim/offline_checks/vexii_client"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modelsim", type=Path,
                        help="ModelSim win64 目录；默认读 MODELSIM_BIN")
    parser.add_argument("--gcc", type=Path,
                        help="RISC-V GCC bin 目录；默认读 RISCV_GCC_BIN")
    args = parser.parse_args()
    TOOLS = tool_paths.modelsim_bin(args.modelsim)
    GCC = tool_paths.riscv_gcc_bin(args.gcc)
    camera = generate()
    RUN.mkdir(parents=True, exist_ok=True)
    prefix = str(GCC / "riscv-none-elf-")
    subprocess.run([prefix + "gcc.exe", "-march=rv32im", "-mabi=ilp32",
                    "-nostdlib", "-Ttext=0x80000000", "-Wl,-e,_start",
                    str(ROOT / "sw/vexii_acc_smoke.S"), "-o", str(RUN / "smoke.elf")],
                   check=True)
    subprocess.run([prefix + "objcopy.exe", "-O", "binary",
                    str(RUN / "smoke.elf"), str(RUN / "smoke.bin")], check=True)
    data = (RUN / "smoke.bin").read_bytes().ljust(65536, b"\0")
    for lane in range(8):
        (RUN / f"MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin").write_text(
            "".join(f"{b:08b}\n" for b in data[lane::8]), encoding="ascii")
    sources = [CPU / line for line in (CPU / "sources.f").read_text().splitlines()
               if line and "MicroSoc.v" not in line and "rtl/board/" not in line]
    sources = [OUT / "TilelinkUartCtrl.v" if p.name == "TilelinkUartCtrl.v" else p
               for p in sources]
    commands = [
        [TOOLS / "vlib.exe", "work"],
        [TOOLS / "vlog.exe", "-sv", f"+incdir+{CPU/'rtl/core'}",
         OUT / "vexii_ai_soc.v", camera / "yolo_ai_client.v",
         ROOT / "tb/tb_vexii_client.v",
         *[ROOT / "rtl" / name for name in (
             "tlul_to_axil.v", "conv_engine_axil.v", "conv_band_rt.v", "requant_q15.v",
             "mac_array.v", "ddr_axi_bridge.v", "bridge_to_cdc.v", "axi_cdc.v")],
         *sources],
        [TOOLS / "vsim.exe", "-c", "-quiet", "tb_vexii_client", "-do",
         "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"],
    ]
    for i, command in enumerate(commands):
        result = subprocess.run([str(x) for x in command], cwd=RUN,
                                capture_output=True, text=True, errors="replace",
                                timeout=300)
        text = result.stdout + result.stderr
        (RUN / f"{i}.log").write_text(text, encoding="utf-8")
        if result.returncode or "** Error" in text or "** Fatal" in text:
            raise RuntimeError(text[-6000:])
    if "VEXII_CLIENT_PASS" not in text:
        raise RuntimeError(text[-6000:])
    print(next(line for line in text.splitlines() if "VEXII_CLIENT_PASS" in line))


if __name__ == "__main__":
    main()
