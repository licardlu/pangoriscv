#include <stdint.h>
uint32_t test_acc_rd(unsigned address);
void test_acc_wr(unsigned address,uint32_t data);
uint64_t benchmark_clock(void);
#define acc_rd test_acc_rd
#define acc_wr test_acc_wr
#define acc_fence() ((void)0)
