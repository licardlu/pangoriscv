#!/usr/bin/env python3
"""Assemble tests/isa_e2e/isa_e2e.S with the contest toolchain and run it on
the native AXI SoC testbench, one case per simulation, checking the
architectural register file after each case's halt store.

This is verification tooling: it does not modify RTL, software or constraints.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TOOLCHAIN = Path(
    r"E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin"
)
DEFAULT_MODELSIM = Path(r"E:\donwload\win64")

# case -> (expected register values, required UART output)
# The expectations are derived at run time from the independent Ref model that
# executes the same image, so no hand arithmetic is trusted. NAME is only a
# label for the report.
EXPECTED = None
NAME = {
    1: "ALU dependency chains and immediate forms",
    2: "load-use hazard and load extension",
    3: "M extension multiply/divide/remainder",
    4: "branch/jal/jalr and wrong-path suppression",
    5: "byte/halfword lanes and store->load",
    6: "CSR read/write rules",
    7: "mcycle/minstret counters",
    8: "ECALL trap and MRET return",
    9: "illegal instruction trap",
    10: "load access fault trap",
    11: "store access fault trap",
    12: "UART TXDATA transmit",
    13: "GPIO output mode",
    14: "timer one-shot and W1C",
    15: "machine timer interrupt and MRET",
    16: "WAW in one issue pair: the younger lane wins the register",
}


def _sign(x, bits=32):
    x &= (1 << bits) - 1
    return x - (1 << bits) if x >> (bits - 1) else x


def _sext(x, bits):
    x &= (1 << bits) - 1
    return _sign(x, bits) & 0xFFFFFFFF


def jal_x0(offset):
    """Encode `jal x0, offset` (J-type, rd=0). Used as a reset entry stub."""
    off = offset & 0x1FFFFF
    return ((off >> 20 & 1) << 31
            | (off >> 1 & 0x3FF) << 21
            | (off >> 11 & 1) << 20
            | (off >> 12 & 0xFF) << 12
            | 0x6F)


def _mapped(addr, size):
    """Address windows the native SoC answers: program RAM, data RAM, and the
    five 4 KiB peripheral slaves (timer, UART, GPIO, SPI, interrupt controller).
    Anything else is answered only by the AXI error slave, i.e. it faults."""
    if addr < 0x4000:
        return True
    if 0x10000000 <= addr < 0x10004000:
        return True
    return any(base <= addr < base + 0x1000
               for base in (0x20000000, 0x30000000, 0x40000000,
                            0x50000000, 0x60003000))


class Ref:
    """Independent RV32IM architectural reference, used to derive the expected
    register file for each case instead of hand arithmetic."""

    def __init__(self, words):
        self.m = [w & 0xFFFFFFFF for w in words]
        self.r = [0] * 32
        self.csr = {}
        self.mem = [0] * 16384
        self.halt = False
        # Registers the program actually defines; the rest are architecturally
        # undefined at reset and the RTL register file is intentionally not
        # reset, so undefined entries are not compared.
        self.written = set()
        # The real SoC wires program RAM with WRITE_ENABLE=0, so a store into
        # the program window faults instead of writing.
        self.prog_writable = False

    def w(self, i, v):
        if i:
            self.r[i] = v & 0xFFFFFFFF
            self.written.add(i)

    def run(self, pc, halt_addr=0x10000ff0, limit=200000, trace=False):
        steps = 0
        seen = {}
        dbg = trace
        while not self.halt and steps < limit:
            steps += 1
            seen[pc] = seen.get(pc, 0) + 1
            if seen[pc] > 4 and steps > 12:
                break   # the case's trailing `j 1b` self-loop
            i = self.m[(pc >> 2) & 0xFFF]
            if trace:
                print(f"  REF pc={pc:08x} inst={i:08x}")
            op = i & 0x7F
            rd = (i >> 7) & 31
            f3 = (i >> 12) & 7
            r1 = (i >> 15) & 31
            r2 = (i >> 20) & 31
            f7 = i >> 25
            a, b = self.r[r1], self.r[r2]
            nxt = (pc + 4) & 0xFFFFFFFF
            if op in (0x37, 0x17):
                self.w(rd, (i & 0xFFFFF000) if op == 0x37 else (pc + (i & 0xFFFFF000)))
            elif op == 0x67:
                self.w(rd, nxt)
                tgt = (a + _sext(i >> 20, 12)) & 0xFFFFFFFF
                if tgt & 3:
                    self.csr[0x341] = pc
                    self.csr[0x342] = 0
                    self.csr[0x343] = tgt
                    pc = self.csr.get(0x305, 0)
                    continue
                nxt = tgt & 0xFFFFFFFE
            elif op == 0x6F:
                imm = _sext((((i >> 31) & 1) << 20) | (((i >> 12) & 0xFF) << 12)
                            | (((i >> 20) & 1) << 11) | (((i >> 21) & 0x3FF) << 1), 21)
                self.w(rd, nxt)
                tgt = (pc + imm) & 0xFFFFFFFF
                if tgt & 3:
                    self.csr[0x341] = pc
                    self.csr[0x342] = 0
                    self.csr[0x343] = tgt
                    pc = self.csr.get(0x305, 0)
                    continue
                nxt = tgt
            elif op == 0x63:
                imm = _sext(((((i >> 31) & 1) << 12) | (((i >> 7) & 1) << 11)
                             | (((i >> 25) & 0x3F) << 5)
                             | (((i >> 8) & 0xF) << 1)), 13)
                sa, sb = _sign(a), _sign(b)
                take = {0: a == b, 1: a != b, 4: sa < sb, 5: sa >= sb,
                        6: a < b, 7: a >= b}.get(f3, False)
                if take:
                    nxt = (pc + imm) & 0xFFFFFFFF
            elif op == 0x03:
                addr = (a + _sext(i >> 20, 12)) & 0xFFFFFFFF
                misaligned = (f3 == 1 and (addr & 1)) or (f3 == 2 and (addr & 3))
                if misaligned:
                    self.csr[0x341] = pc
                    self.csr[0x342] = 4          # load address misaligned
                    self.csr[0x343] = addr
                    pc = self.csr.get(0x305, 0)
                    continue
                if not _mapped(addr, f3):
                    self.csr[0x341] = pc
                    self.csr[0x342] = 5          # load access fault
                    self.csr[0x343] = addr
                    pc = self.csr.get(0x305, 0)
                    continue
                if addr < 0x4000:                      # program RAM window
                    raw = self.m[(addr >> 2) & 0xFFF]
                elif 0x10000000 <= addr < 0x10004000:  # data RAM window
                    off = addr & 0xFFC
                    raw = int.from_bytes(bytes(self.mem[off:off + 4] + [0, 0, 0, 0])[:4], "little")
                else:                                   # peripheral window
                    raw = 0
                if f3 == 0:
                    self.w(rd, _sext((raw >> (8 * (addr % 4))) & 0xFF, 8))
                elif f3 == 1:
                    self.w(rd, _sext((raw >> (8 * (addr % 4))) & 0xFFFF, 16))
                elif f3 == 2:
                    self.w(rd, raw)
                elif f3 == 4:
                    self.w(rd, (raw >> (8 * (addr % 4))) & 0xFF)
                elif f3 == 5:
                    self.w(rd, (raw >> (8 * (addr % 4))) & 0xFFFF)
            elif op == 0x23:
                imm = _sext(((i >> 25) & 0x7F) << 5 | ((i >> 7) & 0x1F), 12)
                addr = (a + imm) & 0xFFFFFFFF
                misaligned = (f3 == 1 and (addr & 1)) or (f3 == 2 and (addr & 3))
                # The program RAM is read-only in the native SoC (WRITE_ENABLE=0),
                # so a store into it is rejected by the slave exactly like an
                # unmapped address.
                if misaligned:
                    self.csr[0x341] = pc
                    self.csr[0x342] = 6          # store address misaligned
                    self.csr[0x343] = addr
                    pc = self.csr.get(0x305, 0)
                    continue
                if not _mapped(addr, f3) or (addr < 0x4000 and not self.prog_writable):
                    self.csr[0x341] = pc
                    self.csr[0x342] = 7          # store access fault
                    self.csr[0x343] = addr
                    pc = self.csr.get(0x305, 0)
                    continue
                off = addr & 0xFFC
                old = int.from_bytes(bytes(self.mem[off:off + 4] + [0, 0, 0, 0])[:4], "little")
                mask = {0: 0xFF, 1: 0xFFFF, 2: 0xFFFFFFFF}.get(f3, 0)
                sh = 8 * (addr % 4)
                self.mem[off:off + 4] = ((old & ~(mask << sh)) | ((b & mask) << sh)).to_bytes(4, "little")
                if addr == halt_addr:
                    self.halt = True
            elif op == 0x13:
                imm = _sext(i >> 20, 12)
                sh = b if False else (i >> 20) & 31
                if f3 == 0:
                    self.w(rd, a + imm)
                elif f3 == 2:
                    self.w(rd, int(_sign(a) < _sign(imm)))
                elif f3 == 3:
                    self.w(rd, int(a < (imm & 0xFFFFFFFF)))
                elif f3 == 4:
                    self.w(rd, a ^ imm)
                elif f3 == 6:
                    self.w(rd, a | imm)
                elif f3 == 7:
                    self.w(rd, a & imm)
                elif f3 == 1:
                    self.w(rd, a << sh)
                elif f3 == 5:
                    self.w(rd, a >> sh if f7 == 0 else _sign(a) >> sh)
            elif op == 0x33:
                sa, sb = _sign(a), _sign(b)
                sh = b & 31
                if f7 == 1:
                    p = a * b
                    if f3 == 0:
                        self.w(rd, p)
                    elif f3 == 1:
                        self.w(rd, (sa * sb) >> 32)
                    elif f3 == 2:
                        self.w(rd, (sa * (b & 0xFFFFFFFF)) >> 32)
                    elif f3 == 3:
                        self.w(rd, p >> 32)
                    elif f3 == 4:
                        self.w(rd, 0xFFFFFFFF if b == 0 else (abs(sa) // abs(sb)) * (-1 if (sa < 0) != (sb < 0) else 1))
                    elif f3 == 5:
                        self.w(rd, 0xFFFFFFFF if b == 0 else a // b)
                    elif f3 == 6:
                        self.w(rd, a if b == 0 else sa - int(sa / sb) * sb if sb else a)
                    elif f3 == 7:
                        self.w(rd, a if b == 0 else a % b)
                else:
                    if f7 == 0x20:
                        # SUB and SRA share funct7=0x20.
                        res = {0: a - b, 5: _sign(a) >> sh}.get(f3, 0)
                    else:
                        res = {0: a + b, 1: a << sh,
                               2: int(sa < sb), 3: int(a < b), 4: a ^ b,
                               5: a >> sh,
                               6: a | b, 7: a & b}.get(f3, 0)
                    self.w(rd, res)
            elif op == 0x73:
                if i == 0x30200073:            # MRET
                    pc = self.csr.get(0x341, 0)
                    continue
                if i == 0x00000073:            # ECALL
                    self.csr[0x341] = pc
                    self.csr[0x342] = 11
                    self.csr[0x343] = 0
                    pc = self.csr.get(0x305, 0)
                    continue
                if i == 0x00100073:            # EBREAK
                    self.csr[0x341] = pc
                    self.csr[0x342] = 3
                    self.csr[0x343] = 0
                    pc = self.csr.get(0x305, 0)
                    continue
                csr = i >> 20
                old = self.csr.get(csr, 0)
                # Immediate CSR forms use the zero-extended rs1 field itself.
                src = r1 if f3 in (5, 6, 7) else a
                new = {1: src, 2: old | src, 3: old & ~src,
                       5: r1, 6: old | r1, 7: old & ~r1}.get(f3, old)
                if csr == 0x341:
                    new &= ~3
                if csr == 0x305:
                    new &= ~3
                if not (f3 in (2, 3, 6, 7) and src == 0):
                    self.csr[csr] = new & 0xFFFFFFFF
                self.w(rd, old)
            else:
                self.csr[0x341] = pc
                self.csr[0x342] = 2
                self.csr[0x343] = i
                pc = self.csr.get(0x305, 0)
                continue
            pc = nxt
        return steps


# case -> entry address of the case body in tests/isa_e2e/isa_e2e.S
CASE_PC = {1: 0x000, 2: 0x200, 3: 0x300, 4: 0x400, 5: 0x500, 6: 0x600,
           7: 0x700, 8: 0x900, 9: 0xA00, 10: 0xB00, 11: 0xC00,
           12: 0xD00, 13: 0xE00, 14: 0xF00, 15: 0x1000, 16: 0x1100}
# The shared trap handler lives in its own 0x1000-aligned section.
TRAP_HANDLER = 0x1000
# mtvec value the test cases program: the trap section is linked at 0x1000
# words = address 0x4000.
MTVEC = 0x3F00


def run(cmd, log_path, timeout=300):
    with open(log_path, "w", encoding="utf-8", errors="replace") as fh:
        fh.write("$ " + " ".join(str(c) for c in cmd) + "\n")
        fh.flush()
        proc = subprocess.run(
            [str(c) for c in cmd], stdout=fh, stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    return proc.returncode


def reg(text, case, i):
    m = re.search(rf"E2E_REG case={case} x{i}=([0-9a-f]+)", text)
    return None if not m else int(m.group(1), 16)


def special_checks(case, text, problems):
    """Cases that read live hardware state (counters, UART, GPIO, timer) cannot
    be predicted by an architectural register model, so they carry explicit
    behavioural checks instead."""
    if case == 7:
        # mcycle is free running; only its observable invariants are checked.
        if reg(text, case, 2) != 1:
            problems.append(f"x2={reg(text, case, 2)} want 1 (mcycleh after wrap)")
        x3 = reg(text, case, 3)
        if x3 is None or x3 > 64:
            problems.append(f"x3={x3} want a small value (mcycle cleared then re-read)")
        x5 = reg(text, case, 5)
        if not x5:
            problems.append("x5=0: mcycle alias did not advance")
    elif case == 12:
        n = text.count("UART_TX char=")
        if "UART_TX char='A'" not in text:
            problems.append("UART character 'A' not decoded")
        if n != 1:
            problems.append(f"{n} UART characters decoded, want exactly 1")
        if reg(text, case, 2) != 0x41:
            problems.append(f"x2={reg(text, case, 2):08x} want 00000041")
    elif case == 13:
        m = re.search(r"E2E_GPIO ctrl=([0-9a-f]+) data=([0-9a-f]+)", text)
        if not m or int(m.group(1), 16) != 5 or int(m.group(2), 16) != 2:
            problems.append(f"GPIO mismatch: {m.group(0) if m else 'no sample'}")
    elif case == 14:
        x8 = reg(text, case, 8)
        if x8 is None or not (x8 & 4) or (x8 & 1):
            problems.append(f"x8={x8} want pending set (bit2) and enable clear (bit0)")
        if reg(text, case, 10) != 2:
            problems.append(f"x10={reg(text, case, 10)} want 2 (W1C cleared pending)")
    elif case == 15:
        # The interrupt is asynchronous; only its architectural contract is
        # checked: exactly one machine-timer trap (cause 0x80000007) reached the
        # handler, the handler's flag became visible to the interrupted loop,
        # and execution returned through MRET.
        if "cause=80000007" not in text:
            causes = re.findall(r"E2E_TRAP n=\d+ cause=([0-9a-f]+)", text)
            problems.append(
                "no machine timer interrupt (cause 80000007); observed: "
                + (", ".join(causes) if causes else "none"))
        ntrap = len(re.findall(r"E2E_TRAP n=", text))
        if ntrap != 1:
            problems.append(f"{ntrap} traps observed, want exactly 1")
        if reg(text, case, 8) != 1:
            problems.append(
                f"x8={reg(text, case, 8)} want 1 (interrupt-handler flag)")


# Cases whose behaviour is fixed by hardware state rather than by a register
# computation; they use special_checks instead of the Ref oracle.
SPECIAL_CASES = {7, 12, 13, 14, 15}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--toolchain-bin", type=Path, default=DEFAULT_TOOLCHAIN)
    ap.add_argument("--prefix", default="riscv32-unknown-elf-",
                    help="toolchain program prefix (default: riscv32-unknown-elf-)")
    ap.add_argument("--extra-flag", action="append", default=[], metavar="FLAG",
                    help="extra compiler flag, repeatable (e.g. -march=rv32im_zicsr)")
    ap.add_argument("--modelsim", type=Path, default=DEFAULT_MODELSIM)
    ap.add_argument("--cases", default="all")
    ap.add_argument("--dump-expected", action="store_true",
                    help="print the reference model's expected registers per case")
    ap.add_argument("--out", type=Path, default=ROOT / ".sim_runs")
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()

    if args.cases == "all":
        cases = sorted(CASE_PC)
    else:
        cases = [int(c) for c in re.split(r"[,\s]+", args.cases) if c]

    # The historical default is the OpenISA riscv32-unknown-elf-* toolchain. Modern
    # xpack releases ship the riscv-none-elf-* prefix, which produces identical
    # rv32im code, so the prefix and extra flags are parameters instead of
    # constants (GCC 12+ also needs -march=rv32im_zicsr for csr instructions).
    gcc = args.toolchain_bin / (args.prefix + "gcc.exe")
    objcopy = args.toolchain_bin / (args.prefix + "objcopy.exe")
    objdump = args.toolchain_bin / (args.prefix + "objdump.exe")
    for tool in (gcc, objcopy, objdump):
        if not tool.exists():
            print(f"BLOCKED: toolchain tool not found: {tool}")
            return 2
    vlog = args.modelsim / "vlog.exe"
    vsim = args.modelsim / "vsim.exe"
    vlib = args.modelsim / "vlib.exe"
    vmap = args.modelsim / "vmap.exe"
    for tool in (vlog, vsim, vlib, vmap):
        if not tool.exists():
            print(f"BLOCKED: ModelSim tool not found: {tool}")
            return 2

    # Explicit mkdir instead of tempfile.mkdtemp: on this Windows workspace the
    # 0700 directory created by tempfile is not writable by the next process
    # (verification.md E02).  A normal directory with a unique suffix works.
    out_root = Path(args.out)
    out_root.mkdir(parents=True, exist_ok=True)
    work_dir = out_root / ("isa-e2e-" + uuid.uuid4().hex[:8])
    work_dir.mkdir(parents=True, exist_ok=False)
    src = ROOT / "tests" / "isa_e2e" / "isa_e2e.S"
    elf = work_dir / "isa_e2e.elf"
    raw = work_dir / "isa_e2e.bin"

    print(f"work dir: {work_dir}")
    rc = run([gcc, "-march=rv32im", "-mabi=ilp32", *args.extra_flag,
              "-nostdlib", "-nostartfiles",
              "-static", "-Wl,--no-relax", "-T", str(ROOT/"tests"/"isa_e2e"/"link.ld"),
              "-e", "_start",
              str(src), "-o", str(elf)], work_dir / "assemble.log")
    if rc != 0:
        print("ASSEMBLE FAILED")
        print((work_dir / "assemble.log").read_text(errors="replace")[:3000])
        return 1

    # Confirm no compressed instructions ever entered the executable image. The
    # constant table at 0x100 is data inside .text, so only disassembly lines
    # that name an instruction mnemonic are considered.
    rc = run([objdump, "-d", str(elf)], work_dir / "objdump.log")
    text = (work_dir / "objdump.log").read_text(errors="replace")
    c_insns = [ln for ln in text.splitlines()
               if re.match(r"\s+[0-9a-f]+: [0-9a-f]{4} [a-z]", ln)]
    if c_insns:
        print(f"FAIL: {len(c_insns)} compressed instructions in the image")
        print("\n".join(c_insns[:5]))
        return 1
    print("image check: no compressed instructions")

    rc = run([objcopy, "-O", "binary", str(elf), str(raw)],
             work_dir / "objcopy.log")
    if rc != 0:
        print("OBJCOPY FAILED")
        return 1
    image = raw.read_bytes()
    if len(image) > 16384:
        print(f"FAIL: image is {len(image)} bytes, program RAM is 16384")
        return 1
    print(f"image: {len(image)} bytes of 16384")

    # ModelSim $readmemh image: one 32-bit little-endian word per line, padded
    # with NOPs so the whole program RAM is defined.
    words = []
    padded = image + b"\x00" * ((4 - len(image) % 4) % 4)
    for off in range(0, len(padded), 4):
        words.append(int.from_bytes(padded[off:off + 4], "little"))
    while len(words) < 4096:
        words.append(0x00000013)  # NOP

    # The CPU always resets to address 0, and the case bodies live at fixed
    # .org offsets, so each case image gets a one-instruction entry stub
    # (`jal x0, <case entry>`) patched into word 0. Case 1 already starts at 0.
    def case_image(case):
        w = list(words)
        entry = CASE_PC[case]
        if entry:
            w[0] = jal_x0(entry)
        return w

    def image_file(case):
        path = work_dir / f"case{case:02d}.hex"
        path.write_text("\n".join(f"{x:08x}" for x in case_image(case)) + "\n",
                        encoding="ascii")
        return path

    def reference(case):
        ref = Ref(case_image(case))
        ref.csr[0x305] = MTVEC
        ref.run(0)
        return ref

    if args.dump_expected:
        for case in cases:
            ref = reference(case)
            vals = {r: v for r, v in enumerate(ref.r)
                    if v != 0 and r not in (29, 30)}
            print(f"case {case:2d} "
                  + " ".join(f"x{r}={v:08x}" for r, v in vals.items()))
        return 0

    # Compile the full native SoC plus the testbench.
    lib = work_dir / "work"
    rc = run([vlib, str(lib)], work_dir / "vlib.log")
    run([vmap, "work", str(lib)], work_dir / "vmap.log")
    if rc != 0:
        print("VLIB FAILED")
        return 1
    manifest = ROOT / "sim" / "native_axi_sources.f"
    rc = run([vlog, "-sv", "-work", str(lib),
              f"+incdir+{ROOT/'rtl'/'core'}", f"+incdir+{ROOT/'rtl'/'soc'}",
              "-f", str(manifest), str(ROOT / "tb" / "integration" / "tb_isa_e2e.sv")],
             work_dir / "compile.log")
    log_text = (work_dir / "compile.log").read_text(errors="replace")
    if rc != 0 or re.search(r"\*\* Error", log_text):
        print("COMPILE FAILED")
        print(log_text[-3000:])
        return 1
    print("compile: 0 errors")

    results = []
    for case in cases:
        log = work_dir / f"case{case:02d}.log"
        img = image_file(case)
        rc = run([vsim, "-c", "-lib", str(lib), "work.tb_isa_e2e",
                  "-do", "run -all; quit -f",
                  f"+PROG={img}", f"+DATA={img}",
                  f"+CASE={case}"],
                 log, timeout=600)
        text = log.read_text(errors="replace")
        problems = []
        if not re.search(rf"TEST_PASS case={case}", text):
            problems.append("no pass marker")
        want_ref = reference(case)
        if case not in SPECIAL_CASES:
            want_regs = want_ref.r
            for regno in sorted(want_ref.written):
                m = re.search(rf"E2E_REG case={case} x{regno}=([0-9a-f]+)", text)
                if not m:
                    problems.append(f"x{regno}: no observed value")
                elif int(m.group(1), 16) != want_regs[regno]:
                    problems.append(
                        f"x{regno}={m.group(1)} want {want_regs[regno]:08x}")
        else:
            special_checks(case, text, problems)
        # x0 must never be written: the retire trace reports we=0 for rd=0.
        if re.search(rf"E2E_RETIRE.* rd=0 we=1", text):
            problems.append("x0 written by a retiring instruction")
        if case == 12:
            pass
        if re.search(r"E2E_TIMEOUT", text):
            problems.append("timeout waiting for the halt store")
        if re.search(r"E2E_FAULT", text):
            problems.append("unexpected bus fault: " + re.search(r"E2E_FAULT.*", text).group(0))
        results.append((case, problems))
        status = "PASS" if not problems else "FAIL"
        print(f"case {case:2d} {status}  {NAME[case]}")
        for p in problems:
            print(f"          - {p}")

    failures = [c for c, p in results if p]
    print(f"SUMMARY {len(cases) - len(failures)} / {len(cases)} PASS")
    if failures:
        print("failing cases: " + ", ".join(str(c) for c in failures))
    if not args.keep:
        pass
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
