    .section .init
    .globl _start
_start:
    li s0, 0x10003100
    .option push
    .option arch,+zicsr
    csrr t0, mcycle
    nop
    nop
    csrr t1, mcycle
    .option pop
    sub t1, t1, t0
    beqz t1, failed
    lw t0, 12(s0)
    li t1, 0x10000
    bne t0, t1, failed
    li t0, 8
    sw t0, 16(s0)
    sw t0, 20(s0)
    li t0, 1
    sw t0, 24(s0)
    sw t0, 28(s0)
    sw t0, 32(s0)
    sw t0, 36(s0)
    sw t0, 40(s0)
    sw t0, 44(s0)
    sw zero, 48(s0)
    sw zero, 52(s0)
    sw t0, 56(s0)
    li t0, 15
    sw t0, 60(s0)
    sw zero, 64(s0)
    li t0, 0x100
    sw t0, 68(s0)
    li t0, 0x200
    sw t0, 72(s0)
    sw zero, 76(s0)
    li t0, 0x300
    sw t0, 80(s0)
    fence iorw,iorw
    li t0, 1
    sw t0, 0(s0)
    li t2, 10000
poll:
    lw t0, 4(s0)
    andi t1, t0, 4
    bnez t1, failed
    andi t1, t0, 2
    bnez t1, readback
    addi t2, t2, -1
    bnez t2, poll
    j failed
readback:
    li t0, 0x300
    sw t0, 96(s0)
    li t0, 1
    sw t0, 100(s0)
    li t2, 10000
readpoll:
    lw t0, 100(s0)
    andi t1, t0, 4
    bnez t1, failed
    andi t1, t0, 2
    bnez t1, compare
    addi t2, t2, -1
    bnez t2, readpoll
    j failed
compare:
    li t1, 0x08070605
    lw t0, 104(s0)
    bne t0, t1, failed
    li t1, 0x0c0b0a09
    lw t0, 108(s0)
    bne t0, t1, failed
    li t0, 0x600d
    sw t0, 252(s0)
1:  j 1b
failed:
    li t0, 0xbad
    sw t0, 252(s0)
2:  j 2b
