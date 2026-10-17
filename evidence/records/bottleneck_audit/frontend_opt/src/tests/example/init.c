#include <stdint.h>

#include "include/utils.h"


extern void trap_entry();


void _init()
{
    // 设置中断入口函数
    write_csr(mtvec, &trap_entry);
    write_csr(mie, 0);
    write_csr(mstatus, read_csr(mstatus) & ~8UL);
}
