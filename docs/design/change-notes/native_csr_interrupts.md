# Native M-Mode CSR and Trap Contract

This document describes implemented RTL, not simulation or board validation.
Production sources include `rtl/core/csr_native.v`; baseline `csr_reg.v` and
`clint.v` are unchanged and are not instantiated by the native CPU.

| CSR | Address | Policy |
| --- | --- | --- |
| mstatus | 300 | MIE bit 3 and MPIE bit 7 writable; MPP fixed M; other bits zero |
| misa | 301 | Read-only RV32IM, 0x40001100 |
| mie | 304 | Software/timer/external enables at bits 3/7/11 |
| mtvec | 305 | Direct only, low two bits forced zero |
| mscratch | 340 | Read/write |
| mepc | 341 | Read/write, low two bits forced zero |
| mcause, mtval | 342,343 | Read/write, trap overwrites atomically |
| mip | 344 | Read-only live hardware IRQ levels at bits 3/7/11 |
| mcycle, mcycleh | B00,B80 | Writable 64-bit counter |
| minstret, minstreth | B02,B82 | Writable 64-bit actual-retirement counter |
| cycle, cycleh | C00,C80 | Read-only mcycle aliases |
| instret, instreth | C02,C82 | Read-only minstret aliases |
| mhartid | F14 | Read-only zero |

Other addresses and writes to read-only CSRs trap as illegal instructions.
Counter half writes override that clock's increment and preserve the other
half from the pre-clock counter. Traps do not increment minstret.

All six Zicsr operations read CSR state in EX, never an ID snapshot. CSRRW
always writes, including rd=x0; no implemented CSR has read side effects.
CSRRS/CSRRC write intent depends on the encoded rs1 index (not its value).
Immediate operands are zero-extended zimm; zero zimm suppresses set/clear writes.
Only exact ECALL, EBREAK and MRET system encodings are accepted. FENCE is
supported at the serialized EX boundary; FENCE.I is illegal.

The wrapper and SoC expose irq_software, irq_timer and irq_external inputs.
Priority is external > software > timer. Interrupt eligibility uses the
post-normal-CSR-write and post-MRET state. Trap entry then copies that MIE
into MPIE, clears MIE, and records full 32-bit mcause.

Synchronous faults have priority. Interrupts are accepted only at actual
retirement or an empty EX boundary, never while memory/division is incomplete.
Interrupt mepc is the retired instruction's actual successor (including branch
and MRET), or arch_next_pc when EX is empty. Acceptance flushes younger fetch/ID
work before it can enter EX. trap_ready backpressure delays acceptance but does
not undo or repeat normal retirement. A retiring store has completed its response.
Halting suppresses interrupt acceptance while current EX drains.

trap_cause is now 32 bits. csr_mtvec exposes the architectural redirect target.
The old trap_vector input remains for connection compatibility but is unused:
native traps always redirect using architectural mtvec. mtvec resets to zero.

Syntax-only verification:
`vlog -sv -work sim/work_csr_native_compile +incdir+rtl/core -f sim/native_axi_sources.f`
completed with zero errors and zero warnings. No simulation was run.
