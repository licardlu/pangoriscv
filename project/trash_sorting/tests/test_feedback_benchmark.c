#include "benchmark.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned status,cursor,commits,runs,paused,valid_result=1;
static unsigned char cells[3520];
static uint32_t registers[11];
uint64_t benchmark_clock(void){return 0;}
uint32_t test_acc_rd(unsigned a){return a==0xd0?status:0;}
void test_acc_wr(unsigned a,uint32_t v){
 if(a==0xc0)cursor=0;
 if(a==0xc4){assert(cursor+4<=sizeof cells);memcpy(cells+cursor,&v,4);cursor+=4;}
 if(a==0xc8){assert(cursor==sizeof cells);commits++;}
 if(a==0xd0){if(v==1)status=(status&~1u)|2u;if(v==2)status=(status&~2u)|8u;if(v==512)status|=1u;}
 if(a>=0xd4&&a<=0xfc)registers[(a-0xd4)/4]=v;
}
int media_player_paused(void){return paused;}
void media_player_pause(int p){paused=p;}
void benchmark_evaluate(benchmark_result_t*r){
 r->valid=r->crc_ok&&r->cycles>=540000000ull;
 r->norm_milli=r->valid?4321:0;r->score_milli=r->valid?233334:0;
}
void benchmark_coremark(benchmark_result_t*r){
 assert(paused && (status&2));runs++;
 unsigned before=commits;benchmark_poll();assert(commits==before); // No nested work.
 memset(r,0,sizeof *r);r->cycles=650000000ull;r->iterations=5000;
 r->cpu_hz=54000000;r->crc_ok=valid_result;r->crc[0]=0xe9f5;
}
int main(int argc,char**argv){
 benchmark_init();assert(commits==1);
 status=4|32;benchmark_poll();benchmark_run_pending();assert(!runs);
 benchmark_request();benchmark_poll();assert(!runs); // poll must never execute it.
 status&=~32u;benchmark_run_pending();assert(!runs); // Waiting for visible page.
 status|=32|64;benchmark_run_pending();assert(!runs); // Page speech still active.
 status&=~64u;benchmark_run_pending();assert(runs==1&&!paused&&benchmark_last.valid);
 assert(registers[6]&0x10000u);assert(memcmp(cells+14*80+5,"4.321",5)==0);
 assert(memcmp(cells+14*80+5,"5.2",3)!=0); // Never clamp to the demo range.
 if(argc>1){FILE*f=fopen(argv[1],"wb");assert(f);assert(fwrite(cells,1,sizeof cells,f)==sizeof cells);fclose(f);}
 paused=1;valid_result=0;benchmark_request();benchmark_poll();benchmark_run_pending();
 assert(runs==2&&paused&&!benchmark_last.valid&&!registers[7]&&!registers[8]);
 assert(memcmp(cells+14*80+5,"---",3)==0);
 status=0;benchmark_poll();status=4|32;benchmark_poll();benchmark_run_pending();assert(runs==2);
 puts("TEST_PASS feedback benchmark: KEY1 request only, visible-page wait, safe-point run, media restore, measured/unclamped result, invalid CRC hides score");
 return 0;
}
