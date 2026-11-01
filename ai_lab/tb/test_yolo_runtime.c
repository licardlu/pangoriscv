#include "../sw/yolo_runtime.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
static unsigned char memory[65536];
static int fail_io;
static int scalar_reads, scalar_writes, bulk_reads, bulk_writes;
static int fail_read_at, fail_write_at;
static int read64(void *p,uint32_t a,uint64_t *v)
{ (void)p; ++scalar_reads; if(fail_io) return 1; assert(a+8<=sizeof memory); memcpy(v,memory+a,8);return 0; }
static int write64(void *p,uint32_t a,uint64_t v)
{ (void)p; ++scalar_writes; if(fail_io) return 1; assert(a+8<=sizeof memory);memcpy(memory+a,&v,8);return 0; }
static int read_bulk(void *p,uint32_t a,void *dst,uint32_t n)
{ (void)p; ++bulk_reads; if(fail_io || (fail_read_at && !--fail_read_at)) return 1; assert(!(a&7) && !(n&7) && a+n<=sizeof memory);memcpy(dst,memory+a,n);return 0; }
static int write_bulk(void *p,uint32_t a,const void *src,uint32_t n)
{ (void)p; ++bulk_writes; if(fail_io || (fail_write_at && !--fail_write_at)) return 1; assert(!(a&7) && !(n&7) && a+n<=sizeof memory);memcpy(memory+a,src,n);return 0; }
static int8_t scale_q24(int8_t value,uint32_t ratio)
{
    int64_t v=(int64_t)value*ratio;
    uint64_t magnitude=v<0?(uint64_t)(-v):(uint64_t)v;
    int64_t rounded=(int64_t)((magnitude+(1u<<23))>>24);
    if(v<0) rounded=-rounded;
    return rounded>127?127:rounded<-128?-128:(int8_t)rounded;
}

static void compare_paths(uint8_t kind,uint8_t count,uint16_t w,uint16_t h,
                          const uint16_t channels[4])
{
    static unsigned char expected[16384];
    yolo_io_t scalar={.read64=read64,.write64=write64};
    yolo_io_t bulk={.read64=read64,.write64=write64,
                    .read_bulk=read_bulk,.write_bulk=write_bulk};
    yolo_tensor_t tensors[5]={0};
    yolo_op_t op={0};
    uint32_t j,i,n,out_c=kind==YOLO_CONCAT?0:channels[0];
    for(j=0;j<count;j++) {
        tensors[j]=(yolo_tensor_t){j*8192,channels[j],channels[j],h,w,1};
        assert((uint32_t)h*w*channels[j]<=8192);
        for(i=0;i<(uint32_t)h*w*channels[j];i++)
            memory[j*8192+i]=(unsigned char)((i*73+j*29)%256);
        op.inputs[j]=(uint16_t)j;
        op.ratios[j]=(j&1)?3u<<23:1u<<23;
        if(kind==YOLO_CONCAT) out_c+=channels[j];
    }
    tensors[4]=(yolo_tensor_t){32768,(uint16_t)out_c,(uint16_t)out_c,h,w,1};
    if(kind==YOLO_UPSAMPLE) { tensors[4].h*=2;tensors[4].w*=2; }
    n=(uint32_t)tensors[4].h*tensors[4].w*out_c;
    assert(n<=sizeof expected);
    op.kind=kind;op.count=count;op.output=4;
    memset(memory+32768,0xa5,n+8);
    assert(yolo_execute_op(&scalar,&op,tensors)==0);
    memcpy(expected,memory+32768,n);
    memset(memory+32768,0x5a,n+8);
    assert(yolo_execute_op(&bulk,&op,tensors)==0);
    assert(memcmp(expected,memory+32768,n)==0);
    for(i=0;i<8;i++) assert(memory[32768+n+i]==0x5a);
    yolo_runtime_options=7;
    assert(yolo_execute_op(&bulk,&op,tensors)==0);
    assert(memcmp(expected,memory+32768,n)==0);
    yolo_runtime_options=0;
    bulk.read_bulk=0;
    assert(yolo_execute_op(&bulk,&op,tensors)==0);
    assert(memcmp(expected,memory+32768,n)==0);
    bulk.read_bulk=read_bulk;bulk.write_bulk=0;
    assert(yolo_execute_op(&bulk,&op,tensors)==0);
    assert(memcmp(expected,memory+32768,n)==0);
    if(kind==YOLO_ADD) {
        int writes_before=bulk_writes;
        bulk.write_bulk=write_bulk;fail_read_at=2;
        assert(yolo_execute_op(&bulk,&op,tensors)==YOLO_IO);
        assert(bulk_writes==writes_before);
        fail_write_at=2;
        assert(yolo_execute_op(&bulk,&op,tensors)==YOLO_IO);
        assert(bulk_writes==writes_before+2);
    }
}

static void exhaustive_add(void)
{
    const uint32_t ratios[][2]={{1u<<23,1u<<23},{1u<<24,1u<<24},
        {1234567,23456789},{0,0},{UINT32_MAX,UINT32_MAX},
        {UINT32_MAX,1},{0xffffffffu,0xfffffffeu}};
    yolo_io_t io={.read64=read64,.write64=write64,
                  .read_bulk=read_bulk,.write_bulk=write_bulk};
    yolo_tensor_t ts[3]={{0,8,8,1,32,1},{256,8,8,1,32,1},
                         {512,8,8,1,32,1}};
    yolo_op_t add={.kind=YOLO_ADD,.count=2,.inputs={0,1},.output=2};
    uint32_t r,a,b;
    for(r=0;r<sizeof ratios/sizeof ratios[0];r++) {
        add.ratios[0]=ratios[r][0];add.ratios[1]=ratios[r][1];
        for(a=0;a<256;a++) {
            for(b=0;b<256;b++) {memory[b]=(unsigned char)a;memory[256+b]=(unsigned char)b;}
            yolo_runtime_options=YOLO_FAST_LINEAR;
            assert(yolo_execute_op(&io,&add,ts)==0);
            for(b=0;b<256;b++) {
                int64_t v=(int64_t)(int8_t)a*ratios[r][0]+
                          (int64_t)(int8_t)b*ratios[r][1];
                int64_t q=v<0?-((-v+0x800000)>>24):(v+0x800000)>>24;
                int8_t expected=q>127?127:q<-128?-128:(int8_t)q;
                assert((int8_t)memory[512+b]==expected);
            }
        }
    }
    yolo_runtime_options=0;
    puts("EXHAUSTIVE_ADD_PASS 7 ratios x 65536 signed input pairs");
}
int main(void)
{
    yolo_io_t io={.context=0,.read64=read64,.write64=write64,.convolve=0,
                  .read_bulk=read_bulk,.write_bulk=write_bulk};
    yolo_tensor_t t[4]={{0,8,8,2,2,1},{64,8,8,2,2,1},
                         {128,8,8,2,2,1},{256,16,16,2,2,1}};
    yolo_op_t op={0};
    int i;
    yolo_runtime_options=0;
    for(i=0;i<32;i++) {memory[i]=(unsigned char)(int8_t)(i-16); memory[64+i]=2;}
    op.kind=YOLO_ADD;op.count=2;op.inputs[0]=0;op.inputs[1]=1;op.output=2;
    op.ratios[0]=op.ratios[1]=1u<<24;
    assert(yolo_execute_op(&io,&op,t)==0);
    assert(bulk_reads==4 && bulk_writes==2 && scalar_reads==0 && scalar_writes==0);
    for(i=0;i<32;i++) assert((int8_t)memory[128+i]==i-14);
    op.kind=YOLO_CONCAT;op.output=3;
    assert(yolo_execute_op(&io,&op,t)==0);
    assert(bulk_reads==8 && bulk_writes==4 && scalar_reads==0 && scalar_writes==0);
    op.ratios[0]=1u<<23;op.ratios[1]=1u<<25;
    assert(yolo_execute_op(&io,&op,t)==0);
    assert(bulk_reads==12 && bulk_writes==6);
    for(i=0;i<4;i++) {
        int j;
        for(j=0;j<8;j++) {
            assert((int8_t)memory[256+i*16+j]==scale_q24((int8_t)memory[i*8+j],1u<<23));
            assert((int8_t)memory[256+i*16+8+j]==scale_q24((int8_t)memory[64+i*8+j],1u<<25));
        }
    }
    op.kind=YOLO_UPSAMPLE;op.count=1;op.output=2;t[2].h=t[2].w=4;
    op.ratios[0]=1u<<23;
    assert(yolo_execute_op(&io,&op,t)==0);
    assert(bulk_reads==16 && bulk_writes==10 && scalar_reads==0 && scalar_writes==0);
    for(i=0;i<16;i++) {
        int j;
        for(j=0;j<8;j++)
            assert((int8_t)memory[128+i*8+j]==scale_q24(
                ((int8_t *)memory)[((i/4/2)*2+(i%4/2))*8+j],1u<<23));
    }
    op.kind=YOLO_POOL;op.kernel=5;op.stride=1;t[2].h=t[2].w=2;
    assert(yolo_execute_op(&io,&op,t)==0);
    for(i=0;i<32;i++) assert((int8_t)memory[128+i]==8+i%8);
    op.kind=YOLO_ADD;op.count=2;op.ratios[0]=op.ratios[1]=1u<<23;
    memory[0]=(unsigned char)-1;memory[64]=0;
    assert(yolo_execute_op(&io,&op,t)==0);
    assert((int8_t)memory[128]==-1);
    fail_io=1;assert(yolo_execute_op(&io,&op,t)==1);fail_io=0;
    op.output=99;
    assert(yolo_execute_graph(&io,&op,1,t,4,0,0)==YOLO_INVALID);
    {
        yolo_tensor_t wide[3]={{0,256,256,1,1,1},{256,256,256,1,1,1},
                               {512,512,512,1,1,1}};
        int before_reads=scalar_reads,before_writes=scalar_writes;
        for(i=0;i<512;i++) memory[i]=(unsigned char)(int8_t)(i-128);
        op.kind=YOLO_CONCAT;op.count=2;op.inputs[0]=0;op.inputs[1]=1;op.output=2;
        op.ratios[0]=op.ratios[1]=1u<<24;
        assert(yolo_execute_op(&io,&op,wide)==0);
        assert(scalar_reads-before_reads==64 && scalar_writes-before_writes==64);
        assert(memcmp(memory+512,memory,512)==0);
    }
    {
        const uint16_t narrow[4]={8,8,8,8},mixed[4]={8,16,24,32};
        const uint16_t wide[4]={128,128,128,128},fallback[4]={256,256,256,256};
        compare_paths(YOLO_ADD,2,35,2,narrow);
        compare_paths(YOLO_CONCAT,4,9,2,mixed);
        compare_paths(YOLO_CONCAT,4,3,2,wide);
        compare_paths(YOLO_UPSAMPLE,1,19,2,narrow);
        compare_paths(YOLO_UPSAMPLE,1,3,2,wide);
        compare_paths(YOLO_UPSAMPLE,1,3,2,fallback);
    }
    {
        yolo_tensor_t head_t[2]={{0,8,8,1,2,.5f},{8192,33,40,1,2,1}};
        int before=bulk_reads;
        int oc,px;
        op=(yolo_op_t){0};op.kind=YOLO_HEAD;op.count=1;op.output=1;
        op.head_weight=1024;op.head_bias=4096;
        memset(memory,0,sizeof memory);
        for(i=0;i<16;i++) memory[i]=(unsigned char)(int8_t)(i-8);
        for(oc=0;oc<33;oc++) {
            float weight=1,bias=oc*.25f;
            memcpy(memory+1024+(oc*8+oc%8)*4,&weight,4);
            memcpy(memory+4096+oc*4,&bias,4);
        }
        assert(yolo_execute_op(&io,&op,head_t)==0);
        assert(bulk_reads>before);
        for(px=0;px<2;px++) for(oc=0;oc<40;oc++) {
            float got,expected=0;
            if(oc<33) expected=(float)(int8_t)memory[px*8+oc%8]*.5f+oc*.25f;
            memcpy(&got,memory+8192+(px*40+oc)*4,4);
            assert(got==expected);
        }
        fail_read_at=1;
        assert(yolo_execute_op(&io,&op,head_t)==YOLO_IO);
    }
    exhaustive_add();
    puts("CPU_POSTOPS_PASS bulk/scalar/chunk tails/requant/fallback/head/error/bounds");
    return 0;
}
