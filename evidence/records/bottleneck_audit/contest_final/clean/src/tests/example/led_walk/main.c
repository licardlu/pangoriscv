/*
 * led_walk - CPU (not RTL) one-hot walking pattern on the 8 board LEDs.
 *
 * Target: "pangoriscv AXI4" native SoC, RV32IM/ILP32, 27 MHz board clock.
 *   GPIO  0x40000000 : +0x0 CTRL, +0x4 DATA            (rtl/perips/axi_gpio.v)
 *   TIMER 0x20000000 : +0x0 CTRL, +0x8 VALUE           (rtl/perips/axi_timer.v)
 *   UART  0x30000000 : 115200 8N1                      (rtl/perips/axi_uart.v)
 *
 * LED wiring (rtl/soc/pangoriscv_top.v:29):
 *   led[i] = gpio_ctrl[2*i +: 2] == 2'b01 && gpio_data[i]
 * so CTRL must mark pins 0..7 as outputs and DATA[7:0] is the LED byte.
 * CTRL packs 2 bits per pin: 2'b01 = output, 2'b10 = input (axi_gpio.v:16,21,28),
 * hence CTRL = 0x00005555 for eight outputs. The walk itself is produced entirely
 * by the CPU: one store to DATA per step, no RTL counter or shift register.
 *
 * One step lights exactly one LED, walking led[0] -> led[7] and wrapping back to
 * led[0], so 8 steps are one full cycle. One ASCII UART line is printed after
 * each full cycle (once per cycle, not once per step: the line is 46 chars plus
 * CRLF = 47 bytes, so at 115200 8N1 it takes 47*10/115200 = ~4.1 ms, far inside
 * the 250 ms step period). That print is the only thing that perturbs the step
 * cadence: RTL simulation measured 6,750,114 cycles for a step that prints
 * nothing and 6,853,740 cycles for the step that ends the cycle (the extra
 * 103,626 cycles, ~3.8 ms, is uart_putc() blocking on UART0_STATUS while the
 * 47-byte line drains, consistent with 47*10*234 = 109,980). The wrap-around
 * step is therefore ~0.254 s instead of 0.250 s; every other step is 0.250 s.
 */

#include <stdint.h>

#include "../include/gpio.h"
#include "../include/timer.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

/* Eight pins, two CTRL bits each: 01 = output (rtl/perips/axi_gpio.v:16,21,28). */
#define LED_COUNT          8
#define LED_CTRL_OUTPUTS   0x00005555U

/* ---------------------------------------------------------------------------
 * Step period.
 *
 * rtl/perips/axi_timer.v:16 expires the counter as soon as
 *   timer_ctrl[0] && timer_count >= timer_value
 * L28-29 advances timer_count by one per 27 MHz clock only while that is false,
 * L34 makes timer_value writable at +0x8, and L35 clears timer_ctrl[0] and
 * raises the sticky flag timer_ctrl[2] on the expiring edge. One step therefore
 * lasts exactly timer_value 27 MHz cycles, no matter how many instructions the
 * wait loop needs:
 *
 *   period = STEP_TICKS / CPU_FREQ_HZ
 *          = (CPU_FREQ_HZ / 4 + 1) / CPU_FREQ_HZ
 *          = 6,750,001 / 27,000,000 s
 *          = 0.2500000 s               (inside the requested 0.2-0.5 s window)
 *
 * 0.25 s per step => 8 steps = 2 s per full walk cycle, i.e. one UART line every
 * ~2 s. Chosen over the extremes: 0.2 s makes the serial log busy and 0.5 s
 * (4 s per lap) makes the walk look like a blink, while 0.25 s keeps the one-hot
 * motion obviously "walking" and the log readable.
 *
 * Why the period is exact: the timer counts 27 MHz clocks, not instructions, so
 * the only software error is how late the polling loop notices CTRL[0] going
 * clear. That loop is three instructions per pass (`lw` + `andi` + `bnez` at
 * firmware.dump addresses 0xe4/0xe8/0xec, i.e. one 32-bit AXI read of the timer
 * register slave per pass); the AXI read costs far more than the instructions,
 * and RTL simulation of this image measured 767,401 timer-CTRL reads in
 * 27,000,019 cycles, i.e. 35 cycles per pass, or ~192,857 passes per step.
 * That simulation measured 6,750,114 cycles between consecutive GPIO DATA
 * stores. The ~113-cycle excess over 6,750,001 is the loop noticing the expiry
 * plus the per-step bookkeeping (one `sw`, one `addi`, one `bne`, one extra
 * VALUE/CTRL arming sequence) - about 17 ppm of the period, i.e. 0.25 s stays
 * 0.250004 s. It is the only timing dependency in the program: nothing else in
 * main() affects the walk rate.
 * ------------------------------------------------------------------------- */
/* Step period in milliseconds. 250 ms is the board default; the pre-board TB
 * (tb/integration/tb_led_walk.sv) builds a 1 ms variant with
 * `--define LED_WALK_STEP_MS=1` so a full 8-step walk plus the 10th change
 * (the normal stop condition of that TB) fits in a short RTL simulation. */
#ifndef LED_WALK_STEP_MS
#define LED_WALK_STEP_MS   250U
#endif
#define STEP_TICKS   ((CPU_FREQ_HZ / 1000U) * (uint32_t)LED_WALK_STEP_MS + 1U)  /* 250 -> 6,750,001, 1 -> 27,001 */

static void led_walk_delay_step(void)
{
    /* timer_value resets to 0 and is writable only at +0x8 (axi_timer.v:22,34).
     * Without this store "expired" would already be true on the first armed
     * clock, timer_count would stay 0, timer_ctrl[0] would clear immediately and
     * the wait below would never finish - the board would freeze on led[0]. */
    TIMER0_REG(TIMER0_VALUE) = STEP_TICKS;
    /* +0x0: bit 0 alone starts the counter. CTRL[1]/CTRL[2] stay clear, so no
     * interrupt is enabled and the sticky expired flag is cleared by this write
     * (axi_timer.v:32). */
    TIMER0_REG(TIMER0_CTRL) = 0x1U;
    /* Wait on CTRL[0], never on COUNT: timer_count equals timer_value for a
     * single clock (L29 zeroes it on the next edge), so a polling loop that
     * compares COUNT can race past that one-cycle window and then spin forever.
     * timer_ctrl[0] instead stays 1 for the whole interval and clears for good. */
    while (TIMER0_REG(TIMER0_CTRL) & 0x1U) {
        asm volatile ("" ::: "memory");
    }
}

int main(void)
{
    uint32_t led;

    uart_init();                        /* 115200 8N1 from CPU_FREQ_HZ */

    GPIO_REG(GPIO_CTRL) = LED_CTRL_OUTPUTS;   /* store to 0x40000000 */
    GPIO_REG(GPIO_DATA) = 0U;

    xprintf("led_walk: pangoriscv native AXI4, 27 MHz, one-hot LED walk\n");

    led = 0;

    for (;;) {
        GPIO_REG(GPIO_DATA) = (uint32_t)(1U << led);  /* store to 0x40000004 */

        led_walk_delay_step();

        led++;
        if (led == LED_COUNT) {
            led = 0;
            /* Once per full 8-step cycle. ASCII only, ~47 bytes at 115200 baud. */
            xprintf("led_walk: pangoriscv native AXI4 CPU, step %u\n", (unsigned)LED_COUNT);
        }
    }
}
