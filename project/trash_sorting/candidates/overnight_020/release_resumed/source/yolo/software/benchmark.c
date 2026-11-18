#include "benchmark.h"
#include "coremark/coremark.h"
#include <stdarg.h>
#include <string.h>
#ifdef BENCHMARK_HOST_TEST
#include <time.h>
#endif
#ifndef CPU_HZ
#define CPU_HZ 54000000u
#endif
#define BENCH_ITERATIONS 5000u
volatile ee_s32 seed1_volatile=0,seed2_volatile=0,seed3_volatile=0x66;
volatile ee_s32 seed4_volatile=BENCH_ITERATIONS,seed5_volatile=0;
ee_u32 default_num_contexts=1;
static uint64_t begin_ticks,end_ticks,begin_inst,end_inst;
static benchmark_result_t *current;
int coremark_entry(void);

static uint64_t counter(unsigned retired) {
#ifdef BENCHMARK_HOST_TEST
    (void)retired;
    return (uint64_t)clock()*CPU_HZ/CLOCKS_PER_SEC;
#else
    uint32_t hi,lo,again;
    do {
        if(retired) {
            __asm__ volatile("csrr %0,minstreth":"=r"(hi));
            __asm__ volatile("csrr %0,minstret":"=r"(lo));
            __asm__ volatile("csrr %0,minstreth":"=r"(again));
        } else {
            __asm__ volatile("csrr %0,mcycleh":"=r"(hi));
            __asm__ volatile("csrr %0,mcycle":"=r"(lo));
            __asm__ volatile("csrr %0,mcycleh":"=r"(again));
        }
    }while(hi!=again);
    return ((uint64_t)hi<<32)|lo;
#endif
}
void start_time(void) { begin_inst=counter(1);begin_ticks=counter(0); }
void stop_time(void) { end_ticks=counter(0);end_inst=counter(1); }
CORE_TICKS get_time(void) { return end_ticks-begin_ticks; }
secs_ret time_in_secs(CORE_TICKS ticks) { return (secs_ret)(ticks/CPU_HZ); }
void portable_init(core_portable *p,int *argc,char *argv[]) {
    (void)argc;(void)argv;p->portable_id=1;
}
void portable_fini(core_portable *p) { p->portable_id=0; }
/* Structured port sink: capture official reporting arguments, no text parsing,
 * no UART inside the timed workload and no replacement of benchmark algorithms. */
int ee_printf(const char *format,...) {
    va_list ap;
    va_start(ap,format);
    if(!strcmp(format,"Iterations       : %lu\n"))current->iterations=(uint32_t)va_arg(ap,unsigned long);
    else if(!strcmp(format,"seedcrc          : 0x%04x\n"))current->crc[0]=(uint16_t)va_arg(ap,unsigned);
    else if(!strcmp(format,"[%d]crclist       : 0x%04x\n")) {
        (void)va_arg(ap,int);current->crc[1]=(uint16_t)va_arg(ap,unsigned);
    } else if(!strcmp(format,"[%d]crcmatrix     : 0x%04x\n")) {
        (void)va_arg(ap,int);current->crc[2]=(uint16_t)va_arg(ap,unsigned);
    } else if(!strcmp(format,"[%d]crcstate      : 0x%04x\n")) {
        (void)va_arg(ap,int);current->crc[3]=(uint16_t)va_arg(ap,unsigned);
    } else if(!strcmp(format,"[%d]crcfinal      : 0x%04x\n")) {
        (void)va_arg(ap,int);current->crc[4]=(uint16_t)va_arg(ap,unsigned);
    }
    va_end(ap);
    return 0;
}
void benchmark_evaluate(benchmark_result_t *r) {
    r->valid=r->crc_ok&&r->cpu_hz&&r->iterations&&r->cycles>=(uint64_t)r->cpu_hz*10u;
    r->score_milli=r->norm_milli=r->per_lut_micro=0;
    if(!r->valid)return;
    r->score_milli=(uint32_t)((uint64_t)r->iterations*r->cpu_hz*1000u/r->cycles);
    r->norm_milli=(uint32_t)((uint64_t)r->iterations*1000000000ull/r->cycles);
    if(r->luts)r->per_lut_micro=(uint32_t)((uint64_t)r->iterations*r->cpu_hz*1000000ull/r->cycles/r->luts);
}
void benchmark_coremark(benchmark_result_t *r) {
    memset(r,0,sizeof *r);current=r;
    seed1_volatile=0;seed2_volatile=0;seed3_volatile=0x66;
    seed4_volatile=BENCH_ITERATIONS;seed5_volatile=0;
    coremark_entry();
    r->cpu_hz=CPU_HZ;r->cycles=get_time();r->instructions=end_inst-begin_inst;
    r->crc_ok=r->iterations==BENCH_ITERATIONS&&r->crc[0]==0xe9f5&&
        r->crc[1]==0xe714&&r->crc[2]==0x1fd7&&r->crc[3]==0x8e3a&&r->crc[4]==0xbd59;
    benchmark_evaluate(r);
}
