#include <stdio.h>
#include <stdlib.h>
#include "coremark.h"
#include "../include/utils.h"
#include "../include/uart.h"
#include "../include/xprintf.h"

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif

#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif

volatile ee_s32 seed4_volatile=ITERATIONS;
volatile ee_s32 seed5_volatile=0;

static CORE_TICKS t0, t1;

void start_time(void)
{
  t0 = get_cycle_value();
}

void stop_time(void)
{
  t1 = get_cycle_value();
  /* xprintf only implements 32-bit conversions and core_main.c prints
     "Total ticks" through an (ee_u32) cast, so the raw 64-bit tick count is
     emitted here as two halves. The contest duration evidence must be read
     from this line (or from the hardware ILA), never from the truncated
     "Total ticks" line. */
  ee_printf("CPM_TICKS hi=%lu lo=%lu\n",
            (unsigned long)(t1 >> 32), (unsigned long)(t1 & 0xffffffffUL));
}

CORE_TICKS get_time(void)
{
  return t1 - t0;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
  uint64_t seconds = ticks / CPU_FREQ_HZ;
  return (secs_ret)(seconds > UINT32_MAX ? UINT32_MAX : seconds);
}

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    uart_init();
    *p = 0;
    if (sizeof(ee_ptr_int) != sizeof(void *) || sizeof(ee_u32) != 4) {
        ee_printf("ERROR! CoreMark port type sizes are invalid.\n");
        for (;;) {}
    }
    *p = 1;
}
