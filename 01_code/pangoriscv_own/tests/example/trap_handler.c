#include <stdint.h>
#include "include/utils.h"
#include "include/trap.h"

extern void software_irq_handler(void) __attribute__((weak));
extern void timer0_irq_handler(void) __attribute__((weak));
extern void external_irq_handler(void) __attribute__((weak));

volatile struct trap_diagnostic trap_last_fault;

uint32_t trap_dispatch(uint32_t cause, uint32_t epc, uint32_t tval)
{
    void (*handler)(void) = 0;
    if (cause & 0x80000000U) {
        switch (cause & 0x7fffffffU) {
        case 3: handler = software_irq_handler; break;
        case 7: handler = timer0_irq_handler; break;
        case 11: handler = external_irq_handler; break;
        default: break;
        }
        if (handler) {
            /* Each handler must acknowledge its own interrupt source. */
            handler();
            return epc;
        }
    }
#ifdef TRAP_TEST_ALLOW_ECALL
    if (cause == 11U)
        return epc + 4U;
#endif
    write_csr(mie, 0);
    write_csr(mstatus, read_csr(mstatus) & ~8UL);
    trap_last_fault.cause = cause;
    trap_last_fault.epc = epc;
    trap_last_fault.tval = tval;
    trap_last_fault.valid = 1;
    for (;;) {
        asm volatile ("" ::: "memory");
    }
}
