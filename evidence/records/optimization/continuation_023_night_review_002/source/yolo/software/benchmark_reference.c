#include "benchmark.h"
#include <string.h>
/* CPU014 values supplied by the user, traceable in the paired record JSON.
 * This compilation unit only loads stored data and executes no benchmark. */
void benchmark_load_reference(benchmark_result_t *r) {
    memset(r,0,sizeof *r);
    r->cycles=1309328358ull;r->cpu_hz=120461538u;r->iterations=7000u;r->luts=8907u;
    r->crc[0]=0xe9f5;r->crc[1]=0xe714;r->crc[2]=0x1fd7;r->crc[3]=0x8e3a;r->crc[4]=0x25b5;
    r->crc_ok=1;r->valid=1;
    uint64_t n=r->iterations,hz=r->cpu_hz,c=r->cycles;
    r->score_milli=(uint32_t)((n*hz*1000u+c/2)/c);
    r->norm_milli=(uint32_t)((n*1000000000ull+c/2)/c);
    if(r->luts)r->per_lut_micro=(uint32_t)((n*hz*1000000ull+c*r->luts/2)/(c*r->luts));
}
