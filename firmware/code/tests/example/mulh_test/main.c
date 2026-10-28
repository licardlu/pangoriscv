/*
 * mulh_test - board test for the M-extension multiply, added with rv32_mul rev 2.0
 *
 * rev 2.0 split the multiplier in two: `mul` became a truncated 32x32 (same
 * cycle), and `mulh`/`mulhsu`/`mulhu` became an explicit two-stage tree whose
 * partial products are registered, with `rv32_top` charging one `mulh_wait`
 * bubble for them.  The arithmetic of the decomposition was proved bit-exact in
 * software (800,484 vectors), but nothing on this machine can simulate the
 * hazard -- ModelSim has no license here (mistakes-log 109) -- and CoreMark's
 * timed loop may never issue mulh at all, so CoreMark's CRC cannot cover it.
 *
 * This image is the missing check.  The operands and the four expected products
 * are literal constants computed offline, and every result is read back with
 * inline asm so the compiler cannot constant-fold the thing it is meant to
 * measure.  Any mismatch is printed and counted; one ASCII capture at 115200
 * 8N1 is the evidence.
 */
#include <stdint.h>

#include "../include/gpio.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

typedef struct {
    uint32_t a, b;
    uint32_t mul, mulh, mulhsu, mulhu;
} vec_t;

static const vec_t k_vec[] = {
    {0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u, 0x00000000u},
    {0x00000001u, 0x00000001u, 0x00000001u, 0x00000000u, 0x00000000u, 0x00000000u},
    {0xFFFFFFFFu, 0xFFFFFFFFu, 0x00000001u, 0x00000000u, 0xFFFFFFFFu, 0xFFFFFFFEu},
    {0x80000000u, 0x80000000u, 0x00000000u, 0x40000000u, 0xC0000000u, 0x40000000u},
    {0x7FFFFFFFu, 0x7FFFFFFFu, 0x00000001u, 0x3FFFFFFFu, 0x3FFFFFFFu, 0x3FFFFFFFu},
    {0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xC0000000u, 0xC0000000u, 0x3FFFFFFFu},
    {0x7FFFFFFFu, 0x80000000u, 0x80000000u, 0xC0000000u, 0x3FFFFFFFu, 0x3FFFFFFFu},
    {0xFFFFFFFFu, 0x00000002u, 0xFFFFFFFEu, 0xFFFFFFFFu, 0xFFFFFFFFu, 0x00000001u},
    {0x00000002u, 0xFFFFFFFFu, 0xFFFFFFFEu, 0xFFFFFFFFu, 0x00000001u, 0x00000001u},
    {0x12345678u, 0x9ABCDEF0u, 0x242D2080u, 0xF8CC93D6u, 0x0B00EA4Eu, 0x0B00EA4Eu},
    {0x9ABCDEF0u, 0x12345678u, 0x242D2080u, 0xF8CC93D6u, 0xF8CC93D6u, 0x0B00EA4Eu},
    {0x00010001u, 0x00010001u, 0x00020001u, 0x00000001u, 0x00000001u, 0x00000001u},
    {0xFFFFFFFFu, 0x80000000u, 0x80000000u, 0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu},
    {0x80000000u, 0xFFFFFFFFu, 0x80000000u, 0x00000000u, 0x80000000u, 0x7FFFFFFFu},
    {0x0000FFFFu, 0x0000FFFFu, 0xFFFE0001u, 0x00000000u, 0x00000000u, 0x00000000u},
    {0xFFFF0000u, 0xFFFF0000u, 0x00000000u, 0x00000001u, 0xFFFF0001u, 0xFFFE0001u},
    {0xFFFF0000u, 0x0000FFFFu, 0x00010000u, 0xFFFFFFFFu, 0xFFFFFFFFu, 0x0000FFFEu},
    {0x0000FFFFu, 0xFFFF0000u, 0x00010000u, 0xFFFFFFFFu, 0x0000FFFEu, 0x0000FFFEu},
    {0xDEADBEEFu, 0xCAFEBABEu, 0x88CF5B62u, 0x06E631CEu, 0xE593F0BDu, 0xB092AB7Bu},
    {0xCAFEBABEu, 0xDEADBEEFu, 0x88CF5B62u, 0x06E631CEu, 0xD1E4EC8Cu, 0xB092AB7Bu},
    {0x00000001u, 0xFFFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu, 0x00000000u, 0x00000000u},
    {0x00000003u, 0x00000005u, 0x0000000Fu, 0x00000000u, 0x00000000u, 0x00000000u},
    {0x40000000u, 0x00000004u, 0x00000000u, 0x00000001u, 0x00000001u, 0x00000001u},
    {0x20000000u, 0x00000008u, 0x00000000u, 0x00000001u, 0x00000001u, 0x00000001u},
};

#define NVEC (sizeof(k_vec) / sizeof(k_vec[0]))

static inline uint32_t hw_mul(uint32_t a, uint32_t b)
{ uint32_t r; __asm__ volatile ("mul %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static inline uint32_t hw_mulh(uint32_t a, uint32_t b)
{ uint32_t r; __asm__ volatile ("mulh %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static inline uint32_t hw_mulhsu(uint32_t a, uint32_t b)
{ uint32_t r; __asm__ volatile ("mulhsu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static inline uint32_t hw_mulhu(uint32_t a, uint32_t b)
{ uint32_t r; __asm__ volatile ("mulhu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r; }

int main(void)
{
    unsigned i, bad = 0;
    uint32_t sig = 0;

    uart_init();
    xprintf("\nMULH start cpu_mhz=%u nvec=%u\n", (unsigned)CPU_FREQ_MHZ, (unsigned)NVEC);

    for (i = 0; i < NVEC; i++) {
        const vec_t *v = &k_vec[i];
        uint32_t mu  = hw_mul(v->a, v->b);
        uint32_t mh  = hw_mulh(v->a, v->b);
        uint32_t mhs = hw_mulhsu(v->a, v->b);
        uint32_t mhu = hw_mulhu(v->a, v->b);

        if (mu != v->mul || mh != v->mulh || mhs != v->mulhsu || mhu != v->mulhu) {
            bad++;
            xprintf("MULH MISMATCH i=%u a=%08x b=%08x\n", i,
                    (unsigned)v->a, (unsigned)v->b);
            xprintf("  mul  got=%08x want=%08x\n", (unsigned)mu, (unsigned)v->mul);
            xprintf("  mulh got=%08x want=%08x\n", (unsigned)mh, (unsigned)v->mulh);
            xprintf("  mulhsu got=%08x want=%08x\n", (unsigned)mhs, (unsigned)v->mulhsu);
            xprintf("  mulhu  got=%08x want=%08x\n", (unsigned)mhu, (unsigned)v->mulhu);
        }
        sig = (sig << 1) | (sig >> 31);
        sig ^= mu;  sig = (sig << 1) | (sig >> 31);
        sig ^= mh;  sig = (sig << 1) | (sig >> 31);
        sig ^= mhs; sig = (sig << 1) | (sig >> 31);
        sig ^= mhu;
    }

    xprintf("MULH signature=%08x\n", (unsigned)sig);
    if (bad == 0 && sig == 0xB5A0D3A2u) {
        xprintf("MULH PASS\n");
    } else {
        xprintf("MULH FAIL bad=%u\n", bad);
    }

    /* LED heartbeat: the run is done, this only proves the core keeps executing
     * and gives a capture window that cannot be confused with the result. */
    for (;;) {
        volatile uint32_t spin;
        GPIO_REG(GPIO_DATA) = 0x0FU;
        for (spin = 0; spin < 400000U; spin++) { }
        GPIO_REG(GPIO_DATA) = 0xF0U;
        for (spin = 0; spin < 400000U; spin++) { }
    }
}
