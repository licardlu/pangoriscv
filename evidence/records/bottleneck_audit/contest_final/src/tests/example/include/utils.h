#ifndef _UTILS_H_
#define _UTILS_H_

#include <stdint.h>

// Board clock of the MES2L676-100HP: the single-ended 27 MHz oscillator on D18
// ("clk input 1 系统时钟，27MHZ", 教程2 通用实验指导手册 7.3; 教程1 2.1.2.2.3.2). This value is
// the clock the CPU actually runs on, so it drives CoreMark's seconds conversion and the
// UART baud divider. Build with --cpu-mhz 27 (the tool default) to keep them in agreement.
#ifndef CPU_FREQ_MHZ
#define CPU_FREQ_MHZ 27U
#endif
#ifndef CPU_FREQ_HZ
#define CPU_FREQ_HZ (CPU_FREQ_MHZ * 1000000U)
#endif
#if CPU_FREQ_HZ != (CPU_FREQ_MHZ * 1000000U)
#error "CPU_FREQ_HZ and CPU_FREQ_MHZ must agree"
#endif


#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp) :: "memory"); \
  __tmp; })

#define write_csr(reg, val) do { \
  unsigned long __value = (unsigned long)(val); \
  asm volatile ("csrw " #reg ", %0" :: "r"(__value) : "memory"); \
} while (0)


#ifdef SIMULATION
#define set_test_pass() asm("li x27, 0x01")
#define set_test_fail() asm("li x27, 0x00")
#endif


uint64_t get_cycle_value(void);
void busy_wait(uint32_t us);

#endif
