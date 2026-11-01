/* Busy program for the halt / reset drain regression.
 *
 * It issues a continuous stream of loads and stores to data RAM so that a
 * halt request or a reset can be injected while a real AXI transaction is in
 * flight. The program never terminates by itself; the testbench decides when
 * to stop.
 */
    .section .text
    .globl _start

_start:
    lui   x5, 0x10000          /* x5 = 0x10000000 (data RAM) */
    addi  x5, x5, 0x200        /* x5 = 0x10000200 */
    li    x6, 0                /* loop counter */
    li    x9, 0x5a5a1234       /* halt signature, unused here */

1:
    lw    x7, 0(x5)            /* in-flight read from data RAM */
    addi  x6, x6, 1
    sw    x6, 0(x5)            /* in-flight store to data RAM */
    lw    x8, 0(x5)            /* load-use on the store result */
    sw    x8, 4(x5)
    j     1b
