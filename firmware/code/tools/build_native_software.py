"""Build native RV32IM firmware without make, WSL, libc, or prebuilt libgcc.

Writes fresh artifacts under build/native_software, never overwriting reference images.
The ELF loader uses PT_LOAD physical addresses for flash (including data's
startup copy) and virtual addresses for the optional initialized RAM image.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / "tests" / "example"
DEFAULT_TOOLS = (ROOT.parent / "toolchains" / "openisa-1.0.0" / "gcc" /
                 "riscv32-unknown-elf-gcc" / "bin")
FLASH_BASE, RAM_BASE, MEMORY_SIZE = 0, 0x10000000, 16384


def command(args):
    result = subprocess.run([str(arg) for arg in args], check=False,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, errors="replace")
    if result.stderr:
        print(result.stderr, end="")
    result.check_returncode()
    return result.stdout


def put_image(image, occupied, base, address, payload):
    offset = address - base
    if offset < 0 or offset + len(payload) > len(image):
        raise ValueError("Load segment outside 16 KiB memory: %#x" % address)
    if any(occupied[offset:offset + len(payload)]):
        raise ValueError("Overlapping ELF load segments at %#x" % address)
    image[offset:offset + len(payload)] = payload
    occupied[offset:offset + len(payload)] = b"\x01" * len(payload)


def extract_images(elf):
    data = elf.read_bytes()
    if data[:7] != b"\x7fELF\x01\x01\x01":
        raise ValueError("Expected a little-endian ELF32 file")
    header = struct.unpack_from("<HHIIIIIHHHHHH", data, 16)
    machine, entry, phoff, flags = header[1], header[3], header[4], header[6]
    phentsize, phnum = header[8], header[9]
    if machine != 243 or flags & 1:
        raise ValueError("Expected RISC-V ELF with the RVC flag clear")
    if entry != FLASH_BASE or phentsize != 32:
        raise ValueError("Unexpected entry point or program-header size")
    flash, ram = bytearray(MEMORY_SIZE), bytearray(MEMORY_SIZE)
    flash_used, ram_used = bytearray(MEMORY_SIZE), bytearray(MEMORY_SIZE)
    segments = []
    for index in range(phnum):
        kind, offset, vma, lma, size, memsize, access, align = \
            struct.unpack_from("<IIIIIIII", data, phoff + index * phentsize)
        if kind != 1:
            continue
        if size > memsize or (size and offset + size > len(data)):
            raise ValueError("Malformed load segment")
        if memsize:
            base = FLASH_BASE if vma < RAM_BASE else RAM_BASE
            if vma < base or vma + memsize > base + MEMORY_SIZE:
                raise ValueError("Segment VMA exceeds memory region")
        payload = data[offset:offset + size]
        if size:
            if FLASH_BASE <= lma < FLASH_BASE + MEMORY_SIZE:
                put_image(flash, flash_used, FLASH_BASE, lma, payload)
            elif not (RAM_BASE <= lma < RAM_BASE + MEMORY_SIZE):
                raise ValueError("Unsupported segment LMA")
            if RAM_BASE <= vma < RAM_BASE + MEMORY_SIZE:
                put_image(ram, ram_used, RAM_BASE, vma, payload)
            elif not (FLASH_BASE <= lma < FLASH_BASE + MEMORY_SIZE):
                raise ValueError("Executable image has no flash load address")
        # A zero-file-size PT_LOAD (for example the linker script's NOLOAD
        # .stack segment) occupies no memory and must not be validated as a
        # loadable image; its LMA is only the address it was laid out from.
        segments.append(dict(vma=vma, lma=lma, file_size=size,
                             memory_size=memsize, flags=access, alignment=align))
    if not any(flash_used):
        raise ValueError("Empty program image")
    return flash, ram, segments


def write_hex(path, image):
    path.write_text("".join("%08x\n" % word[0]
                            for word in struct.iter_unpack("<I", image)),
                    encoding="ascii")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("application", choices=["coremark", "timer_int", "simple",
                                                "gpio", "uart_tx", "uart_rx",
                                                "spi_master", "led_walk",
                                                "selftest", "irq_test",
                                                "perf_probe", "gpio_trace"])
    parser.add_argument("--toolchain-bin", type=Path, default=DEFAULT_TOOLS)
    parser.add_argument("--prefix", default="riscv32-unknown-elf-")
    # Extra -D definitions, repeatable, e.g. --define TRACE_STOP_COUNT=8. Used by the
    # simulation runners to give a firmware the same knobs a board build keeps at their
    # defaults (tests/example/gpio_trace/main.c: TRACE_STOP_COUNT / TRACE_WINDOW_MS).
    parser.add_argument("--define", action="append", default=[], metavar="NAME[=VALUE]",
                        help="extra preprocessor definition (repeatable)")
    # The optimisation level is a first-class A/B knob: the board reference of this round is
    # -O2, and any change is only reportable when the manifest records both sides' flags.
    parser.add_argument("--opt", default="-O2",
                        choices=["-O0", "-O1", "-O2", "-O3", "-Os"],
                        help="optimisation level (default -O2)")
    parser.add_argument("--extra-flag", action="append", default=[], metavar="FLAG",
                        help="extra compiler/linker flag, repeatable (e.g. -funroll-loops)")
    # A tag keeps an experimental image beside the reference instead of overwriting it, so
    # both sides of an A/B stay on disk with their own manifest.
    parser.add_argument("--tag", default="",
                        help="optional subdirectory under <app>/<mode> for A/B builds")
    parser.add_argument("--iterations", type=int, default=10000)
    parser.add_argument("--mode", choices=["performance", "validation", "profile"],
                        default="performance")
    # Default is the MES2L676-100HP board clock (27 MHz single-ended oscillator on D18),
    # not the 50 MHz value earlier rounds assumed. It feeds CoreMark's seconds conversion
    # and the UART baud write in lib/uart.c, so it must match the board or the reported
    # run time and the serial baud rate are both wrong on hardware.
    parser.add_argument("--cpu-mhz", type=int, default=27)
    parser.add_argument("--simulation", action="store_true")
    args = parser.parse_args()
    if not 0 <= args.iterations <= 0x7fffffff or not 1 <= args.cpu_mhz <= 4000:
        parser.error("Invalid iterations or CPU frequency")
    tools = {}
    for name in ["gcc", "objdump", "nm"]:
        path = args.toolchain_bin / (args.prefix + name)
        if not path.is_file():
            path = path.with_suffix(".exe")
        if not path.is_file():
            parser.error("Missing tool: %s" % path)
        tools[name] = path
    out = ROOT / "build" / "native_software" / args.application / args.mode
    if args.tag:
        out = out / args.tag
    out.mkdir(parents=True, exist_ok=True)
    # A failed rebuild must not retain a previous success manifest.
    manifest_path = out / "manifest.json"
    manifest_path.unlink(missing_ok=True)
    common = ["start.S", "trap_entry.S", "init.c", "trap_handler.c",
              "lib/utils.c", "lib/runtime.c", "lib/uart.c", "lib/xprintf.c",
              "lib/spi.c", "lib/flash_n25q.c"]
    sources = [EXAMPLES / name for name in common]
    app = EXAMPLES / args.application
    if args.application == "coremark":
        sources.extend(app / name for name in [
            "core_list_join.c", "core_main.c", "core_matrix.c",
            "core_state.c", "core_util.c", "core_portme.c"])
    else:
        sources.extend(sorted(app.glob("*.c")))
    flags = ["-march=rv32im", "-mabi=ilp32", "-mcmodel=medlow", args.opt,
             "-ffreestanding", "-fno-builtin", "-fno-common",
             "-ffunction-sections", "-fdata-sections", "-falign-functions=4",
             "-falign-jumps=4", "-falign-loops=4",
             "-DCPU_FREQ_MHZ=%d" % args.cpu_mhz]
    flags += list(args.extra_flag)
    if args.application == "coremark":
        flags += ["-DITERATIONS=%d" % args.iterations,
                  "-D%s_RUN=1" % args.mode.upper()]
    if args.simulation:
        flags += ["-DSIMULATION"]
    flags += ["-D" + item for item in args.define]
    flags += ['-DFLAGS_STR="%s"' % " ".join(flags)]
    commands, objects = [], []
    for index, source in enumerate(sources):
        obj = out / ("%02d_%s.o" % (index, source.stem))
        invocation = [tools["gcc"], *flags, "-I", EXAMPLES, "-c", source,
                      "-o", obj]
        commands.append([str(item) for item in invocation])
        command(invocation)
        objects.append(obj)
    elf = out / (args.application + ".elf")
    invocation = [tools["gcc"], *flags, "-nostdlib", *objects, "-T",
                  EXAMPLES / "link.lds", "-Wl,--gc-sections",
                  "-Wl,--check-sections", "-Wl,-Map=" + str(out / "firmware.map"),
                  "-o", elf]
    commands.append([str(item) for item in invocation])
    command(invocation)
    unresolved = command([tools["nm"], "-u", elf])
    # Weak unresolved handlers are intentional and resolve to null.
    if any(line.strip() and line.split()[0].upper() != "W"
           for line in unresolved.splitlines()):
        raise ValueError("Unresolved runtime symbols:\n" + unresolved)
    disassembly = command([tools["objdump"], "-d", elf])
    for line in disassembly.splitlines():
        match = re.match(r"^\s*[0-9a-fA-F]+:\s+([0-9a-fA-F]+)\s", line)
        if match and (len(match[1]) != 8 or int(match[1], 16) & 3 != 3):
            raise ValueError("Non-32-bit instruction in executable section: " + line)
    (out / "firmware.dump").write_text(disassembly, encoding="utf-8")
    flash, ram, segments = extract_images(elf)
    write_hex(out / "program.hex", flash)
    write_hex(out / "data.hex", ram)
    (out / "program.bin").write_bytes(flash)
    provenance = sources + [EXAMPLES / "link.lds", Path(__file__).resolve()]
    provenance += sorted((EXAMPLES / "include").glob("*.h"))
    provenance += sorted(app.glob("*.h"))
    source_hashes = {str(source.relative_to(ROOT)):
                     hashlib.sha256(source.read_bytes()).hexdigest()
                     for source in provenance}
    manifest = dict(application=args.application, architecture="rv32im",
                    abi="ilp32", compressed_instructions=False,
                    compiler=command([tools["gcc"], "--version"]).splitlines()[0],
                    flags=flags, commands=commands, mode=args.mode,
                    iterations=args.iterations, cpu_hz=args.cpu_mhz * 1000000,
                    runtime="local freestanding C; no libgcc or libc",
                    segments=segments, source_sha256=source_hashes,
                    image_format="4096 little-endian 32-bit hex words per memory",
                    startup="program.hex includes data LMA; startup copies to RAM",
                    evidence="compile/link/static image checks only; not executed",
                    artifact_sha256={name: hashlib.sha256((out / name).read_bytes()).hexdigest()
                                     for name in ["program.hex", "data.hex",
                                                  "program.bin", elf.name]})
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n",
                             encoding="utf-8")
    print("Built:", elf)
    print("Manifest:", manifest_path)


if __name__ == "__main__":
    main()
