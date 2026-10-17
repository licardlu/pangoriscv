/* File : core_portme.c
 *
 * Platform : pangoriscv RV32IM core on Pango PG2L100H (MES2L676-100HP), 27 MHz,
 *            bare metal. Based on EEMBC CoreMark v1.01 barebones/core_portme.c
 *            (third-party code, see LICENSE.md beside this file).
 *
 * 移植要点：
 *   - 时间源 = CPU 周期计数器 CSR cycle（lib/utils.c 的 get_cycle_value()，已处理
 *     cycleh 回绕），因此一个 tick 就是一个 CPU 时钟周期，EE_TICKS_PER_SEC = CPU_FREQ_HZ。
 *   - 串口输出由同目录 ee_printf.c 的 uart_send_char() 承担（见其文件头）。
 *   - 内存用 MEM_STATIC 的 2000 字节静态块（见 core_portme.h），不碰 8K 栈。
 */
#include "coremark.h"
#include "core_portme.h"

#include <stdint.h>
#include "../include/utils.h"
#include "../include/uart.h"

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

/* Porting : Timing functions
	The cycle CSR counts core clock cycles, so one tick == one 27 MHz period.
	get_cycle_value() returns 64 bit; the 32-bit CORE_TICKS cast is safe for any
	run below ~2^32 cycles (~159 s at 27 MHz) - see core_portme.h.
*/
CORETIMETYPE barebones_clock() {
	return (CORETIMETYPE)get_cycle_value();
}

#define GETMYTIME(_t) (*_t=barebones_clock())
#define MYTIMEDIFF(fin,ini) ((fin)-(ini))
#define TIMER_RES_DIVIDER 1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC (CPU_FREQ_HZ / TIMER_RES_DIVIDER)

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

void start_time(void) {
	GETMYTIME(&start_time_val);
}

void stop_time(void) {
	GETMYTIME(&stop_time_val);
}

CORE_TICKS get_time(void) {
	CORE_TICKS elapsed=(CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
	return elapsed;
}

/* HAS_FLOAT is 0, so secs_ret is ee_u32: this truncates to whole seconds, which
   is the integer-second convention. The authoritative number is "Total ticks":
   CoreMark/MHz = Iterations * 1e6 / ticks, derivable without floating point. */
secs_ret time_in_secs(CORE_TICKS ticks) {
	secs_ret retval=((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
	return retval;
}

ee_u32 default_num_contexts=1;

void portable_init(core_portable *p, int *argc, char *argv[])
{
	(void)argc;
	(void)argv;
	/* UART must be up before the first ee_printf(). */
	uart_init();
	if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
		ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
	}
	if (sizeof(ee_u32) != 4) {
		ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
	}
	p->portable_id=1;
}

void portable_fini(core_portable *p)
{
	p->portable_id=0;
}
