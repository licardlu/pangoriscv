    .section .init
    .globl _start
_start:
    li t0, 0x1000310c
    lw t1, 0(t0)
    li t2, 0x00010000
    bne t1, t2, failed
    li t0, 0x10003110
    li t1, 40
    sw t1, 0(t0)
    fence iorw,iorw
    li t0, 0x10001004
    lw t1, 0(t0)
    li t0, 0x1000310c
    lw t1, 0(t0)
    bne t1, t2, failed
    li t0, 0x10003114
    li t1, 0x600d
    sw t1, 0(t0)
1:  j 1b
failed:
    li t0, 0x10003114
    li t1, 0xbad
    sw t1, 0(t0)
2:  j 2b
