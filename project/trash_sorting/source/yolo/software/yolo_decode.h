#ifndef YOLO_DECODE_H
#define YOLO_DECODE_H
#include "yolo_runtime.h"

#define YOLO_CLASSES 6
#define YOLO_PER_CLASS 32
#define YOLO_MAX_RESULTS 32
typedef struct {
    float x1,y1,x2,y2,score;
    uint32_t category;
} yolo_box_t;
typedef struct {
    yolo_box_t candidates[YOLO_CLASSES][YOLO_PER_CLASS];
    uint16_t counts[YOLO_CLASSES];
} yolo_decode_workspace_t;
typedef struct {
    float anchors[3][3][2], strides[3];
    float confidence,iou,ratio,pad_x,pad_y;
    uint16_t original_w,original_h;
} yolo_decode_config_t;

/* Bounded per-class Top-K before class-aware NMS. Not whole-image voting.
 * Its recall impact must be included in the deployment evaluation. */
int yolo_decode(const yolo_io_t *,const yolo_tensor_t heads[3],
                const yolo_decode_config_t *,yolo_decode_workspace_t *,
                yolo_box_t results[YOLO_MAX_RESULTS],uint32_t *count);
#endif
