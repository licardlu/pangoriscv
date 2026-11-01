#include "../sw/yolo_runtime.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static unsigned char memory[65536];
static uint32_t input_end, input_reads;
static int read64(void *ctx,uint32_t a,uint64_t *v)
{
    (void)ctx; assert(a+8<=sizeof memory);
    if(a<input_end) input_reads++;
    memcpy(v,memory+a,8);return 0;
}
static int write64(void *ctx,uint32_t a,uint64_t v)
{
    (void)ctx;assert(a+8<=sizeof memory);memcpy(memory+a,&v,8);return 0;
}
static int read_bulk(void *ctx,uint32_t a,void *dst,uint32_t n)
{
    (void)ctx;assert(a+n<=sizeof memory);
    if(a<input_end) input_reads+=n/8;
    memcpy(dst,memory+a,n);return 0;
}
static int write_bulk(void *ctx,uint32_t a,const void *src,uint32_t n)
{
    (void)ctx;assert(a+n<=sizeof memory);memcpy(memory+a,src,n);return 0;
}
int main(void)
{
    yolo_io_t io={.read64=read64,.write64=write64,
                  .read_bulk=read_bulk,.write_bulk=write_bulk};
    yolo_tensor_t t[2]={{0,256,256,2,3,.06690508f},
                       {49152,33,40,2,3,1}};
    yolo_op_t op={.kind=YOLO_HEAD,.count=1,.output=1,
                  .head_weight=2048,.head_bias=40000};
    uint32_t i,oc,px;
    float worst=0;
    yolo_runtime_options=YOLO_FAST_HEAD;
    input_end=2*3*256;
    for(i=0;i<input_end;i++) memory[i]=(unsigned char)(int8_t)(i*73u+19u);
    for(oc=0;oc<33;oc++) {
        float bias=(float)((int)oc-16)/32;
        memcpy(memory+op.head_bias+oc*4,&bias,4);
        for(i=0;i<256;i++) {
            float w=(float)((int)((i*29u+oc*53u)%4096)-2048)/8192;
            memcpy(memory+op.head_weight+(oc*256+i)*4,&w,4);
        }
    }
    assert(yolo_execute_op(&io,&op,t)==0);
    for(px=0;px<6;px++) for(oc=0;oc<40;oc++) {
        float got,expected=0;
        if(oc<33) {
            memcpy(&expected,memory+op.head_bias+oc*4,4);
            for(i=0;i<256;i++) {
                float w,input=(float)(int8_t)memory[px*256+i]*t[0].scale;
                memcpy(&w,memory+op.head_weight+(oc*256+i)*4,4);
                expected+=input*w;
            }
        }
        memcpy(&got,memory+49152+(px*40+oc)*4,4);
        if(fabsf(got-expected)>worst) worst=fabsf(got-expected);
        assert(isfinite(got) && fabsf(got-expected)<=3e-5f+2e-5f*fabsf(expected));
    }
    assert(input_reads<=5*(input_end/8));
    /* Check every real head width, including the 33-channel tail and the
     * boundary after the output tensor. Count actual feature-map reads. */
    for(i=64;i<=256;i*=2) {
        uint32_t c,channels=i;
        t[0].c=t[0].padded_c=(uint16_t)channels;
        input_end=6*channels;input_reads=0;
        for(c=0;c<input_end;c++) memory[c]=(unsigned char)(int8_t)(c*73u+19u);
        for(oc=0;oc<33;oc++) for(c=0;c<channels;c++) {
            float w=(float)((int)((c*29u+oc*53u)%4096)-2048)/8192;
            memcpy(memory+op.head_weight+(oc*channels+c)*4,&w,4);
        }
        memset(memory+49152,0xa5,6*40*4+8);
        yolo_runtime_options=YOLO_FAST_HEAD|YOLO_FAST_INT_HEAD;
        assert(yolo_execute_op(&io,&op,t)==0);
        for(px=0;px<6;px++) for(oc=0;oc<40;oc++) {
            float got,expected=0;
            if(oc<33) {
                memcpy(&expected,memory+op.head_bias+oc*4,4);
                for(c=0;c<channels;c++) {
                    float w,input=(float)(int8_t)memory[px*channels+c]*t[0].scale;
                    memcpy(&w,memory+op.head_weight+(oc*channels+c)*4,4);
                    expected+=input*w;
                }
            }
            memcpy(&got,memory+49152+(px*40+oc)*4,4);
            assert(isfinite(got) && fabsf(got-expected)<.001f+2e-5f*fabsf(expected));
        }
        for(c=0;c<8;c++) assert(memory[49152+6*40*4+c]==0xa5);
        assert(input_reads==(channels==64?1u:channels==128?2u:3u)*(input_end/8));
    }
    t[0].c=t[0].padded_c=256;
    input_end=6*256;
    /* Low-objectness anchors cannot survive a confidence threshold. Keep
     * their objectness but leave the unused coordinate/class logits zero. */
    {
        uint32_t c;
        float bias;
        memset(memory,0,sizeof memory);
        for(c=0;c<input_end;c++) memory[c]=(unsigned char)(int8_t)(c*17u+9u);
        for(oc=0;oc<33;oc++) {
            bias=oc==4?-2.0f:oc==15?0.0f:oc==26?-1.099f:0.125f;
            memcpy(memory+op.head_bias+oc*4,&bias,4);
        }
        yolo_runtime_options=1u|16u|32u;
        yolo_head_logit_floor=-1.0996123f;
        assert(yolo_execute_op(&io,&op,t)==0);
        for(px=0;px<6;px++) for(oc=0;oc<40;oc++) {
            float got,expected=oc<33?0.125f:0;
            if(oc==4) expected=-2.0f;
            else if(oc==15) expected=0;
            else if(oc==26) expected=-1.099f;
            else if(oc<11) expected=0;
            memcpy(&got,memory+49152+(px*40+oc)*4,4);
            assert(got==expected);
        }
    }
    yolo_runtime_options=YOLO_FAST_HEAD|YOLO_FAST_LINEAR|YOLO_FAST_POOL;
    printf("HEAD_CHECK input_word_reads=%u worst_logit_error=%g\n",input_reads,worst);
    fflush(stdout);
    /* Four large products exceed INT32; the guarded path must widen them. */
    input_reads=0;
    {
        float weight=-.49f,bias=0,got,expected=0;
        memset(memory,0,sizeof memory);
        for(i=0;i<input_end;i++) memory[i]=(unsigned char)-128;
        for(oc=0;oc<33;oc++) {
            memcpy(memory+op.head_bias+oc*4,&bias,4);
            for(i=0;i<256;i++)
                memcpy(memory+op.head_weight+(oc*256+i)*4,&weight,4);
        }
        for(i=0;i<256;i++) expected+=(-128*t[0].scale)*weight;
        assert(yolo_execute_op(&io,&op,t)==0);
        memcpy(&got,memory+49152,4);
        assert(fabsf(got-expected)<.001f+2e-5f*fabsf(expected));
    }
    memset(memory,0,sizeof memory);
    t[0]=(yolo_tensor_t){0,128,128,10,10,1};
    t[1]=(yolo_tensor_t){32768,128,128,10,10,1};
    op=(yolo_op_t){.kind=YOLO_POOL,.count=1,.output=1,.kernel=5,.stride=1};
    input_end=12800;input_reads=0;
    for(i=0;i<input_end;i++) memory[i]=(unsigned char)(int8_t)(i*41u+i/127u);
    assert(yolo_execute_op(&io,&op,t)==0);
    for(i=0;i<input_end;i++) {
        int y=(int)(i/128/10),x=(int)(i/128%10),c=(int)(i%128);
        int ky,kx,best=-128;
        for(ky=-2;ky<=2;ky++) for(kx=-2;kx<=2;kx++)
            if(y+ky>=0 && y+ky<10 && x+kx>=0 && x+kx<10) {
                int value=(int8_t)memory[((y+ky)*10+x+kx)*128+c];
                if(value>best) best=value;
            }
        assert((int8_t)memory[32768+i]==best);
    }
    printf("POOL_CHECK input_word_reads=%u\n",input_reads);fflush(stdout);
    assert(input_reads==input_end/8);
    puts("CPU_PERF_CHECK_PASS head/logits/padding/pool/bandwidth");
    return 0;
}
