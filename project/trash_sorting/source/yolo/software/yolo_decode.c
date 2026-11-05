#include "yolo_decode.h"
#include <math.h>
#include <string.h>

static float sigmoid(float x)
{
    if(x>=16) return 1;
    if(x<=-16) return 0;
    return 1.0f/(1.0f+expf(-x));
}
static float overlap(const yolo_box_t *a,const yolo_box_t *b)
{
    float x1=fmaxf(a->x1,b->x1),y1=fmaxf(a->y1,b->y1);
    float x2=fminf(a->x2,b->x2),y2=fminf(a->y2,b->y2);
    float area=fmaxf(0,x2-x1)*fmaxf(0,y2-y1);
    float total=(a->x2-a->x1)*(a->y2-a->y1)+(b->x2-b->x1)*(b->y2-b->y1)-area;
    return total>0 ? area/total : 0;
}
static void insert(yolo_box_t *list,uint16_t *count,uint32_t capacity,yolo_box_t box)
{
    uint32_t at=*count;
    if(at==capacity) {
        if(box.score<=list[at-1].score) return;
        at--;
    } else (*count)++;
    while(at && box.score>list[at-1].score) {
        list[at]=list[at-1];at--;
    }
    list[at]=box;
}
static int read_float(const yolo_io_t *io,uint32_t address,float *v)
{
    uint64_t word;
    uint32_t bits;
    int rc=io->read64(io->context,address&~7u,&word);
    if(rc) return rc;
    bits=(uint32_t)(word>>((address&7)*8));
    memcpy(v,&bits,4);
    return isfinite(*v)?0:YOLO_INVALID;
}

int yolo_decode(const yolo_io_t *io,const yolo_tensor_t heads[3],
                const yolo_decode_config_t *cfg,yolo_decode_workspace_t *work,
                yolo_box_t results[YOLO_MAX_RESULTS],uint32_t *count)
{
    uint32_t h,y,x,a,c;
    float raw_minimum,image_x2,image_y2;
    uint16_t total=0;
    if(!io || !io->read64 || !heads || !cfg || !work || !results || !count ||
       !(cfg->ratio>0) || !isfinite(cfg->ratio) ||
       !isfinite(cfg->pad_x) || !isfinite(cfg->pad_y) ||
       !(cfg->confidence>0 && cfg->confidence<=1) ||
       !(cfg->iou>0 && cfg->iou<=1) || !cfg->original_w || !cfg->original_h)
        return YOLO_INVALID;
    image_x2=cfg->pad_x+cfg->original_w*cfg->ratio;
    image_y2=cfg->pad_y+cfg->original_h*cfg->ratio;
    if(!isfinite(image_x2) || !isfinite(image_y2)) return YOLO_INVALID;
    *count=0;memset(work->counts,0,sizeof work->counts);
    /* Conservative prefilter only: survivors still use the original sigmoid
     * and threshold. The margin retains values near the rounding boundary. */
    raw_minimum=cfg->confidence<1 ?
        logf(cfg->confidence/(1-cfg->confidence))-0.00001f : 16.0f;
    if(raw_minimum>16) raw_minimum=16;
    for(h=0;h<3;h++) {
        const yolo_tensor_t *t=&heads[h];
        if(t->c!=33 || t->padded_c<33 || (t->address&7) ||
           !t->w || !t->h || !(cfg->strides[h]>0)) return YOLO_INVALID;
        for(y=0;y<t->h;y++) for(x=0;x<t->w;x++) for(a=0;a<3;a++) {
            float obj,raw[11],scores[YOLO_CLASSES],best=0;
            uint32_t base=t->address+((y*t->w+x)*t->padded_c+a*11)*4;
            int cached=0;
            int rc=read_float(io,base+16,&obj);
            if(rc) return rc;
            if((yolo_runtime_options&YOLO_FAST_DECODE) &&
               obj<raw_minimum) continue;
            obj=sigmoid(obj);
            if(obj<cfg->confidence) continue;
            /* Six aligned words contain all 11 logits even when the anchor
             * starts in the upper half of a word. Require a padding channel
             * so the last burst cannot read past the tensor's allocation. */
            if((yolo_runtime_options&YOLO_FAST_DECODE) &&
               io->read_bulk && t->padded_c>=34) {
                uint64_t words[6];
                rc=io->read_bulk(io->context,base&~7u,words,sizeof words);
                if(rc) return rc;
                memcpy(raw,(unsigned char *)words+(base&7u),sizeof raw);
                cached=1;
            }
            for(c=0;c<YOLO_CLASSES;c++) {
                rc=cached ? (isfinite(raw[5+c])?0:YOLO_INVALID) :
                    read_float(io,base+(5+c)*4,&raw[5+c]);
                if(rc) return rc;
                scores[c]=obj*sigmoid(raw[5+c]);
                if(scores[c]>best) best=scores[c];
            }
            if(best<cfg->confidence) continue;
            for(c=0;c<4;c++) {
                rc=cached ? (isfinite(raw[c])?0:YOLO_INVALID) :
                    read_float(io,base+c*4,&raw[c]);
                if(rc) return rc;
                raw[c]=sigmoid(raw[c]);
            }
            {
                float cx=(raw[0]*2-0.5f+x)*cfg->strides[h];
                float cy=(raw[1]*2-0.5f+y)*cfg->strides[h];
                float bw=raw[2]*raw[2]*4*cfg->anchors[h][a][0];
                float bh=raw[3]*raw[3]*4*cfg->anchors[h][a][1];
                for(c=0;c<YOLO_CLASSES;c++) if(scores[c]>=cfg->confidence) {
                    yolo_box_t box={cx-bw/2,cy-bh/2,cx+bw/2,cy+bh/2,scores[c],c};
                    /* Padding-only anchors otherwise consume Top-K slots and
                     * become zero-area boxes after clipping to the image. */
                    if(box.x2<=cfg->pad_x || box.y2<=cfg->pad_y ||
                       box.x1>=image_x2 || box.y1>=image_y2) continue;
                    insert(work->candidates[c],&work->counts[c],YOLO_PER_CLASS,box);
                }
            }
        }
    }
    for(c=0;c<YOLO_CLASSES;c++) {
        uint32_t i,j;
        for(i=0;i<work->counts[c];i++) {
            yolo_box_t box=work->candidates[c][i];
            if(box.score<0) continue;
            for(j=i+1;j<work->counts[c];j++)
                if(overlap(&box,&work->candidates[c][j])>cfg->iou)
                    work->candidates[c][j].score=-1;
            box.x1=fminf(cfg->original_w,fmaxf(0,(box.x1-cfg->pad_x)/cfg->ratio));
            box.x2=fminf(cfg->original_w,fmaxf(0,(box.x2-cfg->pad_x)/cfg->ratio));
            box.y1=fminf(cfg->original_h,fmaxf(0,(box.y1-cfg->pad_y)/cfg->ratio));
            box.y2=fminf(cfg->original_h,fmaxf(0,(box.y2-cfg->pad_y)/cfg->ratio));
            if(!(box.x2>box.x1 && box.y2>box.y1)) continue;
            insert(results,&total,YOLO_MAX_RESULTS,box);
        }
    }
    *count=total;
    return 0;
}
