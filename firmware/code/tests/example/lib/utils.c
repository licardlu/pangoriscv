#include <stdint.h>

#include "../include/utils.h"



uint64_t get_cycle_value(void)
{
    uint32_t high, low, high_after;
    do {
        high = read_csr(cycleh);
        low = read_csr(cycle);
        high_after = read_csr(cycleh);
    } while (high != high_after);
    return ((uint64_t)high << 32) | low;
}

void busy_wait(uint32_t us)
{
    uint64_t count = (uint64_t)us * CPU_FREQ_MHZ;
    uint64_t start = get_cycle_value();
    while ((uint64_t)(get_cycle_value() - start) < count) {
        asm volatile ("" ::: "memory");
    }
}
