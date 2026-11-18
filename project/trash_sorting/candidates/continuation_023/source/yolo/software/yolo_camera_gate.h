#ifndef YOLO_CAMERA_GATE_H
#define YOLO_CAMERA_GATE_H
#include "yolo_target_policy.h"

/* Camera GAME temporal gate. Probe/static numerical requests never update it.
 * A successful no-target observation is evidence of absence; an inference
 * failure, navigation or waiting for an answer is not. Two agreeing results
 * add one inference interval of latency, not a guarantee against stable FPs. */
typedef struct {
    yolo_box_t previous;
    uint8_t hits, misses, blocked;
} yolo_camera_gate_t;

static inline void yolo_camera_gate_interrupt(yolo_camera_gate_t *gate)
{
    gate->hits=gate->misses=0;
}

static inline int yolo_camera_gate_observe(yolo_camera_gate_t *gate,
                                          const yolo_box_t *box)
{
    if(!box) {
        gate->hits=0;
        if(gate->misses<2)gate->misses++;
        if(gate->misses==2)gate->blocked=0;
        return 0;
    }
    if(!isfinite(box->x1)||!isfinite(box->y1)||!isfinite(box->x2)||
       !isfinite(box->y2)||!isfinite(box->score)||box->score<0||box->score>1||
       box->category>=4||box->x2<=box->x1||box->y2<=box->y1) {
        yolo_camera_gate_interrupt(gate);return 0;
    }
    gate->misses=0;
    if(gate->blocked){gate->hits=0;return 0;}
    float intersection=target_intersection(box,&gate->previous);
    float union_area=target_area(box)+target_area(&gate->previous)-intersection;
    int agrees=gate->hits && box->category==gate->previous.category &&
        intersection>=union_area*.25f;
    gate->previous=*box;
    gate->hits=agrees?2:1;
    if(gate->hits<2)return 0;
    gate->blocked=1;gate->hits=0;return 1;
}
#endif
