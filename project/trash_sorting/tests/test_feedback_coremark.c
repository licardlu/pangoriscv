#include "benchmark.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 benchmark_result_t r;
 benchmark_coremark(&r);
 assert(r.iterations==5000 && r.crc_ok);
 printf("CRC %04x %04x %04x %04x %04x; native ticks %llu (not board timing)\n",
  r.crc[0],r.crc[1],r.crc[2],r.crc[3],r.crc[4],(unsigned long long)r.cycles);
 r.cpu_hz=54000000;r.iterations=5000;r.cycles=539999999ull;benchmark_evaluate(&r);
 assert(!r.valid&&!r.norm_milli&&!r.score_milli);
 r.cycles=540000000ull;benchmark_evaluate(&r);assert(r.valid&&r.norm_milli==9259);
 assert(r.score_milli==500000 && !r.per_lut_micro);
 /* Known recorded ticks; no dependency on host elapsed time or rounded seconds. */
 r.cpu_hz=120461538;r.iterations=7000;r.cycles=1309328358ull;r.luts=8875;
 benchmark_evaluate(&r);
 assert(r.valid && r.norm_milli==5346 && r.score_milli==644017);
 assert(r.per_lut_micro==72565);
 /* At equal cycles, normalization is independent of the CPU frequency. */
 r.cpu_hz=54000000;benchmark_evaluate(&r);
 assert(r.valid && r.norm_milli==5346 && r.score_milli==288697);
 r.cpu_hz=0;benchmark_evaluate(&r);
 assert(!r.valid && !r.norm_milli && !r.score_milli && !r.per_lut_micro);
 r.cpu_hz=54000000;r.iterations=0;benchmark_evaluate(&r);
 assert(!r.valid && !r.norm_milli && !r.score_milli && !r.per_lut_micro);
 r.iterations=5000;r.cycles=0;benchmark_evaluate(&r);
 assert(!r.valid && !r.norm_milli && !r.score_milli && !r.per_lut_micro);
 r.cycles=540000000ull;
 r.crc_ok=0;benchmark_evaluate(&r);assert(!r.valid&&!r.norm_milli);
 puts("TEST_PASS CoreMark official workload: five CRCs, known-ticks units/frequency invariance, >=10s and invalid-input gating; host only");return 0;
}
