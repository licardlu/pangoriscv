# Native software build

Run from the package root with Python 3.8 or newer:

```powershell
python tools/build_native_software.py coremark
python tools/build_native_software.py coremark --mode validation
python tools/build_native_software.py timer_int --simulation
```

The default compiler directory is the sibling
`toolchains/openisa-1.0.0/gcc/riscv32-unknown-elf-gcc/bin`. Override it with
`--toolchain-bin PATH`; `--prefix` defaults to `riscv32-unknown-elf-`.
The script invokes tools directly, so neither WSL nor make is required.
The target is RV32IM/ILP32 with machine CSRs, using the GCC 7.1.1-compatible
`-march=rv32im` spelling. An RV32I-only build is not supplied: it would also
need a separately audited software multiplication/division runtime.

Outputs are isolated under `build/native_software/APP/MODE/`:

- `program.hex`: 4096 little-endian 32-bit words for flash at address zero.
  It includes initialized data's flash load image; startup copies it into RAM.
- `data.hex`: 4096 words for RAM at `0x10000000`, with initialized data at its
  virtual address and the remaining bytes zero. Startup still performs its
  regular copy and BSS clear.
- `APP.elf`, `firmware.map`, `firmware.dump`, `program.bin`, and
  `manifest.json`: compiler identity, arguments, source/artifact SHA-256
  values, ELF segment addresses, and build evidence.

The linker reserves 8 KiB of the 16 KiB RAM for the stack and rejects
data/BSS overlap. The builder rejects overlapping load-image ranges,
out-of-memory segments, ELF RVC flags, non-32-bit disassembled instructions,
and unresolved non-weak symbols. It links no libc or precompiled libgcc.
The local unsigned 64-bit division/modulo routines use binary long division.
Original precompiled reference images are not overwritten.

CoreMark algorithm sources and CRC tables remain unchanged. Default runs
use 10000 iterations, performance seeds, integer timing, and **27 MHz**, which
is the MES2L676-100HP board system clock (`clk` on D18): the board's single-ended
oscillator is 27 MHz, confirmed from the official hardware manual and from the
official UART demo, whose `uart_top.v` uses `BPS_NUM = 16'd234` (= 27e6/115200).
`--iterations`, `--mode`, and `--cpu-mhz` explicitly change those choices; keep
`--cpu-mhz` equal to the real board clock, because `CPU_FREQ_MHZ` also fixes the
UART baud write in `lib/uart.c` and the seconds conversion in CoreMark.
Integer seconds are truncated; the original CoreMark `Total ticks` line
also narrows ticks to 32 bits. Do not derive a precise long-run score from
that line alone: capture the 64-bit `get_time()` value or instrument the
verification environment. A build does not establish CRC success, runtime
duration, CoreMark/MHz, board frequency, or a measured performance result.

Startup leaves global interrupts and `mie` disabled. The timer example
clears/configures its source before enabling MTIE and global MIE.
Applications can define `software_irq_handler`, `timer0_irq_handler`, or
`external_irq_handler`; each must acknowledge its own source.
Unregistered interrupts and synchronous exceptions halt after recording
`trap_last_fault` in RAM. Only an explicit `TRAP_TEST_ALLOW_ECALL` build
permits an M-mode ECALL to advance the saved PC by four bytes.

The initial CoreMark performance build was compiled and linked locally.
No native software execution, simulation, hardware run, or benchmark
validation was performed as part of this software edit.

## Board-frequency change (board-material audit, 2026-10-11)

The board clock is 27 MHz, so the frequency-dependent software defaults were
corrected in this round (see the project validation archive):

- `include/utils.h`: `CPU_FREQ_MHZ` default `50U` -> `27U`
- `lib/uart.c`: `uart_init()` now writes `UART0_BAUD = CPU_FREQ_HZ / 115200`
  (= 234 at 27 MHz, matching the `axi_uart.v` reset value) and includes
  `include/utils.h`
- `tools/build_native_software.py`: `--cpu-mhz` default `50` -> `27`

The 200-iteration performance image was rebuilt afterwards:
`manifest.json` reports `"cpu_hz": 27000000`, and the image that the PDS flow
loads is the one in `build/native_software/coremark/performance/`.
Images built before this change (50 MHz) remain archived in the project validation
archive and must not be used on this board.
