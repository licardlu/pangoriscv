#ifndef BENCHMARK_H
#define BENCHMARK_H
#include <stdint.h>
typedef struct {
    uint64_t cycles,instructions;
    uint32_t cpu_hz,iterations,luts;
    /* Scaled units: CoreMark * 1e3; CoreMark/MHz * 1e3;
     * CoreMark per individual LUT * 1e6. Zero LUTs means unmeasured. */
    uint32_t score_milli,norm_milli,per_lut_micro;
    uint16_t crc[5];
    uint8_t crc_ok,valid;
} benchmark_result_t;
void benchmark_evaluate(benchmark_result_t *result);
void benchmark_coremark(benchmark_result_t *result);
void benchmark_init(void);
void benchmark_poll(void);
/* Called only at main-loop safe points, never from capture/receive callbacks. */
void benchmark_run_pending(void);
void benchmark_toggle(void);
void benchmark_request(void);
void benchmark_load_reference(benchmark_result_t *result);
unsigned benchmark_page_active(void);
void benchmark_set_luts(uint32_t luts);
extern benchmark_result_t benchmark_last;
#endif
