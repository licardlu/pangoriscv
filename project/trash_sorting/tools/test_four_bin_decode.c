#include "yolo_decode.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
uint32_t yolo_runtime_options;
static float memory[96];
static int read64(void *context,uint32_t address,uint64_t *word)
{
    (void)context;
    if((address&7) || address>sizeof memory-8) return YOLO_INVALID;
    memcpy(word,(char *)memory+address,8);return 0;
}
static int bulk(void *context,uint32_t address,void *dst,uint32_t n)
{
    (void)context;
    if((address&7) || (n&7) || address>sizeof memory || n>sizeof memory-address)
        return YOLO_INVALID;
    memcpy(dst,(char *)memory+address,n);return 0;
}
int main(void)
{
    yolo_tensor_t heads[3]={{0,3*(5+YOLO_CLASSES),32,1,1,1},{128,3*(5+YOLO_CLASSES),32,1,1,1},{256,3*(5+YOLO_CLASSES),32,1,1,1}};
    yolo_io_t io={.read64=read64,.read_bulk=bulk};
    yolo_decode_config_t cfg={.confidence=.25f,.iou=.45f,.ratio=1,
        .original_w=320,.original_h=320,.strides={8,16,32}};
    yolo_decode_workspace_t work;
    yolo_box_t boxes[YOLO_MAX_RESULTS];
    uint32_t mode,h,a,c,i,n;
    assert((YOLO_CLASSES==4 || YOLO_CLASSES==5) && YOLO_SINGLE_LABEL==1);
    for(h=0;h<3;h++) for(a=0;a<3;a++) {
        cfg.anchors[h][a][0]=10;cfg.anchors[h][a][1]=10;
    }
    for(mode=0;mode<2;mode++) for(h=0;h<3;h++) for(a=0;a<3;a++) for(c=0;c<YOLO_CLASSES;c++) {
        uint32_t base=h*32+a*(5+YOLO_CLASSES);
        yolo_runtime_options=mode?YOLO_FAST_DECODE:0;
        for(i=0;i<96;i++) memory[i]=-20;
        for(i=0;i<4;i++) memory[base+i]=0;
        memory[base+4]=4;memory[base+5+c]=4;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==1 && boxes[0].category==c);
        assert(fabsf(boxes[0].score-.964351f)<1e-5f);
        /* Another bucket over threshold must not duplicate this anchor. */
        memory[base+5+(c+1)%YOLO_CLASSES]=3;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==1 && boxes[0].category==c);
    }
    heads[2].c=33;
    assert(yolo_decode(&io,heads,&cfg,&work,boxes,&n)==YOLO_INVALID);
    printf("FOUR_BIN_DECODE_PASS classes=%u, 9 anchors, scalar/bulk, single-label, schema rejection\n",(unsigned)YOLO_CLASSES);
    return 0;
}
