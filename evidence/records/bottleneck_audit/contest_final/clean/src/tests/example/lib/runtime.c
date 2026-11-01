/* Freestanding RV32IM runtime. No dependency on a prebuilt libgcc archive. */
#include <stdint.h>
#include <stddef.h>

static uint64_t divide_unsigned(uint64_t numerator, uint64_t denominator,
                                uint64_t *remainder)
{
    uint64_t quotient = 0;
    uint64_t rest = 0;
    unsigned i;
    if (!denominator) {
        *remainder = numerator;
        return UINT64_MAX;
    }
    /* A carry preserves the 65th bit when the divisor has bit 63 set. */
    for (i = 0; i < 64; ++i) {
        uint32_t carry = (uint32_t)(rest >> 63);
        rest = (rest << 1) | (numerator >> 63);
        numerator <<= 1;
        quotient <<= 1;
        if (carry || rest >= denominator) {
            rest -= denominator;
            quotient |= 1;
        }
    }
    *remainder = rest;
    return quotient;
}

uint64_t __udivdi3(uint64_t numerator, uint64_t denominator)
{
    uint64_t remainder;
    return divide_unsigned(numerator, denominator, &remainder);
}

uint64_t __umoddi3(uint64_t numerator, uint64_t denominator)
{
    uint64_t remainder;
    divide_unsigned(numerator, denominator, &remainder);
    return remainder;
}

void *memcpy(void *destination, const void *source, size_t count)
{
    unsigned char *out = destination;
    const unsigned char *in = source;
    size_t i;
    for (i = 0; i < count; ++i)
        out[i] = in[i];
    return destination;
}

void *memset(void *destination, int value, size_t count)
{
    unsigned char *out = destination;
    size_t i;
    for (i = 0; i < count; ++i)
        out[i] = (unsigned char)value;
    return destination;
}
