#include <stdint.h>

#include "../include/uart.h"
#include "../include/utils.h"
#include "../include/xprintf.h"


// send one char to uart
void uart_putc(uint8_t c)
{
    while (UART0_REG(UART0_STATUS) & 0x1);
    UART0_REG(UART0_TXDATA) = c;
}

// Block, get one char from uart.
uint8_t uart_getc()
{
    UART0_REG(UART0_STATUS) &= ~0x2;
    while (!(UART0_REG(UART0_STATUS) & 0x2));
    return (UART0_REG(UART0_RXDATA) & 0xff);
}

// 115200bps, 8 N 1
void uart_init()
{
    // Program the baud divider from the single board-frequency constant so the port
    // follows the real 27 MHz board clock instead of the hardware reset default.
    // 27e6/115200 = 234 (24 MHz would need 208, the vendor demo uses 234 for 27 MHz).
    // With CPU_FREQ_MHZ = 27 this equals the axi_uart reset value, so it is a
    // belt-and-braces write; it keeps the value correct if the build frequency changes.
    UART0_REG(UART0_BAUD) = (CPU_FREQ_HZ / 115200U);

    // enable tx and rx
    UART0_REG(UART0_CTRL) = 0x3;

    xdev_out(uart_putc);
}
