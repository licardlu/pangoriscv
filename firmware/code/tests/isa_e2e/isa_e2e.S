/* End-to-end RV32IM regression for the native AXI SoC.
 * Assembled by tools/build_isa_tests.py with the contest toolchain
 * (riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32) and executed on
 * pango_native_top by tb/integration/tb_isa_e2e.sv.
 *
 * Every test case ends with the HALT macro: it stores the signature word to
 * HALT_ADDR. The testbench treats that store as "this case finished" and then
 * compares the register file against the case's expected values.
 *
 * Layout (link address 0):
 *   0x000        test1
 *   0x100..0x107 constants used by test2
 *   0x200        test2
 *   0x300        test3
 *   0x400        test4
 *   0x500        test5
 *   0x600        test6
 *   0x700        test7
 *   0x900        test8     (the ecall must sit at a known address)
 *   0xa00        test9
 *   0xb00        test10
 *   0xc00        test11
 *   0xd00        test12
 *   0xe00        test13
 *   0xf00        test14
 *   0x800        shared trap handler
 */
  .section .text
  .globl _start

  .macro HALT
    lui   x30, 0x10000            /* 0x10000000 */
    li    x28, 0xff0
    or    x30, x30, x28           /* 0x10000ff0 */
    li    x29, 0x5a5a1234
    sw    x29, 0(x30)
1:  j     1b
  .endm

/* The shared trap handler is defined at the end of the file so the linker
 * script places .text (starting at address 0) before .trap (at 0x4000).
 * Tests 8-11 read x5/x6/x7 (mepc/mcause/mtval) from here. */

  .section .text

/* ------------------------------------------------------------------ test 1
 * ALU dependency chains, x0 writes, immediate forms, LUI, M-extension reuse.
 * Expected: x2=12 x3=31 x4=15 x5=31 x6=224 x7=40 x8=112 x9=14 x10=0xABCDE000
 */
  .org 0x000
_start:
test1:
  addi  x1, x0, 5
  addi  x2, x1, 7               /* RAW on x1 */
  add   x3, x2, x1              /* RAW on x2 and x1 */
  addi  x0, x3, 9               /* x0 must stay 0 */
  andi  x4, x3, 0xf
  ori   x5, x4, 0x10
  xori  x6, x5, 0xff
  slli  x7, x1, 3
  srai  x8, x6, 1
  srli  x9, x6, 2
  lui   x10, 0xabcde
  HALT

/* ------------------------------------------------------------------ test 2
 * Load-use hazards, all load widths, sign and zero extension.
 * Expected: x11=0x8000abcd x12=0x8000abce x13=0xcd x14=0xffffffcd
 *           x15=0x8000 x16=0xffff8000 x17=0x12345678
 *           x18=0x12345745 x19=0x923456ab
 */
  .org 0x100
  .word 0x8000abcd
  .word 0x12345678
  .word 0x13579bdf
  .org 0x200
test2:
  lui   x1, 0x0
  addi  x1, x1, 0x108           /* x1 -> the constant table */
  lw    x11, -8(x1)
  addi  x12, x11, 1             /* immediate use of the load result */
  lbu   x13, -8(x1)
  lb    x14, -8(x1)
  lhu   x15, -6(x1)
  lh    x16, -6(x1)
  lw    x17, -4(x1)
  add   x18, x17, x13           /* both operands from loads */
  sub   x19, x17, x11
  HALT

/* ------------------------------------------------------------------ test 3
 * M extension: signed/unsigned multiply, divide, remainder, divide by zero.
 * Expected: x3=0xffffffeb x4=0 x5=0 x6=0x2492491f x7=4 x8=0
 *           x9=0xffffffff x10=0xffffffeb
 */
  .org 0x300
test3:
  addi  x1, x0, 7
  addi  x2, x0, -3
  mul   x3, x1, x2              /* -21 */
  mulhu x4, x1, x1              /* high half of 49 = 0 */
  div   x5, x2, x1              /* -3 / 7 = 0 */
  li    x20, -21
  divu  x6, x20, x1             /* 0xffffffeb / 7 */
  remu  x7, x20, x1             /* 4 */
  xor   x8, x3, x20             /* 0 */
  divu  x9, x1, x0              /* divide by zero => all ones */
  remu  x10, x20, x0            /* remainder by zero => dividend */
  HALT

/* ------------------------------------------------------------------ test 4
 * Branch and jump behaviour, wrong-path suppression.
 * Expected: x3=7 x6=11 x7=12 x10=40 x18=40; x4,x5,x8,x9,x11 must stay 0.
 */
  .org 0x400
test4:
  addi  x1, x0, 1
  addi  x2, x0, 0
  bne   x1, x2, 4f              /* taken */
  addi  x3, x0, 99              /* wrong path */
  addi  x4, x0, 99              /* wrong path */
  addi  x5, x0, 99              /* wrong path */
4:
  beq   x1, x1, 5f              /* taken */
  addi  x6, x0, 99              /* wrong path */
  addi  x7, x0, 99              /* wrong path */
5:
  jal   x10, 6f                 /* x10 = return address */
  addi  x8, x0, 99              /* skipped */
  addi  x9, x0, 99              /* skipped */
6:
  jalr  x18, x10, 16            /* x18 = return address, jump to label 7 */
  addi  x11, x0, 99             /* skipped */
7:
  blt   x1, x0, 8f              /* not taken (1 >= 0) */
  addi  x3, x0, 7
  bge   x1, x0, 9f              /* taken */
  addi  x4, x0, 99              /* wrong path */
9:
  addi  x6, x0, 11
  addi  x7, x0, 12
8:
  HALT

/* ------------------------------------------------------------------ test 5
 * Byte/halfword lanes and store->load through the real LSU/AXI/RAM path.
 * Expected: x3=0xa5 x4=0xa5a5 x5=0xa5a5a5a5 x6=0xa5a5a5a6
 */
  .org 0x500
test5:
  lui   x1, 0x10000             /* 0x10000000 data RAM */
  lui   x2, 0xa5a5a
  ori   x2, x2, 0x5a5           /* 0xA5A5A5A5 */
  sb    x2, 44(x1)
  sh    x2, 54(x1)
  sw    x2, 32(x1)
  lbu   x3, 44(x1)
  lhu   x4, 54(x1)
  lw    x5, 32(x1)
  addi  x6, x5, 1
  HALT

/* ------------------------------------------------------------------ test 6
 * CSR rules: rs1==x0 suppresses set/clear but not CSRRW; rd==x0 still
 * writes for CSRRW; zimm==0 suppresses the immediate forms.
 * Expected: x2=0 x3=0xffffffff x4=0 x5=15 x6=3 x7=31
 */
  .org 0x600
test6:
  li    x1, -1
  csrrw x2, 0x340, x1        /* mscratch = 0xffffffff, x2 = 0 */
  csrrs x3, 0x340, x0        /* rs1=x0: no write, x3 = 0xffffffff */
  csrrc x0, 0x340, x1        /* rd=x0 still clears every bit */
  csrrw x4, 0x340, x0        /* rs1=x0 still writes 0 */
  li    x5, 15
  csrrsi x6, 0x340, 5        /* zimm=5 sets bits 1:0 */
  csrrwi x7, 0x340, 31
  csrrsi x8, 0x340, 0        /* zimm=0: no write */
  csrrs x9, 0x340, x0        /* x9 = 31 */
  HALT

/* ------------------------------------------------------------------ test 7
 * mcycle/minstret: writable halves, read-only aliases, free running.
 * Expected: x2=1 x3=0 x5 = cycle low half, non-zero, even after the shift pair
 *
 * The wrap carry is only observable once at least one mcycle increment has
 * elapsed after the write, so the NOP below is REQUIRED, not decoration: the
 * two CSR instructions would otherwise issue on consecutive cycles, and the
 * read would sample mcycleh in the very cycle the low half still holds
 * 0xffffffff (carry not yet applied).  Without it the case depends on whether
 * an instruction-fetch bubble happens to land between them, which any change to
 * pipeline timing can flip -- that is a property of the test, not of the core.
 */
  .org 0x700
test7:
  li    x1, -1
  csrw  0xb00, x1              /* mcycle = 0xffffffff */
  nop                          /* let one increment carry into mcycleh */
  csrrs x2, 0xb80, x0         /* wraps: mcycleh = 1 */
  csrrc x0, 0xb00, x1          /* clear low half */
  csrrs x3, 0xb00, x0          /* x3 = 0 */
  csrrs x5, 0xc00, x0           /* read-only alias of mcycle */
  slli  x5, x5, 1
  srli  x5, x5, 1               /* keep in range, still non-zero expected */
  HALT

/* ------------------------------------------------------------------ test 8
 * ECALL trap entry and MRET return. The ecall sits at 0x900.
 * Expected: x5=0x900 (mepc) x6=11 (mcause) x7=0 x3=7 x4=9
 */
  .org 0x900
test8:
  lui   x2, 0x0
  li    x2, 0x3f00
  csrw  0x305, x2
  csrwi 0x341, 0                 /* clear, so a stale value is visible */
  csrwi 0x342, 0
  ecall                         /* trap; mepc = 0x900 */
  addi  x3, x0, 7               /* resumes here */
  addi  x4, x0, 9
  HALT

/* ------------------------------------------------------------------ test 9
 * Illegal instruction (FENCE.I) traps with mcause=2 and mtval=encoding.
 * Expected: x6=2 x7=0x0000100f
 */
  .org 0xa00
test9:
  lui   x2, 0x0
  li    x2, 0x3f00
  csrw  0x305, x2
  csrw  0x343, x0
  .word 0x0000100f              /* FENCE.I: illegal in this CPU */
  li    x3, 99                  /* must be reached only via the handler */
  HALT

/* ----------------------------------------------------------------- test 10
 * Unmapped load -> cause 5 with mtval = faulting address.
 * Expected: x6=5 x7=0x70000000
 */
  .org 0xb00
test10:
  lui   x2, 0x0
  li    x2, 0x3f00
  csrw  0x305, x2
  csrw  0x343, x0
  lui   x4, 0x70000
  lw    x5, 0(x4)
  li    x3, 99
  HALT

/* ----------------------------------------------------------------- test 11
 * Unmapped store -> cause 7 with mtval = faulting address.
 * Expected: x6=7 x7=0x70000000
 */
  .org 0xc00
test11:
  lui   x2, 0x0
  li    x2, 0x3f00
  csrw  0x305, x2
  csrw  0x343, x0
  lui   x4, 0x70000
  sw    x4, 0(x4)
  li    x3, 99
  HALT

/* ----------------------------------------------------------------- test 12
 * UART: enable TX, then one write to TXDATA transmits exactly one character
 * ('A'). The TXDATA write is rejected with SLVERR while TX is disabled or the
 * transmitter is busy, so TX must be enabled first.
 * Expected: x2=0x41 and exactly one decoded UART character.
 */
  .org 0xd00
test12:
  lui   x1, 0x30000             /* 0x30000000 */
  li    x2, 3                   /* ctrl: TX enable | RX enable */
  sw    x2, 0(x1)
  li    x2, 0x41                /* 'A' */
  sw    x2, 12(x1)              /* TXDATA */
  HALT

/* ----------------------------------------------------------------- test 13
 * GPIO: output mode drives gpio_ctrl/gpio_data pins.
 * Expected: gpio_ctrl = 0x5, gpio_data = 0x2
 */
  .org 0xe00
test13:
  lui   x1, 0x40000             /* 0x40000000 */
  li    x2, 5                   /* ctrl[1:0] = 01 -> output */
  sw    x2, 0(x1)
  li    x3, 2
  sw    x3, 4(x1)
  HALT

/* ----------------------------------------------------------------- test 14
 * Timer one-shot: pending is set when the counter expires, W1C clears it.
 * Expected: x8 bit2 set, bit0 clear; x10 all zero.
 */
  .org 0xf00
test14:
  lui   x1, 0x20000             /* 0x20000000 */
  li    x2, 4
  sw    x2, 8(x1)               /* timer value = 4 */
  li    x3, 3                   /* enable | int enable */
  sw    x3, 0(x1)
  .rept 12
  nop
  .endr
  lw    x8, 0(x1)               /* ctrl: pending set, enable cleared */
  addi  x9, x8, 0
  sw    x9, 0(x1)               /* write back: W1C clears pending */
  lw    x10, 0(x1)
  HALT

/* ----------------------------------------------------------------- test 15
 * Machine timer interrupt through the real IRQ path:
 *   timer armed with int-enable -> irq_ctrl/mie/mstatus MIE -> trap with
 *   mcause = 0x80000007 -> handler records a flag in data RAM and clears the
 *   timer pending bit with W1C -> mret -> the main loop observes the flag.
 * Expected: x8 = 1 (flag observed) after exactly one machine-timer interrupt.
 */
  .org 0x1000
test15:
  li    x2, 0x3f00
  csrw  0x305, x2               /* mtvec = trap handler */
  lui   x4, 0x10000             /* flag word at 0x100000f0 */
  li    x5, 0xf0
  or    x4, x4, x5
  sw    x0, 0(x4)               /* flag = 0 */
  lui   x6, 0x20000             /* timer */
  li    x7, 300
  sw    x7, 8(x6)               /* timer value = 300 */
  li    x7, 3                   /* enable | int enable */
  sw    x7, 0(x6)
  li    x7, 0x80                /* mie.MTIE */
  csrw  0x304, x7
  li    x7, 8                   /* mstatus.MIE */
  csrw  0x300, x7
spin15:
  lw    x8, 0(x4)
  beq   x8, x0, spin15
  HALT

/* ----------------------------------------------------------------- test 16
 * WAW inside one issue pair: two independent ALU ops write the SAME rd.  They
 * may issue together because lane 1's sources do not depend on lane 0's result,
 * and in-order commit means the younger lane (lane 1) must win the register.
 * Expected: x20 = 13 (x7 + 2, lane 1), x21 = 13.
 */
  .org 0x1100
test16:
  li    x6, 3
  li    x7, 11
  addi  x20, x6, 1              /* lane 0: x20 = 4  (older, must be overwritten) */
  addi  x20, x7, 2              /* lane 1: x20 = 13 (younger, must win) */
  addi  x21, x20, 0             /* observe the surviving value */
  HALT

/* ----------------------------------------------------------------- test 17
 * RAW inside one issue pair: lane 1 consumes the register lane 0 produces in
 * the SAME cycle.  Lane 0 is ALU class, so its result is combinational and can
 * be forwarded straight into lane 1's operands (P37a).  Every pair below is
 * 8 B aligned so the two instructions really land in one fetch packet; the
 * expectations are generated by the Ref model, not by hand.
 */
  .org 0x1200
test17:
  li    x6, 7
  li    x7, 5
  .align 3
  addi  x20, x6, 9              /* lane 0: x20 = 16 */
  add   x21, x20, x7            /* lane 1: RAW on rs1 -> 21 */
  slli  x22, x21, 2             /* lane 0: x22 = 84 */
  xor   x23, x22, x6            /* lane 1: RAW on rs1 -> 83 */
  addi  x24, x0, -3             /* lane 0: x24 = -3 */
  sub   x25, x23, x24           /* lane 1: RAW on rs2 -> 86 */
  lui   x26, 0x12345            /* lane 0: x26 = 0x12345000 */
  srli  x27, x26, 4             /* lane 1: RAW on rs1 -> 0x1234500 */
  addi  x8, x25, 1              /* lane 0: x8 = 87 */
  bne   x8, x25, 1f             /* lane 1: RAW on rs1+rs2, taken -> wrong path killed */
  addi  x9, x0, 0x7ff           /* must be skipped */
1:
  addi  x10, x27, 0             /* observe x27 after the pair */
  HALT

/* New packet tests deliberately avoid .align relocations. The runner reads
 * linked test labels; .org values alone are not reliable after test17. */
  .org 0x1304
test18:
  lui   x10, 0x10000
  addi  x11, x0, 0x123
  addi  x12, x10, 64
  sw    x11, 0(x12)             /* lane1 RAW address */
  addi  x13, x0, -7
  sw    x13, 4(x12)             /* lane1 RAW store data */
  addi  x14, x0, 9
  lw    x15, 0(x12)             /* lane1 load */
  add   x16, x15, x14           /* next-packet load consumer */
  lw    x17, 4(x12)
  add   x18, x17, x16
  lbu   x19, 5(x12)
  add   x20, x19, x18
  lw    x0, 0(x12)              /* x0 discards data, not the memory access */
  HALT

  .org 0x1404
test19:
  li    x2, 0x3f00
  csrw  0x305, x2
  lui   x10, 0x70000
  addi  x20, x0, 77
  lw    x0, 0(x10)              /* lane1 access fault: older x20 survives */
  addi  x21, x20, 1
  addi  x22, x6, 0              /* preserve load fault cause */
  addi  x23, x0, 33
  sw    x23, 0(x10)             /* lane1 store fault */
  addi  x24, x23, 1
  HALT

  .org 0x1504
test20:
  li    x2, 0x3f00
  csrw  0x305, x2
  lui   x10, 0x10000
  addi  x20, x0, 91
  lw    x21, 1(x10)             /* lane1 misalignment must not issue LSU */
  addi  x22, x6, 0
  addi  x23, x20, 1
  addi  x24, x0, 35
  sh    x24, 1(x10)
  addi  x25, x24, 1
  HALT

/* ------------------------------------------------------------------ trap
 * Shared trap handler, linked into the .trap section at address 0x3f00 by
 * link.ld. It reads mepc/mcause/mtval into x5/x6/x7. Synchronous exceptions
 * advance mepc past the faulting instruction; machine-timer interrupts set the
 * flag word at 0x100000f0 and clear the timer pending bit (W1C) without
 * advancing mepc, then both paths mret. */
  .section .trap, "ax"
  .org 0
trap_handler:
  csrrs x5, 0x341, x0
  csrrs x6, 0x342, x0
  csrrs x7, 0x343, x0
  li    x28, 0x80000007
  beq   x6, x28, trap_irq
  addi  x28, x5, 4
  csrw  0x341, x28
  mret
trap_irq:
  lui   x29, 0x10000
  li    x30, 0xf0
  or    x29, x29, x30
  li    x30, 1
  sw    x30, 0(x29)             /* flag = 1 */
  lui   x29, 0x20000
  li    x30, 4                  /* W1C the timer pending bit */
  sw    x30, 0(x29)
  mret

  .section .text
  .end
