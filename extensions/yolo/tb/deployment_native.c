/* Native memory backend for cross-checking the CPU operators, not a DDR model. */
#include "yolo_runtime.h"
#ifdef NATIVE_DECODE
#include "yolo_decode.h"
#endif
#include <string.h>

static unsigned char memory[0x03000000];

/* Slow scalar stand-in for the RTL arithmetic, used only in the host graph
 * composition check. It reads the same packed weights, bias, M and LUT. */
static int convolve(void *unused, const acc_layer_t *l, uint32_t *cycles)
{
    uint32_t y,x,oc,ky,kx,c;
    (void)unused;
    *cycles=0;
    if(!l->cin || !l->cout || !l->k || l->act>2) return YOLO_INVALID;
    for(y=0;y<l->out_h;y++) for(x=0;x<l->out_w;x++) for(oc=0;oc<l->cout;oc++) {
        int32_t bias,m;
        int64_t acc,scaled,rounded;
        int8_t value;
        memcpy(&bias,memory+l->q_base+oc*4,4);
        memcpy(&m,memory+l->q_base+(l->cout+oc)*4,4);
        acc=bias;
        for(ky=0;ky<l->k;ky++) for(kx=0;kx<l->k;kx++) {
            int iy=(int)(y*l->stride+ky)-l->pad;
            int ix=(int)(x*l->stride+kx)-l->pad;
            if(iy<0 || ix<0 || iy>=l->in_h || ix>=l->in_w) continue;
            for(c=0;c<l->cin;c++) {
                int8_t a=(int8_t)memory[l->a_base+((iy*l->in_w+ix)*l->cin+c)];
                int8_t w=(int8_t)memory[l->w_base+(((oc*l->k+ky)*l->k+kx)*l->cin+c)];
                acc+=(int32_t)a*w;
            }
        }
        if(acc<INT32_MIN || acc>INT32_MAX) return YOLO_INVALID;
        scaled=acc*m;
        rounded=scaled<0 ? -((-scaled+16384)>>15) : (scaled+16384)>>15;
        value=rounded>127 ? 127 : rounded<-128 ? -128 : (int8_t)rounded;
        if(l->act==2) value=(int8_t)memory[l->t_base+(int)value+128];
        else if(l->act==1 && value<0) value=(int8_t)(-((-value+7)/8));
        memory[l->y_base+((y*l->out_w+x)*l->cout+oc)]=(unsigned char)value;
    }
    return 0;
}

static int load64(void *unused, uint32_t a, uint64_t *v)
{
    (void)unused;
    if ((a & 7u) || a > sizeof(memory)-8) return YOLO_INVALID;
    memcpy(v, memory+a, 8);
    return 0;
}
static int store64(void *unused, uint32_t a, uint64_t v)
{
    (void)unused;
    if ((a & 7u) || a > sizeof(memory)-8) return YOLO_INVALID;
    memcpy(memory+a, &v, 8);
    return 0;
}
static int load_bulk(void *unused, uint32_t a, void *dst, uint32_t n)
{
    (void)unused;
    if (!dst || a > sizeof(memory) || n > sizeof(memory)-a) return YOLO_INVALID;
    memcpy(dst, memory+a, n);
    return 0;
}
static int store_bulk(void *unused, uint32_t a, const void *src, uint32_t n)
{
    (void)unused;
    if (!src || a > sizeof(memory) || n > sizeof(memory)-a) return YOLO_INVALID;
    memcpy(memory+a, src, n);
    return 0;
}
int native_put(uint32_t a, const void *p, uint32_t n)
{
    if (a > sizeof(memory) || n > sizeof(memory)-a) return YOLO_INVALID;
    memcpy(memory+a, p, n);
    return 0;
}
int native_get(uint32_t a, void *p, uint32_t n)
{
    if (a > sizeof(memory) || n > sizeof(memory)-a) return YOLO_INVALID;
    memcpy(p, memory+a, n);
    return 0;
}
int native_op(const yolo_op_t *op, const yolo_tensor_t *tensors)
{
    yolo_io_t io = {.context=0,.read64=load64,.write64=store64,
                    .read_bulk=load_bulk,.write_bulk=store_bulk};
    return yolo_execute_op(&io, op, tensors);
}
void native_set_options(uint32_t options)
{
    yolo_runtime_options=options;
}
void native_set_head_floor(float floor)
{
    yolo_head_logit_floor=floor;
}
#ifdef NATIVE_DECODE
static uint32_t decode_bulk_reads;
static int decode_load_bulk(void *unused,uint32_t a,void *dst,uint32_t n)
{
    decode_bulk_reads++;
    return load_bulk(unused,a,dst,n);
}
uint32_t native_decode_bulk_reads(void)
{
    return decode_bulk_reads;
}
int native_decode(const yolo_tensor_t heads[3],float ratio,float pad_x,float pad_y,
                  uint32_t width,uint32_t height,yolo_box_t *boxes,uint32_t *count)
{
    static yolo_decode_workspace_t workspace;
    yolo_io_t io={.read64=load64,.read_bulk=decode_load_bulk};
    yolo_decode_config_t cfg={
        .anchors={{{10,13},{16,30},{33,23}},{{30,61},{62,45},{59,119}},
                  {{116,90},{156,198},{373,326}}},
        .strides={8,16,32},.confidence=.25f,.iou=.45f,.ratio=ratio,
        .pad_x=pad_x,.pad_y=pad_y,.original_w=(uint16_t)width,
        .original_h=(uint16_t)height};
    if(!width || !height || width>UINT16_MAX || height>UINT16_MAX)
        return YOLO_INVALID;
    decode_bulk_reads=0;
    return yolo_decode(&io,heads,&cfg,&workspace,boxes,count);
}
#endif

#ifdef TEST_MAIN
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char **argv)
{
    FILE *blob, *fixture;
    uint32_t header[4], i, passed=0;
    yolo_tensor_t *tensors;
    int full_graph=argc==4 || argc==5;
    if(argc != 3 && !full_graph) return 2;
    yolo_runtime_options=argc==5?(uint32_t)strtoul(argv[4],0,0):0;
    yolo_head_logit_floor=-1.0996123f;
    blob=fopen(argv[1],"rb");
    fixture=fopen(argv[2],"rb");
    if(!blob || !fixture) return 2;
    if(!fread(memory+0x01000000,1,0x01000000,blob)) return 2;
    fclose(blob);
    if(fread(header,sizeof header,1,fixture)!=1 ||
       header[2]!=sizeof(yolo_tensor_t) || header[3]!=sizeof(yolo_op_t)) return 3;
    tensors=calloc(header[0],sizeof(*tensors));
    if(!tensors || fread(tensors,sizeof(*tensors),header[0],fixture)!=header[0]) return 3;
    if(full_graph) {
        FILE *input=fopen(argv[3],"rb");
        if(!input || fread(memory+tensors[0].address,1,320*320*8,input)!=320*320*8)
            return 3;
        fclose(input);
    }
    for(i=0;i<header[1];i++) {
        yolo_op_t op;
        uint32_t n,j;
        unsigned char *expected;
        if(fread(&op,sizeof op,1,fixture)!=1 || fread(&n,4,1,fixture)!=1) return 3;
        expected=malloc(n);
        if(!expected || fread(expected,1,n,fixture)!=n) return 3;
        if(op.kind!=YOLO_CONV || full_graph) {
            yolo_io_t io={
                .context=0,.read64=load64,.write64=store64,.convolve=convolve,
                .read_bulk=load_bulk,.write_bulk=store_bulk
            };
            int rc=yolo_execute_op(&io,&op,tensors);
            if(rc) {fprintf(stderr,"op %u rc %d\n",i,rc);return 4;}
            for(j=0;j<n;j+=op.kind==YOLO_HEAD?4:1) {
                int bad;
                if(op.kind==YOLO_HEAD) {
                    float a,b;
                    memcpy(&a,memory+tensors[op.output].address+j,4);
                    memcpy(&b,expected+j,4);
                    float atol=(yolo_runtime_options&YOLO_FAST_INT_HEAD)?3e-4f:3e-5f;
                    float rtol=(yolo_runtime_options&YOLO_FAST_INT_HEAD)?2e-4f:2e-5f;
                    bad=!isfinite(a) || fabsf(a-b)>atol+rtol*fabsf(b);
                    if((yolo_runtime_options&YOLO_FAST_SPARSE_HEAD) &&
                       (j/4)%40<33 && (j/4)%40%11!=4) {
                        uint32_t pixel=(j/4)/40,anchor=((j/4)%40)/11;
                        float object;
                        memcpy(&object,memory+tensors[op.output].address+
                               (pixel*40+anchor*11+4)*4,4);
                        if(object<yolo_head_logit_floor) bad=a!=0;
                    }
                } else bad=memory[tensors[op.output].address+j]!=expected[j];
                if(bad) {fprintf(stderr,"op %u byte %u mismatch\n",i,j);return 5;}
            }
            passed++;
        }
        if(!full_graph && native_put(tensors[op.output].address,expected,n)) return 6;
        free(expected);
    }
    free(tensors);
    fclose(fixture);
    if(full_graph) printf("NATIVE_FULL_GRAPH_PASS %u operators; flags=%u; scalar conv, no oracle injection\n",
                          passed,yolo_runtime_options);
    else printf("CPU_GRAPH_PASS %u CPU operators; conv supplied by oracle\n",passed);
    return 0;
}
#endif
