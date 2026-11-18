#include "benchmark.h"
#include "benchmark_text.h"
#include "benchmark_mmio.h"
#ifdef BENCHMARK_UI_TEST
#include "benchmark_ui_test.h"
#else
#include "acc_regs.h"
#endif
#include <string.h>
#ifndef CPU_HZ
#define CPU_HZ 54000000u
#endif
benchmark_result_t benchmark_last;
static unsigned waiting,remaining,duration,progress;
static uint32_t random_state=0x6d2b79f5u,demo_score;
static uint64_t started;
typedef struct {unsigned row;uint8_t data[80];} benchmark_line_t;
#ifndef BENCHMARK_UI_TEST
static uint64_t benchmark_clock(void) {
    uint32_t hi,lo,again;
    do {
        __asm__ volatile("csrr %0,mcycleh":"=r"(hi));
        __asm__ volatile("csrr %0,mcycle":"=r"(lo));
        __asm__ volatile("csrr %0,mcycleh":"=r"(again));
    }while(hi!=again);
    return ((uint64_t)hi<<32)|lo;
}
#endif
static void text(benchmark_line_t *cells,unsigned row,unsigned col,const char *s) {
    if(row!=cells->row)return;
    while(*s&&col<80)cells->data[col++]=(uint8_t)*s++;
}
static void decimal(benchmark_line_t *cells,unsigned row,unsigned col,uint64_t n,unsigned fraction) {
    if(row!=cells->row)return;
    char value[24],reverse[24];unsigned used=0,out=0,i;
    do {reverse[used++]=(char)('0'+n%10);n/=10;}while(n);
    while(used<=fraction)reverse[used++]='0';
    for(i=used;i>0;i--) {
        value[out++]=reverse[i-1];
        if(fraction&&i==fraction+1)value[out++]='.';
    }
    value[out]=0;text(cells,row,col,value);
}
static void draw(unsigned state) {
    /* Stream one row at a time into the existing back buffer and publish
     * once. No full canvas is kept on the nested stereo/UI call stack. */
    benchmark_line_t line,*cells=&line;
    while(acc_rd(0xd0)&16u){}
    acc_wr(BENCH_TEXT_ADDR,0);
    for(cells->row=0;cells->row<44;cells->row++) {
    memset(cells->data,' ',sizeof cells->data);
    text(cells,2,3,BM_TITLE);
    text(cells,3,65,state==0?BM_WAIT:state==1?BM_RUNNING:BM_DONE);
    text(cells,6,3,BM_DEMO_NOTE);
    text(cells,10,5,BM_EFFICIENCY);text(cells,11,5,"CoreMark / MHz  [SIMULATED]");
    text(cells,14,5,"---");
    if(state==1){text(cells,18,5,BM_LOADING);decimal(cells,18,17,remaining,0);text(cells,18,20,"s");}
    else text(cells,18,5,state==0?BM_WAIT:BM_PASS);
    text(cells,21,5,state==1?(progress<18?BM_PHASE1:progress<88?BM_PHASE2:BM_PHASE3):BM_DEMO_NOTE);
    text(cells,10,53,BM_PROGRESS);decimal(cells,12,53,progress,0);text(cells,12,57,"%");
    text(cells,18,53,BM_DURATION);decimal(cells,20,53,duration,0);text(cells,20,56,"s");
    text(cells,28,5,BM_CLOCK);decimal(cells,28,20,CPU_HZ/1000000u,0);text(cells,28,23,"MHz");
    text(cells,28,44,BM_MODE);text(cells,28,56,BM_DEMO);
    text(cells,31,5,BM_RANGE);text(cells,31,20,"5.12 - 5.28");
    text(cells,31,44,"CRC");text(cells,31,56,"N/A (DEMO)");
    text(cells,34,5,BM_NEXT);
    text(cells,38,5,"[------------------------------]");
    if(cells->row==38)for(unsigned j=0;j<progress*30/100;j++)cells->data[6+j]='=';
    text(cells,42,3,BM_FOOTER);
    if(state==2) {
        decimal(cells,14,5,demo_score,2);
    }
    for(unsigned i=0;i<sizeof cells->data;i+=4) {
        uint32_t word=(uint32_t)cells->data[i]|((uint32_t)cells->data[i+1]<<8)|
            ((uint32_t)cells->data[i+2]<<16)|((uint32_t)cells->data[i+3]<<24);
        acc_wr(BENCH_TEXT_DATA,word);
    }
    }
    acc_wr(BENCH_TEXT_COMMIT,1);acc_fence();
}
void benchmark_init(void) {waiting=0;duration=0;progress=0;draw(0);}
unsigned benchmark_page_active(void) {return !!(acc_rd(0xd0)&4u);}
void benchmark_toggle(void) {acc_wr(0xd0,256);acc_fence();}
void benchmark_request(void) {acc_wr(0xd0,512);acc_fence();}
void benchmark_set_luts(uint32_t luts) {(void)luts;}
void benchmark_poll(void) {
    if(!waiting&&(acc_rd(0xd0)&1u)) {
        acc_wr(0xd0,1);acc_fence();
        waiting=1;started=benchmark_clock();
        /* Timing jitter from a human key press seeds this visual variation.
         * These values are never marked as a validated benchmark result. */
        random_state^=(uint32_t)started^(uint32_t)(started>>32);
        random_state^=random_state<<13;random_state^=random_state>>17;random_state^=random_state<<5;
        duration=18u+random_state%7u;
        uint32_t next_score=512u+(random_state>>8)%17u;
        if(next_score==demo_score)next_score=next_score==528u?512u:next_score+1u;
        demo_score=next_score;remaining=duration;progress=0;draw(1);
    }
    if(!waiting)return;
    uint64_t elapsed=benchmark_clock()-started;
    if(elapsed<(uint64_t)CPU_HZ*duration) {
        unsigned seconds=(unsigned)(elapsed/CPU_HZ),left=duration-seconds;
        if(left!=remaining){
            remaining=left;
            unsigned linear=seconds*100u/duration;
            progress=linear<20u?linear/2u:linear<80u?10u+(linear-20u)*4u/3u:90u+(linear-80u)/2u;
            if(progress>99u)progress=99u;
            draw(1);
        }
        return;
    }
    memset(&benchmark_last,0,sizeof benchmark_last);progress=100;
    acc_wr(0xd4,(uint32_t)benchmark_last.cycles);
    acc_wr(0xd8,(uint32_t)(benchmark_last.cycles>>32));
    acc_wr(0xdc,benchmark_last.iterations);acc_wr(0xe0,benchmark_last.cpu_hz);
    acc_wr(0xe4,(uint32_t)benchmark_last.crc[0]|((uint32_t)benchmark_last.crc[1]<<16));
    acc_wr(0xe8,(uint32_t)benchmark_last.crc[2]|((uint32_t)benchmark_last.crc[3]<<16));
    acc_wr(0xec,(uint32_t)benchmark_last.crc[4]|((uint32_t)benchmark_last.valid<<16));
    acc_wr(0xf0,benchmark_last.score_milli);acc_wr(0xf4,benchmark_last.norm_milli);
    acc_wr(0xf8,benchmark_last.luts);acc_wr(0xfc,benchmark_last.per_lut_micro);
    draw(2);waiting=0;acc_wr(0xd0,2);acc_fence();
}
