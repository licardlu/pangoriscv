#include "benchmark.h"
#include "benchmark_text.h"
#include "benchmark_mmio.h"
#ifdef BENCHMARK_UI_TEST
#include "benchmark_ui_test.h"
#else
#include "acc_regs.h"
#endif
#include <string.h>
#ifdef MEDIA_ENABLE
#include "media_player.h"
#endif
#ifndef CPU_HZ
#define CPU_HZ 54000000u
#endif
benchmark_result_t benchmark_last;
static unsigned queued,visible;
static uint32_t implementation_luts;
typedef struct {unsigned row;uint8_t data[80];} benchmark_line_t;
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
    text(cells,10,5,BM_EFFICIENCY);text(cells,11,5,"CoreMark / MHz");
    if(state==2 && benchmark_last.valid)decimal(cells,14,5,benchmark_last.norm_milli,3);
    else text(cells,14,5,"---");
    text(cells,18,5,state==1?BM_LOADING:state==0?BM_WAIT:benchmark_last.valid?BM_PASS:BM_ERROR);
    text(cells,21,5,state==1?BM_PHASE2:BM_MEASURE);
    text(cells,10,53,BM_MODE);text(cells,12,53,"CoreMark");
    text(cells,18,53,BM_DURATION);
    if(state==2){decimal(cells,20,53,benchmark_last.cycles*1000u/CPU_HZ,3);text(cells,20,61,"s");}
    else text(cells,20,53,"---");
    text(cells,28,5,BM_CLOCK);decimal(cells,28,20,CPU_HZ/1000000u,0);text(cells,28,23,"MHz");
    text(cells,28,44,BM_ITERATIONS);decimal(cells,28,56,benchmark_last.iterations,0);
    text(cells,31,5,BM_CYCLES);decimal(cells,31,20,benchmark_last.cycles,0);
    text(cells,31,44,"CRC");text(cells,31,56,state==2?(benchmark_last.crc_ok?"5/5 PASS":"FAIL"):"---");
    text(cells,34,5,BM_NEXT);
    text(cells,38,5,state==1?BM_PHASE1:state==2?BM_COMPLETE:BM_WAIT);
    text(cells,42,3,BM_FOOTER);
    for(unsigned i=0;i<sizeof cells->data;i+=4) {
        uint32_t word=(uint32_t)cells->data[i]|((uint32_t)cells->data[i+1]<<8)|
            ((uint32_t)cells->data[i+2]<<16)|((uint32_t)cells->data[i+3]<<24);
        acc_wr(BENCH_TEXT_DATA,word);
    }
    }
    acc_wr(BENCH_TEXT_COMMIT,1);acc_fence();
}
void benchmark_init(void) {queued=visible=0;draw(0);}
unsigned benchmark_page_active(void) {return !!(acc_rd(0xd0)&4u);}
void benchmark_toggle(void) {acc_wr(0xd0,256);acc_fence();}
void benchmark_request(void) {acc_wr(0xd0,512);acc_fence();}
void benchmark_set_luts(uint32_t luts) {implementation_luts=luts;}
void benchmark_poll(void) {
    unsigned status=acc_rd(0xd0),page=!!(status&4u);
    /* Returning to the page shows a ready prompt. Navigation never requests a run. */
    if(page&&!visible && !(status&3u)){draw(0);}
    visible=page;
    queued=!!(status&1u);
}
void benchmark_run_pending(void) {
    unsigned status=acc_rd(0xd0);
    if(!queued || !(status&1u))return;
    /* Wait for the actual scanout page, not just the navigation request. */
    if((status&100u)!=36u)return; // Finish page prompt before timed workload.
    queued=0;acc_wr(0xd0,1);acc_fence();draw(1);
#ifdef MEDIA_ENABLE
    int paused=media_player_paused();
    media_player_pause(1);
#endif
    /* The only timed call. Main's inference/UART/media service is suspended;
     * display scanout and the hardware activity indicator keep running. */
    benchmark_coremark(&benchmark_last);
    benchmark_last.luts=implementation_luts;benchmark_evaluate(&benchmark_last);
#ifdef MEDIA_ENABLE
    media_player_pause(paused);
#endif
    acc_wr(0xd4,(uint32_t)benchmark_last.cycles);
    acc_wr(0xd8,(uint32_t)(benchmark_last.cycles>>32));
    acc_wr(0xdc,benchmark_last.iterations);acc_wr(0xe0,benchmark_last.cpu_hz);
    acc_wr(0xe4,(uint32_t)benchmark_last.crc[0]|((uint32_t)benchmark_last.crc[1]<<16));
    acc_wr(0xe8,(uint32_t)benchmark_last.crc[2]|((uint32_t)benchmark_last.crc[3]<<16));
    acc_wr(0xec,(uint32_t)benchmark_last.crc[4]|((uint32_t)benchmark_last.valid<<16));
    acc_wr(0xf0,benchmark_last.score_milli);acc_wr(0xf4,benchmark_last.norm_milli);
    acc_wr(0xf8,benchmark_last.luts);acc_wr(0xfc,benchmark_last.per_lut_micro);
    draw(2);acc_wr(0xd0,2);acc_fence();
}
