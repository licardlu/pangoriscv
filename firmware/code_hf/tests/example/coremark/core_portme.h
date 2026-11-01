/* File : core_portme.h
 *
 * Platform : pangoriscv RV32IM core on Pango PG2L100H (MES2L676-100HP), 27 MHz,
 *            bare metal, newlib-free (-nostdlib), riscv32 GCC.
 * Based on : EEMBC CoreMark v1.01 barebones/core_portme.h.
 *            CoreMark itself is third-party code, see LICENSE.md beside this file.
 *
 * 与上游 barebones 的差异（全部是"裸机没有 Linux 的那套东西"导致的）：
 *   HAS_FLOAT 0   -> 无浮点 printf；分数按整数秒口径打印（赛题公式自算更准）
 *   HAS_TIME_H 0  -> 没有 time.h
 *   USE_CLOCK  0  -> 不用 clock()
 *   HAS_PRINTF 1  -> 用同目录 ee_printf.c（只依赖 uart_send_char）
 *   MEM_METHOD MEM_STATIC -> 静态 2000B 块；MEM_STACK 会吃掉本就只有 8K 的栈
 *   MAIN_HAS_NOARGC 1 -> start.S 用 call main 直接进，没有 argc/argv
 */
#ifndef CORE_PORTME_H
#define CORE_PORTME_H

#include <stddef.h>
#include <stdint.h>

/************************/
/* Data types and settings */
/************************/
#ifndef HAS_FLOAT
#define HAS_FLOAT 0
#endif

#ifndef HAS_TIME_H
#define HAS_TIME_H 0
#endif

#ifndef USE_CLOCK
#define USE_CLOCK 0
#endif

#ifndef HAS_STDIO
#define HAS_STDIO 0
#endif

/* HAS_PRINTF is CoreMark's "the platform has stdio printf" switch: coremark.h
   does `#define ee_printf printf` when it is 1. This port must keep it 0 so that
   ee_printf stays the local formatter in ee_printf.c (which only needs
   uart_send_char -> uart_putc). */
#ifndef HAS_PRINTF
#define HAS_PRINTF 0
#endif

/* COMPILER_VERSION / COMPILER_FLAGS / MEM_LOCATION */
#ifndef COMPILER_VERSION
#ifdef __GNUC__
#define COMPILER_VERSION "GCC"__VERSION__
#else
#define COMPILER_VERSION "unknown"
#endif
#endif

#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS FLAGS_STR
#endif

#ifndef MEM_LOCATION
#define MEM_LOCATION "STATIC"
#endif

/* Data types. ee_ptr_int must hold a pointer. */
typedef signed short ee_s16;
typedef unsigned short ee_u16;
typedef signed int ee_s32;
typedef double ee_f32;
typedef unsigned char ee_u8;
typedef unsigned int ee_u32;
typedef ee_u32 ee_ptr_int;
typedef size_t ee_size_t;
#define NULL ((void *)0)

#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x) - 1) & ~3))

/* Timing : the CPU cycle counter (CSR cycle) runs at the core clock, 27 MHz.
 * CORE_TICKS is 32 bit: a 600-iteration performance run is ~4.8e8 cycles, an
 * order of magnitude below 2^32, so a single run cannot wrap. Do not raise
 * --iterations into the billions without widening this type.
 */
typedef ee_u32 CORETIMETYPE;
#define CORE_TICKS ee_u32

#ifndef SEED_METHOD
#define SEED_METHOD SEED_VOLATILE
#endif

#ifndef MEM_METHOD
#define MEM_METHOD MEM_STATIC
#endif

#ifndef MULTITHREAD
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK 0
#define USE_SOCKET 0
#endif

/* start.S calls main with no arguments. */
#ifndef MAIN_HAS_NOARGC
#define MAIN_HAS_NOARGC 1
#endif

#ifndef MAIN_HAS_NORETURN
#define MAIN_HAS_NORETURN 0
#endif

extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S {
	ee_u8 portable_id;
} core_portable;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);

#if !defined(PROFILE_RUN) && !defined(PERFORMANCE_RUN) && !defined(VALIDATION_RUN)
#if (TOTAL_DATA_SIZE == 1200)
#define PROFILE_RUN 1
#elif (TOTAL_DATA_SIZE == 2000)
#define PERFORMANCE_RUN 1
#else
#define VALIDATION_RUN 1
#endif
#endif

int ee_printf(const char *fmt, ...);

#endif /* CORE_PORTME_H */
