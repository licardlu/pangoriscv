#include "yolo_camera_gate.h"
#include <assert.h>
#include <stdio.h>

int main(void){
    yolo_camera_gate_t g={0};
    yolo_box_t a={100,100,140,200,.8f,2},b=a;
    _Static_assert(sizeof(g)<=40,"Temporal state exceeds memory contract");
    assert(!yolo_camera_gate_observe(&g,&a));
    assert(yolo_camera_gate_observe(&g,&a));
    for(unsigned i=0;i<100;i++)assert(!yolo_camera_gate_observe(&g,&a));
    /* Navigation/CRC failure/servo wait may not rearm the same item. */
    yolo_camera_gate_interrupt(&g);assert(g.blocked);
    assert(!yolo_camera_gate_observe(&g,0));
    assert(!yolo_camera_gate_observe(&g,&a)&&g.blocked);
    assert(!yolo_camera_gate_observe(&g,0));
    assert(!yolo_camera_gate_observe(&g,0)&&!g.blocked);
    assert(!yolo_camera_gate_observe(&g,&a));
    b.category=1;assert(!yolo_camera_gate_observe(&g,&b));
    b.x1=500;b.x2=540;assert(!yolo_camera_gate_observe(&g,&b));
    assert(yolo_camera_gate_observe(&g,&b));
    assert(!yolo_camera_gate_observe(&g,0));
    yolo_camera_gate_interrupt(&g);
    assert(!yolo_camera_gate_observe(&g,0)&&g.blocked);
    assert(!yolo_camera_gate_observe(&g,0)&&!g.blocked);
    assert(!yolo_camera_gate_observe(&g,&a));
    yolo_camera_gate_interrupt(&g);
    assert(!yolo_camera_gate_observe(&g,&a));
    b=a;b.score=NAN;assert(!yolo_camera_gate_observe(&g,&b));
    assert(!yolo_camera_gate_observe(&g,&a));
    assert(yolo_camera_gate_observe(&g,&a));
    puts("TEST_PASS camera_gate: two-frame class/IoU, one-shot until two absences, interruption/invalid never rearms, latency contract");
}
