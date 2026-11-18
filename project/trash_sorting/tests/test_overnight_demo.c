#include "benchmark.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static uint64_t ticks;
static uint32_t status;
static unsigned cursor,commits;
static unsigned char cells[3520];
static FILE *canvas_trace;
uint64_t benchmark_clock(void){return ticks;}
uint32_t test_acc_rd(unsigned a){return a==0xd0?status:0;}
void test_acc_wr(unsigned a,uint32_t v){
 if(a==0xc0)cursor=0;
 if(a==0xc4){assert(cursor+4<=sizeof cells);memcpy(cells+cursor,&v,4);cursor+=4;}
 if(a==0xc8){
  assert(cursor==sizeof cells);commits++;
  if(canvas_trace)assert(fwrite(cells,1,sizeof cells,canvas_trace)==sizeof cells);
 }
 if(a==0xd0){if(v==1)status=(status&~1u)|2u;if(v==2)status=(status&~2u)|8u;if(v==512)status|=5u;if(v==256)status^=4u;}
 // A demo must never claim a validated CRC/result in the public registers.
 if(a>=0xd4&&a<=0xfc)assert(v==0);
}
static unsigned number(unsigned row,unsigned col){return (unsigned)atoi((char*)cells+row*80+col);}
int main(int argc,char **argv){
 if(argc>2){canvas_trace=fopen(argv[2],"wb");assert(canvas_trace);}
 benchmark_init();assert(commits==1);
 benchmark_toggle();benchmark_poll();assert(commits==1);
 unsigned last_score=0;
 for(unsigned run=0;run<24;run++){
  ticks+=1234567u+run*31337u;benchmark_request();benchmark_poll();assert(status&2u);
  unsigned duration=number(20,53);assert(duration>=18&&duration<=24);
  uint64_t start=ticks;unsigned previous=0;
  for(unsigned second=1;second<duration;second++){
   ticks=start+(uint64_t)second*54000000u;benchmark_poll();
   unsigned p=number(12,53);assert(p>=previous&&p<100);previous=p;assert(status&2u);
  }
  ticks=start+(uint64_t)duration*54000000u-1;benchmark_poll();assert(status&2u);
  ticks++;benchmark_poll();assert(!(status&2u));assert(status&8u);assert(number(12,53)==100);
  char score_text[5];memcpy(score_text,cells+14*80+5,4);score_text[4]=0;
  unsigned score=(unsigned)(atof(score_text)*100.0+0.5);assert(score>=512&&score<=528&&score!=last_score);last_score=score;
  assert(!benchmark_last.valid&&!benchmark_last.crc_ok&&!benchmark_last.cycles&&!benchmark_last.iterations);
  if(run==0&&argc>1){FILE *f=fopen(argv[1],"wb");assert(f);assert(fwrite(cells,1,sizeof cells,f)==sizeof cells);fclose(f);}
 }
 if(canvas_trace)assert(fclose(canvas_trace)==0);
 puts("TEST_PASS demo: 24 runs,18-24 seconds,monotone progress,5.12-5.28,no consecutive equal scores,no validated benchmark/CRC claims");
 return 0;
}
