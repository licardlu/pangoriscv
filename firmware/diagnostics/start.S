.section .text.init,"ax"
.option norvc
.globl _start
_start:
  .option push
  .option norelax
  la gp,__global_pointer$
  .option pop
  la sp,_stack_top
  csrw mie,zero
  csrw mstatus,zero
  la t0,diag_trap_entry
  csrw mtvec,t0
  la t0,_bss_start
  la t1,_bss_end
1: bgeu t0,t1,2f
  sw zero,0(t0)
  addi t0,t0,4
  j 1b
2: fence.i
  call main
3: j 3b

.balign 4
// Machine traps use the interrupted stack. No nesting; preserve every GPR.
// The 128-byte frame preserves the ABI's 16-byte stack alignment.
diag_trap_entry:
  addi sp,sp,-128
  sw ra,4(sp)
  sw gp,12(sp)
  sw tp,16(sp)
  sw t0,20(sp)
  sw t1,24(sp)
  sw t2,28(sp)
  sw s0,32(sp)
  sw s1,36(sp)
  sw a0,40(sp)
  sw a1,44(sp)
  sw a2,48(sp)
  sw a3,52(sp)
  sw a4,56(sp)
  sw a5,60(sp)
  sw a6,64(sp)
  sw a7,68(sp)
  sw s2,72(sp)
  sw s3,76(sp)
  sw s4,80(sp)
  sw s5,84(sp)
  sw s6,88(sp)
  sw s7,92(sp)
  sw s8,96(sp)
  sw s9,100(sp)
  sw s10,104(sp)
  sw s11,108(sp)
  sw t3,112(sp)
  sw t4,116(sp)
  sw t5,120(sp)
  sw t6,124(sp)
  addi t0,sp,128
  sw t0,8(sp)
  csrr a0,mcause
  csrr a1,mepc
  csrr a2,mtval
  call diag_trap
  csrw mepc,a0
  lw ra,4(sp)
  lw gp,12(sp)
  lw tp,16(sp)
  lw t0,20(sp)
  lw t1,24(sp)
  lw t2,28(sp)
  lw s0,32(sp)
  lw s1,36(sp)
  lw a0,40(sp)
  lw a1,44(sp)
  lw a2,48(sp)
  lw a3,52(sp)
  lw a4,56(sp)
  lw a5,60(sp)
  lw a6,64(sp)
  lw a7,68(sp)
  lw s2,72(sp)
  lw s3,76(sp)
  lw s4,80(sp)
  lw s5,84(sp)
  lw s6,88(sp)
  lw s7,92(sp)
  lw s8,96(sp)
  lw s9,100(sp)
  lw s10,104(sp)
  lw s11,108(sp)
  lw t3,112(sp)
  lw t4,116(sp)
  lw t5,120(sp)
  lw t6,124(sp)
  addi sp,sp,128
  mret

// Live caller-saved sentinels detect incomplete ISR save/restore.
.globl probe_illegal
probe_illegal:
  li t0,0x12345678
  li t1,0x76543210
  li a0,0x13579bdf
  li t6,0x2468ace0
.globl illegal_pc
illegal_pc:
  .word 0xffffffff
  li t2,0x12345678
  bne t0,t2,probe_fail
  li t2,0x76543210
  bne t1,t2,probe_fail
  li t2,0x13579bdf
  bne a0,t2,probe_fail
  li t2,0x2468ace0
  bne t6,t2,probe_fail
  li a0,0
  ret
.globl probe_ecall
probe_ecall:
  li t0,0x12345678
  li t1,0x76543210
  li a0,0x13579bdf
  li t6,0x2468ace0
.globl ecall_pc
ecall_pc:
  ecall
  li t2,0x12345678
  bne t0,t2,probe_fail
  li t2,0x76543210
  bne t1,t2,probe_fail
  li t2,0x13579bdf
  bne a0,t2,probe_fail
  li t2,0x2468ace0
  bne t6,t2,probe_fail
  li a0,0
  ret
.globl probe_timer
probe_timer:
  li t0,0x12345678
  li t1,0x76543210
  li a0,0x13579bdf
  li t6,0x2468ace0
.globl timer_begin
timer_begin:
  li t3,128
  csrs mie,t3
  li t3,8
  csrs mstatus,t3
  la t2,timer_hits
  li t3,200000
4: lw t4,0(t2)
  bnez t4,5f
  addi t3,t3,-1
  bnez t3,4b
  j probe_fail
5:
.globl timer_end
timer_end:
  li t2,0x12345678
  bne t0,t2,probe_fail
  li t2,0x76543210
  bne t1,t2,probe_fail
  li t2,0x13579bdf
  bne a0,t2,probe_fail
  li t2,0x2468ace0
  bne t6,t2,probe_fail
  li a0,0
  ret
probe_fail:
  li a0,1
  ret

