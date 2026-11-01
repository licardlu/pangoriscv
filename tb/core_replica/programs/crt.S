.section .text.init,"ax"
.globl _start
_start:
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, _stack_top
  la t0, trap_entry
  csrw mtvec, t0
  csrw mie, zero
  csrw mstatus, zero
  la t0, _bss_start
  la t1, _bss_end
1:
  bgeu t0, t1, 2f
  sw zero, 0(t0)
  addi t0, t0, 4
  j 1b
2:
  fence.i
  call main
3:
  j 3b

.balign 4
trap_entry:
  csrr a0, mcause
  csrr a1, mepc
  csrr a2, mtval
  addi sp, sp, -16
  sw ra, 12(sp)
  call trap_report
  lw ra, 12(sp)
  addi sp, sp, 16
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
