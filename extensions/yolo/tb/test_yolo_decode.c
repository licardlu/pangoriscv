#include "../sw/yolo_decode.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
static float memory[3*40];
static uint32_t single_reads,bulk_reads;
static int bulk_error;
static int read64(void *ctx,uint32_t a,uint64_t *word)
{
    (void)ctx;
    if(a>sizeof(memory)-8 || (a&7)) return YOLO_INVALID;
    single_reads++;
    memcpy(word,(unsigned char *)memory+a,8);return 0;
}
static int read_bulk(void *ctx,uint32_t a,void *dst,uint32_t n)
{
    (void)ctx;
    assert(!(a&7) && !(n&7) && a+n<=sizeof memory);
    bulk_reads++;
    if(bulk_error) return YOLO_IO;
    memcpy(dst,(unsigned char *)memory+a,n);return 0;
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
    {
        yolo_box_t expected[YOLO_MAX_RESULTS];
        uint32_t reference_reads=single_reads;
        memcpy(expected,boxes,n*sizeof boxes[0]);
        yolo_runtime_options=YOLO_FAST_DECODE;
        io.read_bulk=read_bulk;single_reads=0;
        assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
        assert(n==2 && !memcmp(expected,boxes,n*sizeof boxes[0]));
        printf("DECODE_TRAFFIC scalar_requests=%u fast_requests=%u\n",
               reference_reads,single_reads+bulk_reads);fflush(stdout);
        assert(bulk_reads==3 && single_reads==9);
        assert(single_reads+bulk_reads<reference_reads);
        bulk_error=1;
        assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_IO);
        bulk_error=0;
        memory[5]=NAN;
        assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_INVALID);
        memory[5]=4;
        io.read_bulk=0;
        assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
        assert(n==2 && !memcmp(expected,boxes,n*sizeof boxes[0]));
        io.read_bulk=read_bulk;
    }
    /* A partially visible edge object remains valid. An anchor entirely in
     * letterbox padding must not become a zero-height detection at y=0. */
    cfg.pad_y=4;
    assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
    assert(n==2 && boxes[0].y1==0 && boxes[0].y2==5);
    cfg.pad_y=70;cfg.ratio=.25f;
    cfg.original_w=1280;cfg.original_h=720;
    assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
    assert(n==0);
    cfg.pad_y=0;cfg.pad_x=9;cfg.ratio=1;
    assert(!yolo_decode(&io,heads,&cfg,&workspace,boxes,&n));
    assert(n==0); /* Touching the edge without positive intersection. */
    cfg.pad_x=0;
    cfg.ratio=INFINITY;
    assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_INVALID);
    cfg.ratio=1;cfg.pad_y=NAN;
    assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_INVALID);
    cfg.pad_y=0;
    cfg.ratio=0;
    assert(yolo_decode(&io,heads,&cfg,&workspace,boxes,&n)==YOLO_INVALID);
    puts("DECODE_PASS score, class-aware NMS, partial edge objects, padding rejection, finite config");
    return 0;
}
