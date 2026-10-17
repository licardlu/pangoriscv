/*
 * perf_probe - on-board evidence for the the caches performance counters.
 *
 * The plan's the caches acceptance gate asks for board evidence that an I-cache miss
 * becomes one ARLEN=7 INCR burst and that such a burst produces eight R
 * handshakes.  The counters live in rtl/perips/perf_regs.v at 0x60002000 and
 * only exist when PERF_ENABLE is defined, so this image must be flashed
 * together with a PERF_ENABLE bitstream; on any other build a read of that
 * window answers SLVERR.
 *
 * Reads always return the snapshot bank, so the probe writes CTRL.SNAP before
 * reading.  Two snapshots are taken: one after a cold sweep that must miss, and
 * one after a 64-access repetition of a single cache line that must hit, so the
 * same log line carries both miss and hit evidence.
 *
 * Every line printed is ASCII so a plain 115200 8N1 capture is the evidence.
 */

#include <stdint.h>

#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

#define PERF_BASE       (0x60002000U)
#define PERF_REG(off)   (*((volatile uint32_t *)(PERF_BASE + (off))))

#define PERF_CTRL       (0x00U)   /* W: bit0 SNAP, bit1 CLEAR */
#define PERF_STATUS     (0x04U)   /* R: bit0 snapshot_valid  */
#define PERF_CYCLE_LO   (0x10U)
#define PERF_INST_LO    (0x18U)
#define PERF_IFW_LO     (0x20U)
#define PERF_LSUW_LO    (0x28U)
#define PERF_IMS_LO     (0x30U)
#define PERF_DMS_LO     (0x38U)
#define PERF_CF_LO      (0x40U)
#define PERF_MP_LO      (0x48U)
#define PERF_I_AR       (0x50U)
#define PERF_I_AR_LEN7  (0x54U)
#define PERF_I_R_BEAT   (0x58U)
#define PERF_I_R_LAST   (0x5CU)
#define PERF_D_AR       (0x60U)
#define PERF_D_AR_LEN7  (0x64U)
#define PERF_D_R_BEAT   (0x68U)
#define PERF_D_R_LAST   (0x6CU)
#define PERF_D_AW       (0x70U)
#define PERF_D_W_BEAT   (0x74U)
#define PERF_D_B        (0x78U)

#define WORDS           (256U)    /* 1 KiB: 32 data-cache lines */

typedef struct {
    uint32_t cycle, instret, if_wait, lsu_wait;
    uint32_t i_miss, d_miss, ret_cf, mispred;
    uint32_t i_ar, i_ar_len7, i_r_beat, i_r_last;
    uint32_t d_ar, d_ar_len7, d_r_beat, d_r_last;
    uint32_t d_aw, d_w_beat, d_b;
    uint32_t win_d_ar, win_d_ar_len7;   /* phase-B window, observer reads included */
} perf_set;

/* 1 KiB source and 1 KiB destination in .bss (link.lds gives 16 KiB data RAM). */
static volatile uint32_t src[WORDS];
static volatile uint32_t dst[WORDS];

static __attribute__((noinline)) uint32_t mix(uint32_t a, uint32_t b)
{
    return (a ^ (b << 3)) + (b >> 2) + (a >> 7);
}

static void perf_snap(void)
{
    PERF_REG(PERF_CTRL) = 0x1U;
    asm volatile ("" ::: "memory");
}

static void perf_capture(perf_set *p)
{
    p->cycle     = PERF_REG(PERF_CYCLE_LO);
    p->instret   = PERF_REG(PERF_INST_LO);
    p->if_wait   = PERF_REG(PERF_IFW_LO);
    p->lsu_wait  = PERF_REG(PERF_LSUW_LO);
    p->i_miss    = PERF_REG(PERF_IMS_LO);
    p->d_miss    = PERF_REG(PERF_DMS_LO);
    p->ret_cf    = PERF_REG(PERF_CF_LO);
    p->mispred   = PERF_REG(PERF_MP_LO);
    p->i_ar      = PERF_REG(PERF_I_AR);
    p->i_ar_len7 = PERF_REG(PERF_I_AR_LEN7);
    p->i_r_beat  = PERF_REG(PERF_I_R_BEAT);
    p->i_r_last  = PERF_REG(PERF_I_R_LAST);
    p->d_ar      = PERF_REG(PERF_D_AR);
    p->d_ar_len7 = PERF_REG(PERF_D_AR_LEN7);
    p->d_r_beat  = PERF_REG(PERF_D_R_BEAT);
    p->d_r_last  = PERF_REG(PERF_D_R_LAST);
    p->d_aw      = PERF_REG(PERF_D_AW);
    p->d_w_beat  = PERF_REG(PERF_D_W_BEAT);
    p->d_b       = PERF_REG(PERF_D_B);
}

/* An AR command with ARLEN=7 always delivers eight R beats, one of them with
 * RLAST; a single-beat command delivers one of each.  So for the whole run
 *   r_beat = ar + 7 * ar_len7   and   r_last = ar
 * on both ports, which is exactly the "ARLEN=7 plus eight R handshakes"
 * evidence the plan asks for. */
static uint32_t bursts_lined_up(const perf_set *p)
{
    return (p->i_ar_len7 > 0U) && (p->d_ar_len7 > 0U) &&
           (p->i_r_beat == p->i_ar + 7U * p->i_ar_len7) &&
           (p->i_r_last == p->i_ar) &&
           (p->d_r_beat == p->d_ar + 7U * p->d_ar_len7) &&
           (p->d_r_last == p->d_ar);
}

int main(void)
{
    perf_set cold, hot;
    uint32_t sum = 0;
    uint32_t i, n;

    uart_init();
    xprintf("\nPERF probe start cpu_mhz=%u\n", (unsigned)CPU_FREQ_MHZ);

    for (i = 0; i < WORDS; i++) {
        src[i] = ((i * 2654435761U) ^ (i << 7)) + 0x9E3779B9U;
    }

    for (n = 1; ; n++) {
        /* Phase A: a sequential sweep over 1 KiB must miss every one of the 32
         * data-cache lines, and the loop plus mix() must fetch instruction lines
         * as well.  One store per word is write-through with no write allocate. */
        for (i = 0; i < WORDS; i++) {
            sum += mix(src[i], i);
        }
        for (i = 0; i < WORDS; i++) {
            dst[i] = sum + i;
        }
        perf_snap();
        perf_capture(&cold);

        /* Phase B: 64 accesses to a single already-cached line, with no console
         * traffic in between.  The window is bracketed by four MMIO reads, which
         * are themselves uncached single-beat reads, so anything the window shows
         * above those four is a real data-cache miss. */
        hot.win_d_ar      = PERF_REG(PERF_D_AR);
        hot.win_d_ar_len7 = PERF_REG(PERF_D_AR_LEN7);
        for (i = 0; i < 64U; i++) {
            sum += mix(src[1], i);
        }
        hot.win_d_ar      = PERF_REG(PERF_D_AR) - hot.win_d_ar;
        hot.win_d_ar_len7 = PERF_REG(PERF_D_AR_LEN7) - hot.win_d_ar_len7;
        perf_snap();
        perf_capture(&hot);

        xprintf("PERF probe n=%u workload: sum=%u\n", (unsigned)n, (unsigned)sum);
        xprintf("PERF probe n=%u counters: cycle=%u instret=%u if_wait=%u lsu_wait=%u "
                "i_miss=%u d_miss=%u ret_cf=%u mispred=%u\n",
                (unsigned)n, (unsigned)cold.cycle, (unsigned)cold.instret,
                (unsigned)cold.if_wait, (unsigned)cold.lsu_wait,
                (unsigned)cold.i_miss, (unsigned)cold.d_miss,
                (unsigned)cold.ret_cf, (unsigned)cold.mispred);
        xprintf("PERF probe n=%u axi_i: ar=%u ar_len7=%u r_beat=%u r_last=%u\n",
                (unsigned)n, (unsigned)cold.i_ar, (unsigned)cold.i_ar_len7,
                (unsigned)cold.i_r_beat, (unsigned)cold.i_r_last);
        xprintf("PERF probe n=%u axi_d: ar=%u ar_len7=%u r_beat=%u r_last=%u "
                "aw=%u w_beat=%u b=%u\n",
                (unsigned)n, (unsigned)cold.d_ar, (unsigned)cold.d_ar_len7,
                (unsigned)cold.d_r_beat, (unsigned)cold.d_r_last,
                (unsigned)cold.d_aw, (unsigned)cold.d_w_beat, (unsigned)cold.d_b);
        xprintf("PERF probe n=%u hit_window: d_ar=%u d_ar_len7=%u observer_mmio=4 "
                "i_ar=%u i_ar_len7=%u\n",
                (unsigned)n,
                (unsigned)hot.win_d_ar,
                (unsigned)hot.win_d_ar_len7,
                (unsigned)(hot.i_ar - cold.i_ar),
                (unsigned)(hot.i_ar_len7 - cold.i_ar_len7));
        xprintf("PERF probe n=%u burst_check=%u\n", (unsigned)n,
                (unsigned)bursts_lined_up(&cold));
        /* Every store is one AW plus one W beat, and at most one store can be in
         * flight when the snapshot lands (the LSU waits for B before retiring the
         * store), so the observed B count is the AW count or one behind it. */
        xprintf("PERF probe n=%u store_check=%u\n", (unsigned)n,
                (unsigned)((cold.d_aw == cold.d_w_beat) && (cold.d_aw > 0U) &&
                           ((cold.d_b == cold.d_aw) ||
                            (cold.d_b + 1U == cold.d_aw))));
        /* Hit-only window: at most the four observer reads and at most one refill
         * for the first access to the line. */
        xprintf("PERF probe n=%u hit_check=%u\n", (unsigned)n,
                (unsigned)((hot.win_d_ar_len7 <= 1U) && (hot.win_d_ar <= 6U)));
        xprintf("PERF probe n=%u %s\n", (unsigned)n,
                (bursts_lined_up(&cold) && (cold.d_aw == cold.d_w_beat) &&
                 ((cold.d_b == cold.d_aw) || (cold.d_b + 1U == cold.d_aw)) &&
                 (hot.win_d_ar_len7 <= 1U) && (hot.win_d_ar <= 6U))
                ? "PASS" : "FAIL");

        busy_wait(2000000U);
    }
}
