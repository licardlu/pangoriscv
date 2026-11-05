/* acc_regs.h -- accelerator <-> CPU contract.
 *
 * This describes the register file that wraps conv_band_rt, and it is derived
 * from the engine's actual port list, not from an earlier plan.  An earlier
 * version of this file described a descriptor sequencer (acc_seq.v) that was
 * deleted: it had multiple drivers and duplicated logic, and one layer costs a
 * few hundred thousand cycles, so writing 20 registers per layer from the CPU
 * is free by comparison.  There is no descriptor format any more.
 *
 * Bus: AXI4-Lite slave, 32-bit data, byte addresses.  One accelerator instance.
 *
 * Completion rule: DONE is asserted only after the last AXI write burst has
 * received BRESP == OKAY.  "Last beat accepted" is not "finished".  A write
 * that is issued but not yet acknowledged keeps BUSY set.
 *
 * Numeric rules the engine implements, frozen in ai_lab/STATUS.md:
 *   acc = sum(a_q * w_q) + bias_q          int32
 *   y   = (acc * M) >> 15                  round half away from zero, then clip
 *   act = none | leaky(y>>3 if y<0) | table[y+128]
 * S is fixed at 15 and is not a runtime value: the quantiser always emits 15,
 * and a 64-bit barrel shifter on the critical path bought nothing.
 */
#ifndef ACC_REGS_H
#define ACC_REGS_H

#include <stdint.h>
#include <string.h>

/* The firmware uses this header in freestanding builds.  Keep the small CRC
 * helper local to the accelerator helpers so it cannot collide with the
 * protocol CRC routine in platform_main.c. */
#ifndef ACC_CRC_UPDATE_DECL
#define ACC_CRC_UPDATE_DECL
static inline uint32_t acc_crc_update(uint32_t crc, const unsigned char *p,
                                      uint32_t n)
{
    uint32_t j;
    while (n--) {
        crc ^= *p++;
        for (j = 0; j < 8; ++j)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return crc;
}
#endif

/* Current pangoriscv_ai_soc window; another CPU integration may override it. */
#ifndef ACC_BASE
#define ACC_BASE            0x70000000u
#endif

/* --- control / status --------------------------------------------------- */
#define ACC_CTRL            0x00u   /* W */
#define ACC_CTRL_START      (1u << 0)
/* Abort is not implemented: recovery from a timeout requires system reset. */

#define ACC_STATUS          0x04u   /* R */
#define ACC_ST_BUSY         (1u << 0)
#define ACC_ST_DONE         (1u << 1)
#define ACC_ST_ERR          (1u << 2)   /* sticky until the next START */

#define ACC_CYCLES          0x08u   /* R: cycles the last layer took */
#define ACC_VERSION         0x0Cu   /* R: 0x0001_0000, engine generation 1.0 */

/* --- layer shape, all written before START ------------------------------ */
/* Every field is the exact value the engine latches at START; nothing is
 * derived in hardware, because deriving it in the address path is what did not
 * close at 100 MHz. */
#define ACC_CIN             0x10u   /* W: channels present, multiple of 8      */
#define ACC_COUT            0x14u   /* W: output channels                      */
#define ACC_IN_W            0x18u   /* W: input width                          */
#define ACC_IN_H            0x1Cu   /* W: input height                         */
#define ACC_OUT_W           0x20u   /* W: output width                         */
#define ACC_OUT_H           0x24u   /* W: output height                        */
#define ACC_K               0x28u   /* W: kernel 1, 3 or 6                     */
#define ACC_STRIDE          0x2Cu   /* W: 1 or 2                               */
#define ACC_PAD             0x30u   /* W: 0..2, from the layer table (autopad)  */
#define ACC_ACT             0x34u   /* W: 0 none, 1 leaky, 2 table             */
#define ACC_TR              0x38u   /* W: band rows, 1..8                      */
#define ACC_SHIFT           0x3Cu   /* W: must be 15                           */

/* --- DDR base addresses, 64-bit word aligned ---------------------------- */
#define ACC_A_BASE          0x40u   /* W: input tensor  [y][x][c] channel-last */
#define ACC_W_BASE          0x44u   /* W: weights, 8 banks of k*k*cin/8 words  */
#define ACC_Q_BASE          0x48u   /* W: int32 bias[cout] then int32 M[cout]  */
#define ACC_T_BASE          0x4Cu   /* W: 256-byte activation table, or 0      */
#define ACC_Y_BASE          0x50u   /* W: output tensor [y][x][c] channel-last */

/* --- model load window ---------------------------------------------------
 * The CPU has no DDR master: its two AXI masters only reach the on-chip RAM and
 * the peripherals.  The accelerator does have one, and it is idle whenever a
 * layer is not running, so three registers are enough to stream a model image
 * in.  Set ADDR once, then for each 64-bit word write LO and HI; ADDR walks
 * itself by 8.  There is no DMA and no burst: this is the slow path, and it
 * only runs once per power-up. */
#define ACC_LOAD_ADDR       0x54u   /* W: DDR byte address of the next word     */
#define ACC_LOAD_LO         0x58u   /* W: bits [31:0] of the word               */
#define ACC_LOAD_HI         0x5Cu   /* W: bits [63:32]; writing this commits it */
#define ACC_READ_ADDR       0x60u   /* W: aligned DDR byte address */
#define ACC_READ_CTRL       0x64u   /* W bit0: start, R: busy/done/error */
#define ACC_READ_LO         0x68u
#define ACC_READ_HI         0x6Cu
#define ACC_LOAD_STATUS     0x70u   /* R bit0 busy, bit1 write error */

/* --- bulk DDR window ----------------------------------------------------- */
/* BULK_ADDR arms both the write and read cursors.  Each LO/HI pair writes one
 * word; each RLO/RHI pair reads one word.  The hardware applies backpressure
 * while the previous DDR transaction is outstanding, so the CPU need not
 * poll between words. */
#define ACC_BULK_ADDR       0xA0u   /* W: byte address; resets both cursors */
#define ACC_BULK_WLO        0xA4u   /* W: next word [31:0] */
#define ACC_BULK_WHI        0xA8u   /* W: next word [63:32], commits */
#define ACC_BULK_RLO        0xACu   /* R: current word [31:0] */
#define ACC_BULK_RHI        0xB0u   /* R: current word [63:32], advances */
#define ACC_BULK_STATUS     0xB4u   /* R: err[31], ready[30], busy[29], len */
#define ACC_BULK_ST_ERR     (1u << 31)
#define ACC_BULK_ST_READY   (1u << 30)
#define ACC_BULK_ST_BUSY    (1u << 29)
#define ACC_BULK_MAX_WORDS  0xffffu

/* --- what "one layer" looks like from the CPU --------------------------- */
typedef struct {
    uint32_t a_base, w_base, q_base, t_base, y_base;
    uint16_t cin, cout, in_w, in_h, out_w, out_h;
    uint8_t  k, stride, pad, act, tr;
} acc_layer_t;

/* Use pack_deployment.py's tr. The engine rejects oversized buffer requests
 * before issuing DDR reads. */

static inline void acc_wr(uint32_t off, uint32_t v)
{
    *(volatile uint32_t *)(uintptr_t)(ACC_BASE + off) = v;
}

static inline uint32_t acc_rd(uint32_t off)
{
    return *(volatile uint32_t *)(uintptr_t)(ACC_BASE + off);
}

static inline void acc_fence(void)
{
#ifdef __riscv
    __asm__ volatile ("fence iorw,iorw" ::: "memory");
#endif
}

static inline int acc_wait_idle(uint32_t limit)
{
    while (limit--) {
        uint32_t s = acc_rd(ACC_STATUS);
        if (s & ACC_ST_ERR) return 1;
        if (!(s & ACC_ST_BUSY)) return 0;
    }
    return 2;
}

static inline int acc_memory_write64(uint32_t address, uint64_t data, uint32_t limit)
{
    int rc;
    if (address & 7u) return 3;
    rc = acc_wait_idle(limit);
    if (rc) return rc;
    acc_wr(ACC_LOAD_ADDR, address);
    acc_wr(ACC_LOAD_LO, (uint32_t)data);
    acc_wr(ACC_LOAD_HI, (uint32_t)(data >> 32));
    acc_fence();
    return acc_wait_idle(limit);
}

static inline int acc_memory_read64(uint32_t address, uint64_t *data, uint32_t limit)
{
    int rc;
    if (!data || (address & 7u)) return 3;
    rc = acc_wait_idle(limit);
    if (rc) return rc;
    acc_wr(ACC_READ_ADDR, address);
    acc_wr(ACC_READ_CTRL, 1);
    acc_fence();
    while (limit--) {
        uint32_t s = acc_rd(ACC_READ_CTRL);
        if (s & ACC_ST_ERR) return 1;
        if (!(s & ACC_ST_BUSY) && (s & ACC_ST_DONE)) {
            *data = ((uint64_t)acc_rd(ACC_READ_HI) << 32) | acc_rd(ACC_READ_LO);
            return 0;
        }
    }
    return 2;
}

static inline int acc_memory_write_bulk(uint32_t address,
                                        const void *src, uint32_t bytes,
                                        uint32_t limit)
{
    const unsigned char *p = (const unsigned char *)src;
    uint32_t done = 0, i, chunk, s;
    uint64_t word;
    if (!src || (address & 7u) || (bytes == 0) || (bytes & 7u)) return 3;
    while (done < bytes) {
        chunk = (bytes - done) >> 3;
        if (chunk > ACC_BULK_MAX_WORDS) chunk = ACC_BULK_MAX_WORDS;
        if (acc_wait_idle(limit)) return 1;
        acc_wr(ACC_BULK_ADDR, address + done);
        for (i = 0; i < chunk * 8u; i += 8) {
            memcpy(&word, p + done + i, sizeof word);
            acc_wr(ACC_BULK_WLO, (uint32_t)word);
            acc_wr(ACC_BULK_WHI, (uint32_t)(word >> 32));
        }
        acc_fence();
        s = ACC_BULK_ST_BUSY;
        for (i = 0; i < limit; ++i) {
            s = acc_rd(ACC_BULK_STATUS);
            if (s & ACC_BULK_ST_ERR) return 1;
            if (!(s & ACC_BULK_ST_BUSY)) break;
        }
        if (s & ACC_BULK_ST_BUSY || (s & 0xffffu) != chunk) return 2;
        done += chunk * 8u;
    }
    return 0;
}

static inline int acc_memory_read_bulk(uint32_t address,
                                       void *dst, uint32_t bytes,
                                       uint32_t limit)
{
    unsigned char *p = (unsigned char *)dst;
    uint32_t done = 0, i, chunk, s;
    uint64_t word;
    if (!dst || (address & 7u) || (bytes == 0) || (bytes & 7u)) return 3;
    while (done < bytes) {
        chunk = (bytes - done) >> 3;
        if (chunk > ACC_BULK_MAX_WORDS) chunk = ACC_BULK_MAX_WORDS;
        if (acc_wait_idle(limit)) return 1;
        acc_wr(ACC_BULK_ADDR, address + done);
        acc_fence();
        for (i = 0; i < chunk; ++i) {
            s = ACC_BULK_ST_BUSY;
            while (!(s & ACC_BULK_ST_READY)) {
                s = acc_rd(ACC_BULK_STATUS);
                if (s & ACC_BULK_ST_ERR) return 1;
                if (!limit--) return 2;
            }
            /* RLO is a non-consuming snapshot read; RHI is the consuming
             * read.  The pair therefore belongs to one DDR word. */
            word = (uint64_t)acc_rd(ACC_BULK_RLO);
            word |= (uint64_t)acc_rd(ACC_BULK_RHI) << 32;
            memcpy(p + done + i * 8u, &word, sizeof word);
        }
        done += chunk * 8u;
    }
    return 0;
}

static inline int acc_memory_crc_bulk(uint32_t address, uint32_t bytes,
                                      uint32_t limit, uint32_t *crc)
{
    uint32_t done = 0, i, chunk, s;
    uint64_t word;
    if (!crc || (address & 7u) || (bytes == 0) || (bytes & 7u)) return 3;
    while (done < bytes) {
        chunk = (bytes - done) >> 3;
        if (chunk > ACC_BULK_MAX_WORDS) chunk = ACC_BULK_MAX_WORDS;
        if (acc_wait_idle(limit)) return 1;
        acc_wr(ACC_BULK_ADDR, address + done);
        acc_fence();
        for (i = 0; i < chunk; ++i) {
            s = ACC_BULK_ST_BUSY;
            while (!(s & ACC_BULK_ST_READY)) {
                s = acc_rd(ACC_BULK_STATUS);
                if (s & ACC_BULK_ST_ERR) return 1;
                if (!limit--) return 2;
            }
            word = (uint64_t)acc_rd(ACC_BULK_RLO);
            word |= (uint64_t)acc_rd(ACC_BULK_RHI) << 32;
            *crc = acc_crc_update(*crc, (const unsigned char *)&word, 8);
        }
        done += chunk * 8u;
    }
    return 0;
}

static inline void acc_program(const acc_layer_t *l)
{
    acc_wr(ACC_CIN,    l->cin);
    acc_wr(ACC_COUT,   l->cout);
    acc_wr(ACC_IN_W,   l->in_w);
    acc_wr(ACC_IN_H,   l->in_h);
    acc_wr(ACC_OUT_W,  l->out_w);
    acc_wr(ACC_OUT_H,  l->out_h);
    acc_wr(ACC_K,      l->k);
    acc_wr(ACC_STRIDE, l->stride);
    acc_wr(ACC_PAD,    l->pad);
    acc_wr(ACC_ACT,    l->act);
    acc_wr(ACC_TR,     l->tr);
    acc_wr(ACC_SHIFT,  15);
    acc_wr(ACC_A_BASE, l->a_base);
    acc_wr(ACC_W_BASE, l->w_base);
    acc_wr(ACC_Q_BASE, l->q_base);
    acc_wr(ACC_T_BASE, l->t_base);
    acc_wr(ACC_Y_BASE, l->y_base);
}

/* Returns 0 on success, 1 if the engine reported an AXI error, 2 on timeout.
 * The poll bound is deliberately finite and layer-independent: a wrong tr or a
 * bad base address shows up as a stall, and an infinite loop hides it. */
static inline int acc_run(uint32_t poll_limit)
{
    uint32_t i;
    acc_fence();
    acc_wr(ACC_CTRL, ACC_CTRL_START);
    for (i = 0; i < poll_limit; i++) {
        uint32_t s = acc_rd(ACC_STATUS);
        if (s & ACC_ST_ERR)  return 1;
        if (s & ACC_ST_DONE) return 0;
    }
    return 2;
}

#endif /* ACC_REGS_H */
