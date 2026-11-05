/* Execute the real graph, including CPU branches and software FP32 heads.
 * Build with gen/integration/packed on the include path. */
#include "yolo_runtime.h"
#include "deployment_model.h"

int yolo_forward(uint32_t poll_limit, uint64_t *cycles_out, int *bad_op)
{
    yolo_io_t io = {
        .context=&poll_limit, .read64=yolo_acc_read, .write64=yolo_acc_write,
        .convolve=yolo_acc_convolve, .read_bulk=yolo_acc_read_bulk,
        .write_bulk=yolo_acc_write_bulk
    };
    return yolo_execute_graph(&io, yolo_ops, YOLO_N_OPS,
                              yolo_tensors, YOLO_N_TENSORS, bad_op, cycles_out);
}
