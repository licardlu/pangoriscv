/*
 * selftest - Stage-A board acceptance program for the native AXI4 CPU.
 *
 * Order follows the plan's board-test sequence: arithmetic signature ->
 * RAM test -> timer/CSR check -> fixed UART string -> GPIO change -> idle
 * heartbeat.  CoreMark performance/validation seeds are separate images.
 *
 * Everything printed is ASCII so a plain 115200 8N1 capture is the evidence.
 * Checks accumulate into one bitmask summarised once, so one failing item
 * cannot hide behind later output.
 */

#include <stdint.h>

#include "../include/gpio.h"
#include "../include/timer.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

#define FAIL_MUL       (1U << 0)
#define FAIL_DIV_REM   (1U << 1)
#define FAIL_DIV_ZERO  (1U << 2)
#define FAIL_SHIFT     (1U << 3)
#define FAIL_BRANCH    (1U << 4)
#define FAIL_RAM_WORD  (1U << 5)
#define FAIL_RAM_SUB   (1U << 6)
#define FAIL_RAM_ALIGN (1U << 7)
#define FAIL_TIMER     (1U << 8)
#define FAIL_CSR       (1U << 9)

static volatile uint32_t g_fail;

/* 4 KiB in .bss; link.lds gives 16 KiB data RAM, 8 KiB of it stack. */
static volatile uint32_t ram_area[1024];

#ifdef SIMULATION
#define STEP_TICKS    (CPU_FREQ_HZ / 1000U + 1U)   /* 1 ms */
#else
#define STEP_TICKS    (CPU_FREQ_HZ / 10U + 1U)     /* 100 ms */
#endif
#define WALK_STEPS    8U

static void check(uint32_t bit, uint32_t ok)
{
    if (!ok) g_fail |= bit;
}

/* One timer delay; returns the cycle-counter delta observed across it. */
static uint32_t timer_delay(uint32_t ticks)
{
    uint64_t t0 = get_cycle_value();
    TIMER0_REG(TIMER0_VALUE) = ticks;
    TIMER0_REG(TIMER0_CTRL)  = 0x1U;
    while (TIMER0_REG(TIMER0_CTRL) & 0x1U) {
        asm volatile ("" ::: "memory");
    }
    return (uint32_t)(get_cycle_value() - t0);
}

/* ---------------------------------------------------------------- 1) arith */
static void test_arith(void)
{
    volatile int32_t  sa = -100, sb = 7;
    volatile uint32_t ua = 0xFFFFFFFFU, ub = 3U;
    volatile uint32_t big = 0x12345678U;
    volatile int32_t  i32min = (int32_t)0x80000000;
    volatile int32_t  negone = -1;
    volatile int32_t  zero = 0;
    uint64_t hi;
    uint32_t r;

    /* M extension, low and both high halves. */
    r = big * 3U;
    check(FAIL_MUL, r == 0x369D0368U);
    hi = (uint64_t)0xFFFFFFFFU * 0xFFFFFFFFU;              /* mulhu */
    check(FAIL_MUL, (uint32_t)(hi >> 32) == 0xFFFFFFFEU);
    hi = (uint64_t)i32min * (int64_t)i32min;                /* mulh  */
    check(FAIL_MUL, (uint32_t)(hi >> 32) == 0x40000000U);
    hi = (uint64_t)(int64_t)negone * (uint64_t)0xFFFFFFFFU; /* mulhsu */
    check(FAIL_MUL, (uint32_t)(hi >> 32) == 0xFFFFFFFFU);

    /* Signed division truncates toward zero; remainder follows the dividend. */
    check(FAIL_DIV_REM, (uint32_t)(sa / sb) == (uint32_t)-14);
    check(FAIL_DIV_REM, (uint32_t)(sa % sb) == (uint32_t)-2);
    check(FAIL_DIV_REM, (uint32_t)(100 / -7) == (uint32_t)-14);
    check(FAIL_DIV_REM, (uint32_t)(100 % -7) == 2U);
    check(FAIL_DIV_REM, (uint32_t)(-100 / -7) == 14U);
    check(FAIL_DIV_REM, (uint32_t)(-100 % -7) == (uint32_t)-2);
    /* The same bit patterns divide differently when treated as unsigned. */
    check(FAIL_DIV_REM, (ua / ub) == 0x55555555U);
    check(FAIL_DIV_REM, (ua % ub) == 0U);
    /* RISC-V division by zero: quotient all ones, remainder the dividend.
     * The divisor is volatile so the compiler must emit a real DIV/REM
     * instruction; a constant 0 would be folded away at compile time. */
    check(FAIL_DIV_ZERO, (uint32_t)(100 / zero) == 0xFFFFFFFFU);
    check(FAIL_DIV_ZERO, (uint32_t)(100 % zero) == 100U);
    check(FAIL_DIV_ZERO, (uint32_t)(i32min / zero) == 0xFFFFFFFFU);
    check(FAIL_DIV_ZERO, (uint32_t)(i32min / negone) == 0x80000000U);

    /* Shifts: logical for unsigned values, arithmetic for signed ones. */
    check(FAIL_SHIFT, (uint32_t)(big << 13) == 0x8ACF0000U);
    check(FAIL_SHIFT, (ua >> 17) == 0x00007FFFU);
    check(FAIL_SHIFT, (uint32_t)(i32min >> 31) == 0xFFFFFFFFU);
    check(FAIL_SHIFT, (uint32_t)((int32_t)-8 >> 1) == 0xFFFFFFFCU);
}

/* Branch exercise with a trivially checkable result instead of a checksum. */
static uint32_t branch_mix(uint32_t n)
{
    uint32_t i, taken = 0, not_taken = 0;
    for (i = 0; i < n; i++) {
        if (i & 1U) {
            taken++;
        } else {
            not_taken++;
        }
    }
    return (taken << 16) | not_taken;
}

static void test_branch(void)
{
    volatile uint32_t n = 64U;
    check(FAIL_BRANCH, branch_mix(n) == 0x00200020U);
    check(FAIL_BRANCH, (0U < 1U) && ((int32_t)-1 < 0) && (0x80000000U > 0x7FFFFFFFU));
    /* Backward-branch loop count: exactly 100 iterations. */
    {
        volatile uint32_t i = 0, count = 0;
        while (i < 100U) {
            i++;
            count++;
        }
        check(FAIL_BRANCH, count == 100U);
    }
}

/* ------------------------------------------------------------------ 2) RAM */
static void test_ram(void)
{
    uint32_t i;

    /* Walking one over every word: catches stuck or shorted address/data bits. */
    for (i = 0; i < 1024U; i++) {
        ram_area[i] = 1U << (i & 31U);
    }
    for (i = 0; i < 1024U; i++) {
        if (ram_area[i] != (1U << (i & 31U))) {
            g_fail |= FAIL_RAM_WORD;
            break;
        }
    }
    /* Address-dependent pattern, verified in reverse order. */
    for (i = 0; i < 1024U; i++) {
        ram_area[i] = (i * 2654435761U) ^ 0xA5A5A5A5U;
    }
    for (i = 1024U; i-- > 0U;) {
        if (ram_area[i] != ((i * 2654435761U) ^ 0xA5A5A5A5U)) {
            g_fail |= FAIL_RAM_WORD;
            break;
        }
    }
    /* Byte and halfword lanes at every offset inside a word. */
    for (i = 0; i < 1024U; i++) {
        ram_area[i] = 0xFFFFFFFFU;
    }
    for (i = 0; i < 1024U; i++) {
        volatile uint8_t  *p8  = (volatile uint8_t *)(ram_area + i);
        volatile uint16_t *p16 = (volatile uint16_t *)(ram_area + i);
        p8[0] = (uint8_t)i;           p8[1] = (uint8_t)(i + 1U);
        p8[2] = (uint8_t)(i + 2U);    p8[3] = (uint8_t)(i + 3U);
        if (p8[0] != (uint8_t)i || p8[1] != (uint8_t)(i + 1U) ||
            p8[2] != (uint8_t)(i + 2U) || p8[3] != (uint8_t)(i + 3U)) {
            g_fail |= FAIL_RAM_SUB;
            break;
        }
        p16[0] = (uint16_t)(i * 3U);
        p16[1] = (uint16_t)(i * 5U);
        if (p16[0] != (uint16_t)(i * 3U) || p16[1] != (uint16_t)(i * 5U)) {
            g_fail |= FAIL_RAM_SUB;
            break;
        }
    }
    /* Neighbouring bytes must keep their own values at a word boundary. */
    for (i = 0; i < 1024U; i++) {
        ram_area[i] = 0U;
    }
    for (i = 0; i + 1U < 1024U; i++) {
        volatile uint8_t *p8 = (volatile uint8_t *)(ram_area + i);
        p8[3] = 0x5AU;                       /* last byte of word i   */
        p8[4] = 0xA5U;                       /* first byte of word i+1 */
        if (p8[3] != 0x5AU || p8[4] != 0xA5U) {
            g_fail |= FAIL_RAM_ALIGN;
            break;
        }
        ram_area[i] = 0U;
        ram_area[i + 1U] = 0U;
    }
}

/* --------------------------------------------------------- 3) timer / CSR  */
static void test_timer_csr(void)
{
    uint32_t d = timer_delay(STEP_TICKS);

    /* rtl/perips/axi_timer.v:16-29 expires the counter after exactly timer_value
     * cycles (timer_count >= timer_value clears timer_ctrl[0]), so the interval
     * itself is exact. The measured delta additionally contains the exit latency
     * of the poll loop - one MMIO read of CTRL plus the ~9-cycle fetch of the
     * loop body - hence the overshoot allowance. 512 cycles is 0.019 % of the
     * 2.7 M-cycle (100 ms) interval; the value is printed so the margin is
     * auditable rather than hidden. */
    xprintf("SELFTEST timer: delta=%u expect=%u\n", (unsigned)d, (unsigned)STEP_TICKS);
    check(FAIL_TIMER, d >= STEP_TICKS && d <= STEP_TICKS + 512U);
    /* Nothing in this program may take a trap. */
    check(FAIL_CSR, (uint32_t)read_csr(mcause) == 0U);
    check(FAIL_CSR, (uint32_t)read_csr(mepc) == 0U);
    /* init.c must have left global interrupts disabled in mstatus.MIE (bit 3). */
    check(FAIL_CSR, ((uint32_t)read_csr(mstatus) & 0x8U) == 0U);
}

/* ---------------------------------------------------------------- 4) UART   */
static void test_uart(void)
{
    xprintf("SELFTEST uart: fixed string line 1/3\n");
    xprintf("SELFTEST uart: the quick brown fox jumps over the lazy dog 0123456789\n");
    xprintf("SELFTEST uart: fixed string line 2/3\n");
    xprintf("SELFTEST uart: !\"#$%%&'()*+,-./:;<=>?@[\\]^_`{|}~ 0123456789\n");
    xprintf("SELFTEST uart: fixed string line 3/3\n");
}

/* ---------------------------------------------------------------- 5) GPIO   */
static void test_gpio(void)
{
    uint32_t key, step;

    /* pin0 = input (2'b10), pins1..7 = output (2'b01) -> CTRL = 0x5556.
     * pango_native_top.v:86 drives gpio_input = {1'b1, key}. */
    GPIO_REG(GPIO_CTRL) = 0x00005556U;
    key = GPIO_REG(GPIO_DATA) & 0x1U;
    xprintf("SELFTEST gpio: key bit = %u (0 = pressed)\n", (unsigned)key);

    /* All eight pins as outputs: CTRL = 0x5555 (2'b01 per pin). */
    GPIO_REG(GPIO_CTRL) = 0x00005555U;
    for (step = 0; step < WALK_STEPS; step++) {
        GPIO_REG(GPIO_DATA) = 1U << step;
        timer_delay(STEP_TICKS);
    }
    GPIO_REG(GPIO_DATA) = 0U;
    xprintf("SELFTEST gpio: one-hot walk over %u LEDs done\n", (unsigned)WALK_STEPS);
}

int main(void)
{
    uint32_t beat = 0;

    uart_init();
    GPIO_REG(GPIO_CTRL) = 0x00005555U;
    GPIO_REG(GPIO_DATA) = 0U;

    xprintf("\nSELFTEST start cpu_mhz=%u\n", (unsigned)CPU_FREQ_MHZ);

    test_arith();
    test_branch();
    xprintf("SELFTEST arith done fail=%u\n", (unsigned)g_fail);
    test_ram();
    xprintf("SELFTEST ram done fail=%u\n", (unsigned)g_fail);
    test_timer_csr();
    xprintf("SELFTEST timer_csr done fail=%u\n", (unsigned)g_fail);
    test_uart();
    test_gpio();

    if (g_fail == 0U) {
        xprintf("SELFTEST PASS\n");
    } else {
        xprintf("SELFTEST FAIL mask=%u\n", (unsigned)g_fail);
    }

    /* Idle heartbeat: proves the core keeps executing and gives the board LEDs
     * a slowly changing, visible pattern. */
    for (;;) {
        GPIO_REG(GPIO_DATA) = 0x01U;
        timer_delay(STEP_TICKS);
        GPIO_REG(GPIO_DATA) = 0x80U;
        timer_delay(STEP_TICKS);
        beat++;
        xprintf("HEARTBEAT n=%u fail=%u\n", (unsigned)beat, (unsigned)g_fail);
    }
}
