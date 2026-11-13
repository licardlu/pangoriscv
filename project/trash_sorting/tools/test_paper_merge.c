#include "yolo_decode.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

uint32_t yolo_runtime_options;
static float memory[120];
static int read64(void *context,uint32_t address,uint64_t *word)
{
    (void)context;
    if((address&7) || address>sizeof(memory)-8) return YOLO_INVALID;
    memcpy(word,(unsigned char *)memory+address,8);return 0;
}
static int read_bulk(void *context,uint32_t address,void *dst,uint32_t length)
{
    (void)context;
    if((address&7) || (length&7) || address+length>sizeof(memory)) return YOLO_INVALID;
    memcpy(dst,(unsigned char *)memory+address,length);return 0;
}
int main(void)
{
    yolo_tensor_t heads[3]={{0,33,40,1,1,1},{160,33,40,1,1,1},{320,33,40,1,1,1}};
    yolo_io_t io={.read64=read64,.read_bulk=read_bulk};
    yolo_decode_workspace_t work;
    yolo_box_t boxes[YOLO_MAX_RESULTS];
    yolo_decode_config_t cfg={.confidence=.25f,.iou=.45f,.ratio=1,
        .original_w=320,.original_h=320,.strides={8,16,32}};
    uint32_t mode,category,i,h,a,n;
    for(h=0;h<3;h++) for(a=0;a<3;a++) {
        cfg.anchors[h][a][0]=10;cfg.anchors[h][a][1]=10;
    }
    for(mode=0;mode<2;mode++) {
        yolo_runtime_options=mode?YOLO_FAST_DECODE:0;
        for(category=0;category<6;category++) {
            for(i=0;i<120;i++) memory[i]=-20;
            for(i=0;i<4;i++) memory[i]=0;
            memory[4]=4;memory[5+category]=4;
            assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
            assert(n==1 && boxes[0].category==(category==1?4:category));
            assert(fabsf(boxes[0].score-.964351f)<1e-5f);
        }
        /* Same anchor predicts both original paper classes: score stays max. */
        memory[5+5]=-20;memory[5+1]=4;memory[5+4]=3;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==1 && boxes[0].category==4);
        assert(fabsf(boxes[0].score-.964351f)<1e-5f);
        /* Different anchors/heads with overlapping paper classes collapse. */
        for(i=0;i<4;i++) memory[11+i]=0;
        memory[15]=4;memory[11+5+4]=4;
        for(i=0;i<4;i++) memory[40+i]=0;
        /* stride16 uses sigmoid(log(.6))=.375 to share stride8 center4. */
        memory[40]=memory[41]=logf(.6f);
        memory[44]=4;memory[40+5+1]=4;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==1 && boxes[0].category==4);
        /* A distinct metal class at the same location remains. */
        for(i=0;i<4;i++) memory[22+i]=0;
        memory[26]=4;memory[22+5+3]=4;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==2 && boxes[0].category!=boxes[1].category);
        /* A nonoverlapping paper object must survive NMS. */
        memory[40]=3;
        assert(!yolo_decode(&io,heads,&cfg,&work,boxes,&n));
        assert(n==3);
    }
    puts("PAPER_MERGE_PASS six raw IDs, unified NMS, confidence, distinct objects, scalar/bulk");
    return 0;
}
