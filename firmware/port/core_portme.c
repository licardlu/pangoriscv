#include "coremark.h"
#define MMIO(a) (*(volatile unsigned *)(a))
#ifndef CPU_HZ
#define CPU_HZ 120461538u       /* 交付档 120.46 MHz; 90 MHz 诊断档用 -DCPU_HZ=90000000u */
#endif
volatile ee_s32 seed1_volatile=0, seed2_volatile=0, seed3_volatile=0x66;
volatile ee_s32 seed4_volatile=ITERATIONS, seed5_volatile=0;
ee_u32 default_num_contexts=1;
static uint64_t begin_ticks, end_ticks;
static uint64_t cycles(void) {
    unsigned hi, lo, again;
    do {
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(hi));
        __asm__ volatile ("csrr %0, mcycle" : "=r"(lo));
        __asm__ volatile ("csrr %0, mcycleh" : "=r"(again));
    } while(hi!=again);
    return ((uint64_t)hi<<32)|lo;
}
void uart_send_char(char c) {
    if(c=='\n') uart_send_char('\r');
    while((MMIO(0x10001004)&0x00ff0000)==0) {}
    MMIO(0x10001000)=(unsigned char)c;
}
void start_time(void) { __asm__ volatile("fence iorw,iorw":::"memory"); begin_ticks=cycles(); }
void stop_time(void) { end_ticks=cycles(); __asm__ volatile("fence iorw,iorw":::"memory"); }
CORE_TICKS get_time(void) { return end_ticks-begin_ticks; }
secs_ret time_in_secs(CORE_TICKS ticks) { return ticks/CPU_HZ; }
void portable_init(core_portable *p,int *argc,char *argv[]) {
    (void)argc; (void)argv;
    /* UART 分频必须跟着 CPU_HZ 走, 不能写死 130 (那等于把 120 MHz 焊在固件里)。
       90 MHz 档用写死的 130 会得到 85.9 kbaud, 上位机 115200 收下来全是乱码。
       120.461538 MHz: 120461538/921600-1 = 129.7 -> 130, 与原来的值一致。 */
    MMIO(0x10001008)=(CPU_HZ/(115200*8))-1;
    MMIO(0x1000100c)=7; /* 8N1 */
    MMIO(0x10003000)=1;
    /* Load the volatile count: short/release runs must retain identical .text. */
    ee_printf("VEXII_PANGO_BOOT\nCPU_HZ=%u\nITERATIONS=%u\n",CPU_HZ,(unsigned)seed4_volatile);
    p->portable_id=1;
}
void portable_fini(core_portable *p) {
    uint64_t ticks=get_time();
    ee_printf("TICKS_HI=%u\nTICKS_LO=%u\nBENCH_DONE\n",(unsigned)(ticks>>32),(unsigned)ticks);
    MMIO(0x10003000)=0xa5;
    p->portable_id=0;
}
void trap_report(unsigned cause,unsigned pc,unsigned value) {
    ee_printf("TRAP cause=%x pc=%x value=%x\n",cause,pc,value);
    MMIO(0x10003000)=0xee;
    for(;;) {}
}
