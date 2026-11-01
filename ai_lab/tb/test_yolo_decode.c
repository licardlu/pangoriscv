#include "../sw/yolo_decode.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
static float memory[3*40];
static int read64(void *ctx,uint32_t a,uint64_t *word)
{
    (void)ctx;
    if(a>sizeof(memory)-8 || (a&7)) return YOLO_INVALID;
    memcpy(word,(unsigned char *)memory+a,8);return 0;
}
int main(void)
{
    yolo_runtime_options=0;
    yolo_tensor_t heads[3]={{0,33,40,1,1,1},{160,33,40,1,1,1},{320,33,40,1,1,1}};
    yolo_io_t io={.context=0,.read64=read64};
    yolo_decode_workspace_t workspace;
    yolo_box_t boxes[YOLO_MAX_RESULTS];
    yolo_decode_config_t cfg={.confidence=.25f,.iou=.45f,.ratio=1,
        .original_w=320,.original_h=320,.strides={8,16,32}};
    uint32_t n,i,h,a;
    for(i=0;i<120;i++) memory[i]=-20;
    for(h=0;h<3;h++) for(a=0;a<3;a++) {
        cfg.anchors[h][a][0]=10;cfg.anchors[h][a][1]=10;
    }
    /* Two identical class-0 predictions and one overlapping class-1.
     * Same class is suppressed; a different class must remain. */
    for(a=0;a<3;a++) {
        for(i=0;i<4;i++) memory[a*11+i]=0;
        memory[a*11+4]=4;
        memory[a*11+5+(a==2)]=4;
    }
    assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
    assert(n==2);
    assert(boxes[0].category!=boxes[1].category);
    assert(fabsf(boxes[0].score-.964351f)<1e-5f);
    assert(boxes[0].x1==0 && boxes[0].x2==9);
    cfg.ratio=0;
    assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_INVALID);
    puts("DECODE_PASS score=obj*class, class-aware NMS, bounds, invalid config");
    return 0;
}
