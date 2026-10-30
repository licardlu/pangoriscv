#!/usr/bin/env python3
"""V1 复现核的仿真回归入口。

用法:
  python tools/core_replica/run_case.py smoke
  python tools/core_replica/run_case.py coremark --iterations 20 --chars 1100 --cycles 30000000

它做四件事, 顺序固定:
  1) 用固定参数编译固件 (同一个编译器、同一组选项, 不为了让分好看而改工作负载)
  2) objcopy -> 32 位小端字表 (firmware.hex)
  3) ModelSim 编译 RTL + testbench, 跑仿真, 串口文本落到 uart_rx.txt
  4) 判定: 必须同时满足"出现成功关键字" + "没有 TIMEOUT" + "无 UART 校验错"

判定口径来自计划 9.1: banner / LED / 单个 TEST_PASS 都不算成功。
失败返回非零退出码。
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _find_gcc():
    """工具链位置: 先找本目录下, 再找上一级 (本项目实际放在 zi_guang_tong_chuang/toolchains)。"""
    cands = [
        os.path.join(ROOT, "toolchains", "xpack-riscv-none-elf-gcc-15.2.0-1", "bin"),
        os.path.join(os.path.dirname(ROOT), "toolchains",
                     "xpack-riscv-none-elf-gcc-15.2.0-1", "bin"),
    ]
    for c in cands:
        if os.path.exists(os.path.join(c, "riscv-none-elf-gcc.exe")) or \
           os.path.exists(os.path.join(c, "riscv-none-elf-gcc")):
            return c
    return cands[0]


GCC = _find_gcc()
CORE_ARGS = [
    "-march=rv32imc_zicsr_zifencei", "-mabi=ilp32", "-O2",
    "-nostdlib", "-nostartfiles", "-ffreestanding", "-fno-builtin", "-fno-common",
]

# V1 = 已交付基线 (32 位取指块, 单发射)。源码冻结在 wip/v1_core/,
# 与 build/replica_pds/run-002/sources 逐字节一致, 用来保证"新核跑挂了还能回到
# 有板测成绩的那一份"。rtl/core 与 rtl/soc 现在是 V2 主线。
V1_SRC = [
    "wip/v1_core/alu.v",
    "wip/v1_core/shifter.v",
    "wip/v1_core/branch_unit.v",
    "wip/v1_core/multiplier.v",
    "wip/v1_core/divider.v",
    "wip/v1_core/operand_select.v",
    "wip/v1_core/integer_regfile.v",
    "wip/v1_core/load_store_unit.v",
    "wip/v1_core/csr_file.v",
    "wip/v1_core/rvc_decoder.v",
    "wip/v1_core/decoder.v",
    "wip/v1_core/instruction_aligner.v",
    "wip/v1_core/pango_cpu.v",
    "wip/v1_core/ram_tdp.v",
    "wip/v1_core/uart_tx.v",
    "wip/v1_core/pango_soc.v",
    "tb/core_replica/tb_soc.v",
]

# V2 = 主线 (64 位取指块 + 分发缓冲 + 双发射)
V2_SRC = [
    "rtl/core/execute/alu.v",
    "rtl/core/execute/shifter.v",
    "rtl/core/execute/branch_unit.v",
    "rtl/core/execute/multiplier.v",
    "rtl/core/execute/divider.v",
    "rtl/core/execute/operand_select.v",
    "rtl/core/regfile/integer_regfile.v",
    "rtl/core/lsu/load_store_unit.v",
    "rtl/core/control/csr_file.v",
    "rtl/core/decode/rvc_decoder.v",
    "rtl/core/decode/decoder.v",
    "rtl/core/decode/dispatch_buffer.v",
    "rtl/core/frontend/instruction_aligner.v",
    "rtl/core/frontend/branch_predictor.v",
    "rtl/core/pango_cpu.v",
    "rtl/soc/ram_tdp.v",
    "rtl/perips/uart_tx.v",
    "rtl/soc/pango_soc.v",
    "tb/core_replica/tb_soc_v2.v",
]

# include 目录: V1 的头文件在 wip/v1_core, V2 在 rtl/core
V1_INC = os.path.join(ROOT, "wip", "v1_core")


def rtl_list(variant):
    return V1_SRC if variant == "v1" else V2_SRC


def hex_tool(variant):
    return ("tools/core_replica/elf2hex64.py" if variant == "v2"
            else "tools/core_replica/elf2hex32.py")


def run(cmd, cwd=None, env=None, timeout=None):
    print("+", " ".join(cmd))
    # ★ 必须 errors="replace": ModelSim 的 stdout 里会混进非 UTF-8 字节
    #   (中文 Windows 代码页), 用默认严格解码会抛 UnicodeDecodeError,
    #   结果是日志变成空串、所有 grep 判据全失效 (表现为 uart_errors=-1)。
    return subprocess.run(cmd, cwd=cwd, env=env, timeout=timeout,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          encoding="utf-8", errors="replace")


def build_firmware(case, iterations, outdir, variant="v1", cpu_hz=None):
    os.makedirs(outdir, exist_ok=True)
    env = dict(os.environ)
    env["PATH"] = GCC + os.pathsep + env["PATH"]

    if case == "smoke":
        sources = ["tb/core_replica/programs/crt.S", "tb/core_replica/programs/smoke.c"]
        linker = "tb/core_replica/programs/smoke.ld"
        extra = []
    elif case == "pair":
        sources = ["tb/core_replica/programs/crt.S", "tb/core_replica/programs/pair.c"]
        linker = "tb/core_replica/programs/smoke.ld"
        extra = []
    else:
        sources = ["firmware/port/start.S",
                   "firmware/coremark/core_list_join.c",
                   "firmware/coremark/core_main.c",
                   "firmware/coremark/core_matrix.c",
                   "firmware/coremark/core_state.c",
                   "firmware/coremark/core_util.c",
                   "firmware/port/core_portme.c",
                   "firmware/port/ee_printf.c"]
        linker = "firmware/port/link.ld"
        extra = ["-I", "firmware/coremark", "-I", "firmware/port",
                 "-DITERATIONS=%d" % iterations,
                 "-DPERFORMANCE_RUN=1", "-DTOTAL_DATA_SIZE=2000",
                 "-funroll-loops", "-finline-functions", "-falign-functions=8"]

    if cpu_hz:
        extra = extra + ["-DCPU_HZ=%du" % cpu_hz]

    elf = os.path.join(outdir, case + ".elf")
    cmd = [os.path.join(GCC, "riscv-none-elf-gcc")] + CORE_ARGS + extra + \
          ["-T", linker] + sources + ["-lgcc", "-o", elf]
    r = run(cmd, cwd=ROOT, env=env)
    if r.returncode != 0:
        print(r.stdout)
        return None
    if "warning" in r.stdout and "RWX" not in r.stdout:
        print(r.stdout)

    binf = os.path.join(outdir, case + ".bin")
    r = run([os.path.join(GCC, "riscv-none-elf-objcopy"), "-O", "binary", elf, binf],
            cwd=ROOT, env=env)
    if r.returncode != 0:
        print(r.stdout)
        return None

    hexf = os.path.join(outdir, "firmware.hex")
    r = run([sys.executable, hex_tool(variant), binf, hexf], cwd=ROOT)
    if r.returncode != 0:
        print(r.stdout)
        return None
    return hexf


def simulate(hexf, simdir, chars, cycles, variant="v1"):
    os.makedirs(simdir, exist_ok=True)
    shutil.copy(hexf, os.path.join(simdir, "firmware.hex"))

    env = dict(os.environ)
    incdir = "+incdir+" + (V1_INC if variant == "v1"
                            else os.path.join(ROOT, "rtl", "core"))
    r = run(["vlog", "-quiet", incdir, "-work", "work"] +
            [os.path.join(ROOT, f) for f in rtl_list(variant)], cwd=simdir, env=env)
    if r.returncode != 0:
        print(r.stdout)
        return None

    tbmod = "work.tb_soc"   # 两个 TB 的模块名都叫 tb_soc, 只是文件不同
    r = run(["vsim", "-c", "-quiet", tbmod, "-do", "run -all; quit -f",
             "+maxchars=%d" % chars, "+maxcycles=%d" % cycles],
            cwd=simdir, env=env, timeout=3600)
    log = r.stdout or ""

    rx = os.path.join(simdir, "uart_rx.txt")
    text = open(rx, encoding="utf-8", errors="replace").read() if os.path.exists(rx) else ""
    return log, text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("case", choices=["smoke", "coremark", "pair"])
    ap.add_argument("--iterations", type=int, default=20)
    ap.add_argument("--chars", type=int, default=0)
    ap.add_argument("--cycles", type=int, default=6000000)
    ap.add_argument("--variant", choices=["v1", "v2"], default="v1")
    ap.add_argument("--cpu-hz", type=int, default=None,
                    help="覆盖固件里的 CPU_HZ (读诊断档时用, 不影响 CoreMark/MHz)")
    a = ap.parse_args()

    if a.chars == 0:
        a.chars = 120 if a.case == "smoke" else (600 if a.case == "pair" else 1100)

    outdir = os.path.join(ROOT, "build", "replica_" + a.case +
                          ("" if a.variant == "v1" else "_v2"))
    hexf = build_firmware(a.case, a.iterations, outdir, a.variant, a.cpu_hz)
    if not hexf:
        print("RESULT: BUILD_FAIL")
        return 2

    simdir = os.path.join(outdir, "sim")
    res = simulate(hexf, simdir, a.chars, a.cycles, a.variant)
    if not res:
        print("RESULT: SIM_BUILD_FAIL")
        return 3
    log, text = res

    print("\n------------------------------------------------------------")
    print(text)
    print("------------------------------------------------------------")

    timeout = "TIMEOUT" in log
    uart_err = re.search(r"uart_errors=(\d+)", log)
    nerr = int(uart_err.group(1)) if uart_err else -1

    ok = True
    if timeout:
        print("FAIL: simulation timed out"); ok = False
    if nerr != 0:
        print("FAIL: uart framing errors = %d" % nerr); ok = False

    if a.case == "smoke":
        if "SMOKE PASS" not in text:
            print("FAIL: SMOKE PASS not found"); ok = False
    elif a.case == "pair":
        if "PAIR PASS" not in text:
            print("FAIL: PAIR PASS not found"); ok = False
    else:
        # 计划 9.2 的判据: 四项官方 CRC 必须等于该工作负载的期望值, 总 ticks 必须存在。
        # "Correct operation validated" 只有运行 >=10 s 才会打印; HAS_FLOAT=0 时仿真
        # 短跑必然打印 "Must execute for at least 10 secs", 这只能说明"不是正式成绩",
        # 不能当成"算法算错"。所以这里按 CRC 判功能, 按 ticks 报分数并标注证据类型。
        want_crc = {"seedcrc": "0xe9f5", "crclist": "0xe714",
                    "crcmatrix": "0x1fd7", "crcstate": "0x8e3a"}
        for key, want in want_crc.items():
            m = re.search(key + r"\s*:\s*(0x[0-9a-fA-F]+)", text)
            if not m:
                print("FAIL: missing %s" % key); ok = False
            elif m.group(1).lower() != want:
                print("FAIL: %s = %s, want %s" % (key, m.group(1), want)); ok = False
        if "TICKS_LO" not in text:
            print("FAIL: TICKS_LO not found"); ok = False
        else:
            hi = re.search(r"TICKS_HI=(\d+)", text)
            lo = re.search(r"TICKS_LO=(\d+)", text)
            if hi and lo:
                ticks = int(hi.group(1)) * (1 << 32) + int(lo.group(1))
                iters = a.iterations
                if ticks > 0:
                    print("TOTAL_TICKS=%d  TICKS_PER_ITER=%.2f  CoreMark/MHz=%.4f"
                          % (ticks, ticks / iters, iters * 1e6 / ticks))
                if "Correct operation validated" in text:
                    print("EVIDENCE: 正式成绩 (运行 >= 10 s, 官方验证文本齐全)")
                else:
                    print("EVIDENCE: 功能证据 (短跑, 不足 10 s; 不作为正式成绩)")

    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
