/*
 * gpio_trace - CPU-side input polling with post-acquisition UART reporting.
 *
 * Requirement reference (contest plan, trace section 32.2):
 *   "小应用 tests/example/gpio_trace/main.c，CPU 轮询输入位，检测变化后记录 cycle
 *    时间与输入值并翻转输出位，UART 输出放在采集结束后（避免发送耗时污染采样）；
 *    记录缓冲固定 64 项放数据 RAM，每项 uint64_t ticks + uint32_t pins，用 sizeof
 *    核验容量，不假设 12 字节；仿真先注入 8 次相隔 100 周期的输入变化，输出 8 条
 *    单调时间戳。"
 *
 * Target: "pangoriscv AXI4" native SoC, RV32IM/ILP32, 27 MHz board clock.
 *
 *   GPIO 0x40000000 : +0x0 CTRL, +0x4 DATA          (rtl/perips/axi_gpio.v)
 *     CTRL packs 2 bits per pin: 2'b01 = output, 2'b10 = input (axi_gpio.v:16,21,28).
 *     While CTRL[2*i +: 2] == 2'b10 the DATA[i] bit is refreshed every clock from the
 *     two-stage synchroniser sync0/sync1 (axi_gpio.v:14,27,30-31); while it is 2'b01
 *     DATA[i] is the value the CPU drives.  DATA is the only readable pin state, so
 *     one load per poll iteration is enough.
 *   Board wiring (rtl/soc/pangoriscv_top.v:86): .gpio_input({1'b1,key})
 *     -> pin 0 is the KEY button (active low: pressed reads 0), pin 1 is tied to 1'b1.
 *   LED wiring (rtl/soc/pangoriscv_top.v:28-29):
 *     led[i] = soc_rst_n && gpio_ctrl[2*i +: 2] == 2'b01 && gpio_data[i]
 *     -> pin 1 drives led[1]; configured as an output it is the "output bit" this app
 *        flips on every detected input change (one store to GPIO DATA per change).
 *   UART 0x30000000 : 115200 8N1                    (rtl/perips/axi_uart.v)
 *
 * Timing contract, and why the UART is silent during acquisition:
 *   uart_putc() blocks on UART0_STATUS while the 8N1 shifter drains one byte, i.e.
 *   10 bit times at 115200 baud = 10 * 234 = 2340 27 MHz cycles per character
 *   (lib/uart.c:11-12, and the divisor written in lib/uart.c:31 is CPU_FREQ_HZ/115200
 *   = 234).  A single 40-character report line therefore costs ~94k cycles, three
 *   orders of magnitude more than the polling loop itself.  All reporting is hence
 *   done after the acquisition window closes, never inside it: the plan's
 *   "UART 输出放在采集结束后（避免发送耗时污染采样）".
 *
 * Record buffer: fixed 64 entries, 8-byte aligned (uint64_t ticks + uint32_t pins
 * occupies 16 bytes on RV32 ILP32 because uint64_t has 8-byte alignment, NOT the
 * 12 bytes a naive sum of the members suggests).  The capacity is derived from
 * sizeof in TRACE_CAPACITY/TRACE_ENTRY_BYTES below and the build fails if the layout
 * stops matching 64 entries, so nothing here assumes a 12-byte entry.
 *
 * Two knobs exist for the simulation testbench (tb/integration/tb_gpio_trace.sv),
 * which injects 8 KEY transitions 100 cycles apart and expects 8 monotone stamps:
 *   -DTRACE_STOP_COUNT=8  stop as soon as 8 changes were captured (default: buffer full)
 *   -DTRACE_WINDOW_MS=5   acquisition window in ms (default 5000, i.e. 5 s on the board)
 * On the board the defaults apply: up to 64 key edges, or one 5 s window per run.
 */

#include <stdint.h>

#include "../include/gpio.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

/* ---------------------------------------------------------------------------
 * GPIO configuration
 *
 * CTRL[1:0]   = 2'b10 -> pin 0 (KEY) is an input, DATA[0] follows the synchronised
 *                        button state (axi_gpio.v:30).
 * CTRL[3:2]   = 2'b01 -> pin 1 is an output (led[1] on the board), DATA[1] is ours.
 * --------------------------------------------------------------------------- */
#define GPIO_CTRL_TRACE     0x00000006U     /* 2'b01 << 2 | 2'b10 */
#define GPIO_PIN_MASK       0x00000003U     /* the two pin bits of DATA              */
#define GPIO_KEY_BIT        0x00000001U     /* DATA[0] = KEY (0 = pressed)           */
#define GPIO_LED_BIT        0x00000002U     /* DATA[1] = led[1], flipped per change  */

/* ---------------------------------------------------------------------------
 * Record buffer: 64 entries of { uint64_t ticks; uint32_t pins; }
 * --------------------------------------------------------------------------- */
#define TRACE_CAPACITY_FIXED 64u

struct gpio_trace_entry {
    uint64_t ticks;     /* 27 MHz cycle counter at the detected change (CSR cycle/cycleh) */
    uint32_t pins;      /* GPIO DATA pin bits at that instant: bit0 = KEY, bit1 = led[1]  */
};

static struct gpio_trace_entry trace[TRACE_CAPACITY_FIXED];

#define TRACE_ENTRY_BYTES ((unsigned)sizeof(trace[0]))
#define TRACE_BYTES       ((unsigned)sizeof(trace))
#define TRACE_CAPACITY    ((unsigned)(sizeof(trace) / sizeof(trace[0])))

/* sizeof-based capacity check: exactly 64 usable entries, and the whole buffer is a
 * whole number of entries (no hidden padding between records).  A negative array size
 * is a hard compile error, so a future layout change cannot silently shrink the log. */
typedef char gpio_trace_capacity_check[(TRACE_CAPACITY == TRACE_CAPACITY_FIXED) ? 1 : -1];
typedef char gpio_trace_entry_check[((TRACE_BYTES % TRACE_ENTRY_BYTES) == 0u) ? 1 : -1];

/* ---------------------------------------------------------------------------
 * Acquisition window and stop condition
 * --------------------------------------------------------------------------- */
#ifndef TRACE_WINDOW_MS
#define TRACE_WINDOW_MS 5000u       /* board default: one 5 s window per report */
#endif
#ifndef TRACE_STOP_COUNT
#define TRACE_STOP_COUNT TRACE_CAPACITY_FIXED   /* board default: stop when the log is full */
#endif

#define TRACE_WINDOW_TICKS ((uint64_t)TRACE_WINDOW_MS * (uint64_t)CPU_FREQ_MHZ * 1000u)

/* The 64-bit clock read (two CSRs plus the wrap retry in get_cycle_value()) is far
 * more expensive than the single GPIO load that the poll loop needs, so the deadline
 * is only re-read every 32 polls.  With a poll of a handful of cycles this keeps the
 * sampling interval at a few tens of cycles, still ~1/50 of a KEY bounce width and
 * well inside the 100-cycle spacing the simulation injects. */
#define TRACE_DEADLINE_MASK 0x1Fu

int main(void)
{
    unsigned run = 0;

    uart_init();

    /* pin 0 = KEY input, pin 1 = led[1] output (see the header comment).  DATA is
     * left alone: the input bit is refreshed by hardware every cycle. */
    GPIO_REG(GPIO_CTRL) = GPIO_CTRL_TRACE;

    for (;;) {
        unsigned n = 0, polls = 0, toggles = 0, i;
        uint32_t prev = GPIO_REG(GPIO_DATA) & GPIO_PIN_MASK;
        uint32_t led = 0;
        uint64_t start, deadline;
        uint64_t min_delta = 0, max_delta = 0;
        int mono = 1, expired = 0;

        start = get_cycle_value();
        deadline = start + TRACE_WINDOW_TICKS;

        /* ---------------- acquisition: polling only, no UART traffic ------------- */
        do {
            uint32_t data = GPIO_REG(GPIO_DATA);
            uint32_t pins = data & GPIO_PIN_MASK;

            if (pins != prev) {
                prev = pins;
                trace[n].ticks = get_cycle_value();
                trace[n].pins = pins;
                n++;
                led ^= GPIO_LED_BIT;
                GPIO_REG(GPIO_DATA) = led;      /* flip the output bit on every change */
                toggles++;
            }

            polls++;
            if ((polls & TRACE_DEADLINE_MASK) == 0u) {
                if ((int64_t)(get_cycle_value() - deadline) >= 0) {
                    expired = 1;
                    break;
                }
            }
        } while (n < TRACE_STOP_COUNT);

        /* ---------------- reporting: only after the window closed ----------------- */
        for (i = 0; i < n; i++) {
            uint64_t delta = (i == 0) ? 0u : (trace[i].ticks - trace[i - 1].ticks);

            if (i > 0) {
                if (delta == 0u) mono = 0;
                if (min_delta == 0u || delta < min_delta) min_delta = delta;
                if (delta > max_delta) max_delta = delta;
            }
            xprintf("TRACE i=%u hi=%u lo=%u pins=%u delta=%u\n",
                    (unsigned)i, (unsigned)(trace[i].ticks >> 32),
                    (unsigned)(trace[i].ticks & 0xffffffffu),
                    (unsigned)trace[i].pins, (unsigned)delta);
        }

        run++;
        xprintf("TRACE_DONE run=%u count=%u capacity=%u entry_bytes=%u bytes=%u "
                "stop_count=%u mono=%u toggles=%u min_delta=%u max_delta=%u "
                "window_ms=%u expired=%u polls=%u\n",
                (unsigned)run, (unsigned)n, (unsigned)TRACE_CAPACITY,
                (unsigned)TRACE_ENTRY_BYTES, (unsigned)TRACE_BYTES,
                (unsigned)TRACE_STOP_COUNT, (unsigned)mono, (unsigned)toggles,
                (unsigned)min_delta, (unsigned)max_delta,
                (unsigned)TRACE_WINDOW_MS, (unsigned)expired, (unsigned)polls);

        /* IDLE = the window closed with no input change (board, button untouched);
         * PASS = at least one change and strictly increasing timestamps. */
        xprintf("GPIO_TRACE %s run=%u count=%u\n",
                (n == 0u) ? "IDLE" : (mono ? "PASS" : "FAIL"),
                (unsigned)run, (unsigned)n);
    }
}
