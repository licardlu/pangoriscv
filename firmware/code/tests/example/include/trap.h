#ifndef PANGO_TRAP_H
#define PANGO_TRAP_H
#include <stdint.h>
struct trap_diagnostic {
    uint32_t cause;
    uint32_t epc;
    uint32_t tval;
    uint32_t valid;
};
extern volatile struct trap_diagnostic trap_last_fault;
uint32_t trap_dispatch(uint32_t cause, uint32_t epc, uint32_t tval);
#endif
