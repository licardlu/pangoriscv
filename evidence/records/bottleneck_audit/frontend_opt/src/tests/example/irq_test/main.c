/*
 * irq_test -- N12 directed machine-mode interrupt self-test (board + simulation).
 *
 * Purpose: produce UART evidence that the machine-mode trap path
 *          (rtl/core/csr_native.v + rtl/core/retire_ctrl.v + trap_entry.S +
 *           trap_handler.c) really takes, dispatches, acknowledges and returns
 *          from every interrupt class the contest plan requires, and that it
 *          keeps the architectural promises around them.
 *
 * Evidence format (one ASCII line per check):
 *     IRQTEST T<n> PASS
 *     IRQTEST T<n> FAIL extra=.. cause=.. epc=.. tval=.. count=..
 *     IRQTEST T9 SKIP no key press observed
 *     IRQTEST DONE pass=<n> fail=<n>
 *
 * RTL facts this program relies on (all read from the sources, none assumed):
 *   - irq ctrl 0x60003000: +0x00 SW pending (RW/W1C), +0x04 EXT pending (W1C),
 *     +0x08 EXT enable (RW)                       (rtl/perips/irq_ctrl.v)
 *   - timer   0x20000000: +0x00 CTRL (bit0 run, bit1 irq enable, bit2 pending,
 *     write 1 to bit2 clears it), +0x04 COUNT, +0x08 VALUE
 *                                                 (rtl/perips/axi_timer.v)
 *   - external source = KEY1: pango_native_top.v:89 `.ext_event({1'b0,~key})`
 *   - gpio 0x40000000: +0x00 CTRL (2 bits per pin), +0x04 DATA; pin0 is the
 *     key input (pango_native_top.v:86 `{1'b1,key}`)
 *   - cause codes: 3 = M software, 7 = M timer, 11 = M external (csr_native.v)
 *   - program RAM is 16 KiB at 0x0, so a valid interrupted PC is < 0x4000.
 */
#include <stdint.h>

#include "../include/timer.h"
#include "../include/gpio.h"
#include "../include/irq.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

#define CAUSE_M_SOFTWARE  0x80000003u
#define CAUSE_M_TIMER     0x80000007u
#define CAUSE_M_EXTERNAL  0x8000000Bu
#define PROG_RAM_LIMIT    0x00004000u

static volatile uint32_t irq_count;
static volatile uint32_t last_cause, last_epc, last_tval;
static volatile uint32_t sentinel_bad;
static uint32_t pass_n, fail_n;

/* ------------------------------------------------------------------ helpers */
static void mstatus_set_mie(void) { write_csr(mstatus, read_csr(mstatus) | MSTATUS_MIE); }
static void mstatus_clr_mie(void) { write_csr(mstatus, read_csr(mstatus) & ~MSTATUS_MIE); }

static void spin_cycles(uint32_t n)
{
    uint64_t t0 = get_cycle_value();
    while ((get_cycle_value() - t0) < (uint64_t)n) { }
}

static void wait_irq(uint32_t cycles)
{
    uint64_t t0 = get_cycle_value();
    while (irq_count == 0u && (get_cycle_value() - t0) < (uint64_t)cycles) { }
}

static void reset_state(void)
{
    irq_count = 0u; last_cause = 0u; last_epc = 0u; last_tval = 0u;
}

static void checkpoint(uint32_t t, int ok, uint32_t extra)
{
    if (ok) {
        pass_n++;
        xprintf("IRQTEST T%u PASS\n", (unsigned)t);
    } else {
        fail_n++;
        xprintf("IRQTEST T%u FAIL extra=0x%x cause=0x%x epc=0x%x tval=0x%x count=%u\n",
                (unsigned)t, (unsigned)extra, (unsigned)last_cause,
                (unsigned)last_epc, (unsigned)last_tval, (unsigned)irq_count);
    }
}

/* Drop global enable + every source enable, and clear latched pending bits. */
static void disarm_all(void)
{
    mstatus_clr_mie();
    write_csr(mie, 0u);
    TIMER0_REG(TIMER0_CTRL) = 0x04u;        /* W1C timer pending */
    IRQ_REG(IRQ_SOFTWARE) = 1u;             /* W1C software pending */
    IRQ_REG(IRQ_EXTERNAL_PENDING) = 1u;     /* W1C external pending */
}

/* ------------------------------ interrupt handlers (override weak symbols) */
void timer0_irq_handler(void)
{
    last_cause = read_csr(mcause);
    last_epc   = read_csr(mepc);
    last_tval  = read_csr(0x343u);
    irq_count++;
    TIMER0_REG(TIMER0_CTRL) = 0x04u;        /* ack: clear pending, stay stopped */
}

void software_irq_handler(void)
{
    last_cause = read_csr(mcause);
    last_epc   = read_csr(mepc);
    last_tval  = read_csr(0x343u);
    irq_count++;
    IRQ_REG(IRQ_SOFTWARE) = 1u;             /* W1C */
}

void external_irq_handler(void)
{
    last_cause = read_csr(mcause);
    last_epc   = read_csr(mepc);
    last_tval  = read_csr(0x343u);
    irq_count++;
    IRQ_REG(IRQ_EXTERNAL_PENDING) = 1u;     /* W1C */
}

/* --------------------------------------------------------------- T1..T9 ---- */
/* T1: a single machine timer interrupt: right cause, zero mtval, and an
 *     interrupted PC that really lies inside the program RAM. */
static void t1_timer_once(void)
{
    reset_state(); disarm_all();
    TIMER0_REG(TIMER0_VALUE) = 2000u;
    TIMER0_REG(TIMER0_CTRL)  = 0x07u;       /* irq enable + run */
    write_csr(mie, MIE_MTIE);
    mstatus_set_mie();
    wait_irq(200000u);
    mstatus_clr_mie();
    int ok = (irq_count == 1u) && (last_cause == CAUSE_M_TIMER) &&
             (last_tval == 0u) && (last_epc != 0u) && (last_epc < PROG_RAM_LIMIT);
    checkpoint(1u, ok, last_epc);
}

/* T2: five consecutive one-shot interrupts, each with fresh VALUE. */
static void t2_timer_repeat(void)
{
    uint32_t i; int ok = 1;
    disarm_all();
    write_csr(mie, MIE_MTIE);
    mstatus_set_mie();
    for (i = 0u; i < 5u; i++) {
        reset_state();
        TIMER0_REG(TIMER0_VALUE) = 1000u + i * 100u;
        TIMER0_REG(TIMER0_CTRL)  = 0x07u;
        wait_irq(200000u);
        if (irq_count != 1u || last_cause != CAUSE_M_TIMER) { ok = 0; break; }
    }
    mstatus_clr_mie();
    checkpoint(2u, (ok && i == 5u), i);
}

/* T3: with mstatus.MIE set but mie.MTIE clear, the expired timer must stay
 *     pending and never enter the handler (per-source masking). */
static void t3_mie_masking(void)
{
    uint32_t seen;
    reset_state(); disarm_all();
    TIMER0_REG(TIMER0_VALUE) = 300u;
    TIMER0_REG(TIMER0_CTRL)  = 0x07u;
    write_csr(mie, 0u);
    mstatus_set_mie();
    spin_cycles(20000u);
    seen = irq_count;
    mstatus_clr_mie();
    checkpoint(3u, seen == 0u, seen);
}

/* T4: the interrupt latched in T3 must be taken as soon as mie enables it
 *     (pending + enable in a later CSR write). */
static void t4_pending_then_enable(void)
{
    reset_state();
    mstatus_clr_mie();
    write_csr(mie, 0u);
    mstatus_set_mie();
    write_csr(mie, MIE_MTIE);               /* write enable last */
    wait_irq(200000u);
    mstatus_clr_mie();
    checkpoint(4u, (irq_count == 1u) && (last_cause == CAUSE_M_TIMER), irq_count);
}

/* T5: software interrupt: cause 3, and the handler's W1C really clears the
 *     pending register. */
static void t5_software(void)
{
    uint32_t pend;
    reset_state(); disarm_all();
    write_csr(mie, MIE_MSIE);
    IRQ_REG(IRQ_SOFTWARE) = 1u;             /* raise */
    mstatus_set_mie();
    wait_irq(200000u);
    mstatus_clr_mie();
    pend = IRQ_REG(IRQ_SOFTWARE);
    checkpoint(5u, (irq_count == 1u) && (last_cause == CAUSE_M_SOFTWARE) && (pend == 0u), pend);
}

/* T6: software and timer pending at the same instant -> the higher-priority
 *     source (software, cause 3, over timer cause 7) is taken first. */
static void t6_priority(void)
{
    uint32_t first;
    reset_state(); disarm_all();
    TIMER0_REG(TIMER0_VALUE) = 100u;
    TIMER0_REG(TIMER0_CTRL)  = 0x07u;
    spin_cycles(2000u);                     /* timer expires, pending latches */
    IRQ_REG(IRQ_SOFTWARE) = 1u;             /* second source pending as well */
    mstatus_set_mie();
    write_csr(mie, MIE_MSIE | MIE_MTIE);
    wait_irq(200000u);
    first = last_cause;
    mstatus_clr_mie();
    disarm_all();
    checkpoint(6u, first == CAUSE_M_SOFTWARE, first);
}

/* T7: register-file integrity across a taken interrupt. Sentinels live in
 *     caller-saved registers that trap_entry.S must save and restore; the
 *     comparison runs inside the same asm block, so no compiler-generated
 *     frame can mask a missing save. */
static void t7_sentinels(void)
{
    reset_state(); disarm_all();
    write_csr(mie, MIE_MTIE);
    mstatus_set_mie();
    __asm__ volatile (
        "li t3, 0x5A5A0003\n"
        "li t4, 0x5A5A0004\n"
        "li t5, 0x5A5A0005\n"
        "li t6, 0x5A5A0006\n"
        "li a1, 0x5A5A0001\n"
        "li a2, 0x5A5A0002\n"
        "li a3, 0x5A5A0003\n"
        "li a4, 0x5A5A0004\n"
        /* arm the timer: VALUE at 0x20000008, CTRL at 0x20000000 */
        "li t0, 0x20000008\n"
        "li t1, 1500\n"
        "sw t1, 0(t0)\n"
        "li t0, 0x20000000\n"
        "li t1, 7\n"
        "sw t1, 0(t0)\n"
        /* wait until the handler clears the pending bit (bit2) */
        "1:\n"
        "  lw t1, 0(t0)\n"
        "  andi t1, t1, 4\n"
        "  bnez t1, 1b\n"
        "li t0, 0\n"
        "li t1, 0x5A5A0003\n" "beq t3, t1, 2f\n" "ori t0, t0, 1\n"  "2:\n"
        "li t1, 0x5A5A0004\n" "beq t4, t1, 3f\n" "ori t0, t0, 2\n"  "3:\n"
        "li t1, 0x5A5A0005\n" "beq t5, t1, 4f\n" "ori t0, t0, 4\n"  "4:\n"
        "li t1, 0x5A5A0006\n" "beq t6, t1, 5f\n" "ori t0, t0, 8\n"  "5:\n"
        "li t1, 0x5A5A0001\n" "beq a1, t1, 6f\n" "ori t0, t0, 16\n" "6:\n"
        "li t1, 0x5A5A0002\n" "beq a2, t1, 7f\n" "ori t0, t0, 32\n" "7:\n"
        "li t1, 0x5A5A0003\n" "beq a3, t1, 8f\n" "ori t0, t0, 64\n" "8:\n"
        "li t1, 0x5A5A0004\n" "beq a4, t1, 9f\n" "ori t0, t0, 128\n" "9:\n"
        "la t1, sentinel_bad\n"
        "sw t0, 0(t1)\n"
        : : : "t0", "t1", "t3", "t4", "t5", "t6",
              "a1", "a2", "a3", "a4", "memory");
    mstatus_clr_mie();
    checkpoint(7u, (sentinel_bad == 0u) && (irq_count == 1u), sentinel_bad);
}

/* T8: after MRET, mstatus.MIE must be back on and MPIE set (both bit 3 and
 *     bit 7 of mstatus). */
static void t8_mstatus_after_mret(void)
{
    uint32_t st;
    reset_state(); disarm_all();
    TIMER0_REG(TIMER0_VALUE) = 1000u;
    TIMER0_REG(TIMER0_CTRL)  = 0x07u;
    write_csr(mie, MIE_MTIE);
    mstatus_set_mie();
    wait_irq(200000u);
    st = read_csr(mstatus);
    mstatus_clr_mie();
    checkpoint(8u, (irq_count == 1u) && ((st & 0x8u) != 0u) && ((st & 0x80u) != 0u), st);
}

/* T9: external interrupt from KEY1 (interactive; a missing press is reported
 *     as SKIP, never as PASS). */
static void t9_external_key(void)
{
    uint32_t cnt;
    reset_state(); disarm_all();
    IRQ_REG(IRQ_EXTERNAL_ENABLE) = 1u;
    IRQ_REG(IRQ_EXTERNAL_PENDING) = 1u;
    write_csr(mie, MIE_MEIE);
    xprintf("IRQTEST T9 READY press KEY1 within 10 s\n");
    mstatus_set_mie();
    wait_irq(CPU_FREQ_HZ * 10u);
    mstatus_clr_mie();
    cnt = irq_count;
    disarm_all();
    if (cnt == 0u) {
        xprintf("IRQTEST T9 SKIP no key press observed\n");
        return;
    }
    checkpoint(9u, last_cause == CAUSE_M_EXTERNAL, last_cause);
}

/* ----------------------------------------------------------------- main ---- */
int main(void)
{
    uart_init();
    xprintf("IRQTEST start machine-mode interrupt self-test (27 MHz)\n");

    t1_timer_once();
    t2_timer_repeat();
    t3_mie_masking();
    t4_pending_then_enable();
    t5_software();
    t6_priority();
    t7_sentinels();
    t8_mstatus_after_mret();
    t9_external_key();

    xprintf("IRQTEST DONE pass=%u fail=%u\n", (unsigned)pass_n, (unsigned)fail_n);

    /* Keep a visible heartbeat: alternate led[0]/led[7]. */
    GPIO_REG(GPIO_CTRL) = 0x00005555u;
    for (;;) {
        GPIO_REG(GPIO_DATA) = 0x01u;
        spin_cycles(CPU_FREQ_HZ / 4u);
        GPIO_REG(GPIO_DATA) = 0x80u;
        spin_cycles(CPU_FREQ_HZ / 4u);
    }
}
