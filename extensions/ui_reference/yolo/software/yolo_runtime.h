#ifndef YOLO_RUNTIME_H
#define YOLO_RUNTIME_H
#include <stddef.h>
#include <stdint.h>
#include "acc_regs.h"

enum { YOLO_CONV, YOLO_POOL, YOLO_UPSAMPLE, YOLO_CONCAT, YOLO_ADD, YOLO_HEAD };
enum { YOLO_OK, YOLO_IO, YOLO_TIMEOUT, YOLO_INVALID };
enum { YOLO_FAST_HEAD=1, YOLO_FAST_LINEAR=2, YOLO_FAST_POOL=4,
       YOLO_FAST_DECODE=8, YOLO_FAST_INT_HEAD=16, YOLO_FAST_SPARSE_HEAD=32 };
#define YOLO_PROFILE_OPS 96u
extern uint32_t yolo_runtime_options;
/* Set from the decoder confidence before inference. The default only rejects
 * logits that the decoder's sigmoid already maps to zero. */
extern float yolo_head_logit_floor;
extern uint32_t yolo_op_cycles[YOLO_PROFILE_OPS];
static inline uint32_t yolo_clock(void)
{
#ifdef __riscv
    uint32_t value;
    __asm__ volatile (".option push\n.option arch,+zicsr\ncsrr %0,mcycle\n.option pop"
                      : "=r"(value) :: "memory");
    return value;
#else
    return 0;
#endif
}
typedef struct {
    uint32_t address;
    uint16_t c, padded_c, h, w;
    float scale;
} yolo_tensor_t;

typedef struct {
    uint8_t kind, count, kernel, stride;
    uint16_t inputs[4], output;
    uint32_t ratios[4];  /* input scale / output scale, unsigned Q24 */
    acc_layer_t conv;
    uint32_t head_weight, head_bias; /* FP32 row-major [cout][cin] */
} yolo_op_t;

typedef struct {
    void *context;
    int (*read64)(void *, uint32_t, uint64_t *);
    int (*write64)(void *, uint32_t, uint64_t);
    int (*convolve)(void *, const acc_layer_t *, uint32_t *);
    int (*read_bulk)(void *, uint32_t, void *, uint32_t);
    int (*write_bulk)(void *, uint32_t, const void *, uint32_t);
} yolo_io_t;

/* No heap, OS, or direct CPU DDR mapping is required. All DDR access uses
 * the platform callbacks, which may be the accelerator's idle MMIO window. */
int yolo_execute_op(const yolo_io_t *, const yolo_op_t *, const yolo_tensor_t *);
int yolo_execute_graph(const yolo_io_t *, const yolo_op_t *, size_t,
                       const yolo_tensor_t *, size_t, int *, uint64_t *);
int yolo_acc_read(void *, uint32_t, uint64_t *);
int yolo_acc_write(void *, uint32_t, uint64_t);
int yolo_acc_read_bulk(void *, uint32_t, void *, uint32_t);
int yolo_acc_write_bulk(void *, uint32_t, const void *, uint32_t);
int yolo_acc_convolve(void *, const acc_layer_t *, uint32_t *);
#endif
