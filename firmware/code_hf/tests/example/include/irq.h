#ifndef PANGO_IRQ_H
#define PANGO_IRQ_H
#include <stdint.h>
#define IRQ_BASE 0x60003000U
#define IRQ_SOFTWARE (IRQ_BASE + 0x00U)
#define IRQ_EXTERNAL_PENDING (IRQ_BASE + 0x04U)
#define IRQ_EXTERNAL_ENABLE (IRQ_BASE + 0x08U)
#define IRQ_REG(addr) (*(volatile uint32_t *)(uintptr_t)(addr))
#define MIE_MSIE (1U << 3)
#define MIE_MTIE (1U << 7)
#define MIE_MEIE (1U << 11)
#define MSTATUS_MIE (1U << 3)
#endif
