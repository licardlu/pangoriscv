#include "yolo_runtime.h"
#include <string.h>

uint32_t yolo_runtime_options=YOLO_FAST_HEAD|YOLO_FAST_LINEAR|YOLO_FAST_POOL|
                               YOLO_FAST_DECODE|YOLO_FAST_INT_HEAD|YOLO_FAST_SPARSE_HEAD;
float yolo_head_logit_floor=-16.0f;
uint32_t yolo_op_cycles[YOLO_PROFILE_OPS];
/* Operators run sequentially; head weights and pooling rows share storage.
 * Legacy 32 KiB platforms keep the scalar path and its smaller RAM footprint. */
#if defined(VEXII_PLATFORM) || !defined(__riscv)
#define YOLO_CACHED_RUNTIME 1
static union {
    int32_t head_q24[8][256];
    int16_t head_q16[4096];
    int8_t pool[5][1536];
    unsigned char scale_lut[4][256];
    struct {
        int32_t whole[2][256];
        uint32_t fraction[2][256];
    } add;
} scratch;
#endif

static int8_t clip(int64_t v)
{
    return v > 127 ? 127 : v < -128 ? -128 : (int8_t)v;
}

static int64_t rounded_q24(int64_t v)
{
    uint64_t magnitude = v < 0 ? (uint64_t)(-v) : (uint64_t)v;
    int64_t result = (int64_t)((magnitude + (1u << 23)) >> 24);
    return v < 0 ? -result : result;
}

static uint32_t address(const yolo_tensor_t *t, uint32_t y, uint32_t x, uint32_t c)
{
    return t->address + ((y * t->w + x) * t->padded_c + c);
}

static int float_read(const yolo_io_t *io, uint32_t a, float *value)
{
    uint64_t word;
    uint32_t bits;
    int rc = io->read64(io->context, a & ~7u, &word);
    if (rc) return rc;
    bits = (uint32_t)(word >> ((a & 7u) * 8));
    memcpy(value, &bits, sizeof bits);
    return 0;
}

static int read_bytes(const yolo_io_t *io, uint32_t a, void *dst, uint32_t n)
{
    unsigned char *p = (unsigned char *)dst;
    uint32_t i;
    if (io->read_bulk) return io->read_bulk(io->context, a, dst, n);
    if (!io->read64 || (a & 7u) || (n & 7u)) return YOLO_INVALID;
    for (i = 0; i < n; i += 8) {
        uint64_t word;
        int rc = io->read64(io->context, a + i, &word);
        if (rc) return rc;
        memcpy(p + i, &word, 8);
    }
    return 0;
}

static int write_bytes(const yolo_io_t *io, uint32_t a,
                       const void *src, uint32_t n)
{
    const unsigned char *p = (const unsigned char *)src;
    uint32_t i;
    if (io->write_bulk) return io->write_bulk(io->context, a, src, n);
    if (!io->write64 || (a & 7u) || (n & 7u)) return YOLO_INVALID;
    for (i = 0; i < n; i += 8) {
        uint64_t word;
        memcpy(&word, p + i, 8);
        {
            int rc = io->write64(io->context, a + i, word);
            if (rc) return rc;
        }
    }
    return 0;
}

static void scale_bytes(unsigned char *dst,const unsigned char *src,
                        uint32_t n,uint32_t ratio,uint32_t slot)
{
    uint32_t i;
    if((yolo_runtime_options&YOLO_FAST_LINEAR) && ratio==(1u<<24)) {
        memcpy(dst,src,n);return;
    }
#ifdef YOLO_CACHED_RUNTIME
    if(yolo_runtime_options&YOLO_FAST_LINEAR) {
        for(i=0;i<n;i++) dst[i]=scratch.scale_lut[slot][src[i]];
        return;
    }
#else
    (void)slot;
#endif
    for(i=0;i<n;i++)
        dst[i]=(unsigned char)clip(rounded_q24((int64_t)(int8_t)src[i]*ratio));
}

static int execute_bulk_linear(const yolo_io_t *io, const yolo_op_t *op,
                               const yolo_tensor_t *tensors)
{
    enum { CHUNK_BYTES = 1024 };
    unsigned char input[4][CHUNK_BYTES];
    unsigned char output[CHUNK_BYTES];
    const yolo_tensor_t *out = &tensors[op->output];
    const yolo_tensor_t *in = &tensors[op->inputs[0]];
    uint32_t y;

    if (op->kind == YOLO_ADD) {
        uint32_t row_bytes = (uint32_t)out->w * out->c;
#ifdef YOLO_CACHED_RUNTIME
        int fast=(yolo_runtime_options&YOLO_FAST_LINEAR)!=0;
        if(fast) {
            uint32_t j,i;
            for(j=0;j<2;j++) for(i=0;i<256;i++) {
                int64_t product=(int64_t)(int8_t)i*op->ratios[j];
                int32_t whole=(int32_t)(product>=0 ? product>>24 :
                                      -((-product+0xffffff)>>24));
                scratch.add.whole[j][i]=whole;
                scratch.add.fraction[j][i]=(uint32_t)(
                    product-(int64_t)whole*0x1000000);
            }
        }
#endif
        for (y = 0; y < out->h; ++y) {
            uint32_t off;
            for (off = 0; off < row_bytes; off += CHUNK_BYTES) {
                uint32_t n = row_bytes - off;
                uint32_t i;
                int rc;
                if (n > CHUNK_BYTES) n = CHUNK_BYTES;
                rc = read_bytes(io, address(in, y, 0, off), input[0], n);
                if (rc) return rc;
                rc = read_bytes(io,
                    address(&tensors[op->inputs[1]], y, 0, off), input[1], n);
                if (rc) return rc;
                for (i = 0; i < n; ++i) {
                    int64_t v;
#ifdef YOLO_CACHED_RUNTIME
                    if(fast) {
                        uint32_t a=input[0][i],b=input[1][i];
                        uint32_t fraction=scratch.add.fraction[0][a]+
                                          scratch.add.fraction[1][b];
                        int32_t whole=scratch.add.whole[0][a]+
                                      scratch.add.whole[1][b]+(fraction>>24);
                        fraction&=0xffffffu;
                        /* Round halfway cases away from zero, including
                         * negative sums whose low 24 bits equal one half. */
                        whole+=(fraction>0x800000u ||
                                (fraction==0x800000u && whole>=0));
                        output[i]=(unsigned char)(whole>127?127:
                                                  whole<-128?-128:whole);
                        continue;
                    }
#endif
                    v=(int64_t)(int8_t)input[0][i]*op->ratios[0]
                     +(int64_t)(int8_t)input[1][i]*op->ratios[1];
                    output[i] = (unsigned char)clip(rounded_q24(v));
                }
                rc = write_bytes(io, address(out, y, 0, off), output, n);
                if (rc) return rc;
            }
        }
        return 0;
    }

    if (op->kind == YOLO_CONCAT && out->c <= CHUNK_BYTES) {
        for (y = 0; y < out->h; ++y) {
            uint32_t x;
            for (x = 0; x < out->w;) {
                uint32_t pixels = CHUNK_BYTES / out->c;
                uint32_t j, px, channel = 0, out_bytes;
                int rc;
                if (pixels > out->w - x) pixels = out->w - x;
                out_bytes = pixels * out->c;
                for (j = 0; j < op->count; ++j) {
                    const yolo_tensor_t *src = &tensors[op->inputs[j]];
                    rc = read_bytes(io, address(src, y, x, 0), input[j],
                                    pixels * src->c);
                    if (rc) return rc;
                }
                for (px = 0; px < pixels; ++px) {
                    channel = 0;
                    for (j = 0; j < op->count; ++j) {
                        const yolo_tensor_t *src = &tensors[op->inputs[j]];
                        scale_bytes(output+px*out->c+channel,
                                    input[j]+px*src->c,src->c,op->ratios[j],j);
                        channel += src->c;
                    }
                }
                rc = write_bytes(io, address(out, y, x, 0), output, out_bytes);
                if (rc) return rc;
                x += pixels;
            }
        }
        return 0;
    }

    if (op->kind == YOLO_UPSAMPLE && out->c <= CHUNK_BYTES / 2) {
        uint32_t step=(yolo_runtime_options&YOLO_FAST_LINEAR)?2u:1u;
        for (y = 0; y < out->h; y+=step) {
            uint32_t sx;
            for (sx = 0; sx < in->w;) {
                uint32_t pixels = CHUNK_BYTES / (2u * out->c);
                uint32_t px, out_bytes;
                int rc;
                if (pixels > in->w - sx) pixels = in->w - sx;
                rc = read_bytes(io, address(in, y / 2, sx, 0), input[0],
                                pixels * in->c);
                if (rc) return rc;
                out_bytes = pixels * 2u * out->c;
                for (px = 0; px < pixels; ++px) {
                    uint32_t ch;
                    for (ch = 0; ch < out->c; ++ch) {
                        unsigned char scaled;
                        if((yolo_runtime_options&YOLO_FAST_LINEAR) &&
                           op->ratios[0]==(1u<<24))
                            scaled=input[0][px*in->c+ch];
                        else {
                            int64_t value=(int64_t)(int8_t)input[0][px*in->c+ch]
                                          *op->ratios[0];
                            scaled=(unsigned char)clip(rounded_q24(value));
                        }
                        output[(2u * px) * out->c + ch] = scaled;
                        output[(2u * px + 1u) * out->c + ch] = scaled;
                    }
                }
                rc = write_bytes(io, address(out, y, 2u * sx, 0),
                                 output, out_bytes);
                if (rc) return rc;
                if(step==2) {
                    rc=write_bytes(io,address(out,y+1,2u*sx,0),output,out_bytes);
                    if(rc) return rc;
                }
                sx += pixels;
            }
        }
        return 0;
    }
    return YOLO_INVALID;
}

static int concat_wide(const yolo_io_t *io,const yolo_op_t *op,
                       const yolo_tensor_t *tensors)
{
    const yolo_tensor_t *out=&tensors[op->output];
    unsigned char input[1024],output[1024];
    uint32_t px,j;
    for(px=0;px<(uint32_t)out->h*out->w;px++) {
        uint32_t channel=0;
        for(j=0;j<op->count;j++) {
            const yolo_tensor_t *src=&tensors[op->inputs[j]];
            uint32_t c;
            for(c=0;c<src->c;c+=sizeof input) {
                uint32_t n=src->c-c;
                int rc;
                if(n>sizeof input) n=sizeof input;
                rc=read_bytes(io,src->address+px*src->c+c,input,n);
                if(rc) return rc;
                scale_bytes(output,input,n,op->ratios[j],j);
                rc=write_bytes(io,out->address+px*out->c+channel+c,output,n);
                if(rc) return rc;
            }
            channel+=src->c;
        }
    }
    return 0;
}

static int head_scalar(const yolo_io_t *io, const yolo_op_t *op,
                const yolo_tensor_t *tensors)
{
    const yolo_tensor_t *in = &tensors[op->inputs[0]], *out = &tensors[op->output];
    uint32_t y, x, oc, c;
    if (out->c != 33 || in->c > 256 || in->h != out->h || in->w != out->w ||
        in->padded_c != in->c || (in->c & 7) || out->padded_c != 40)
        return YOLO_INVALID;
    /* Two output rows fit the 16 KiB CPU RAM budget. Reading FP32 weights
     * through the mailbox for every individual MAC is prohibitively costly. */
    for (oc = 0; oc < out->padded_c; oc += 2) {
        float weights[2][256], bias[2]={0,0};
        uint32_t j;
        for(j=0;j<2;j++) if(oc+j<out->c) {
            int rc=float_read(io,op->head_bias+(oc+j)*4,&bias[j]);
            if(rc) return rc;
            rc=read_bytes(io,op->head_weight+(oc+j)*in->c*4,
                          weights[j],(uint32_t)in->c*4);
            if(rc) return rc;
        }
        for (y = 0; y < out->h; y++) for (x = 0; x < out->w; x++) {
        float input[256],values[2]={bias[0],bias[1]};
        int8_t bytes[256];
        uint64_t packed=0;
        {
            int rc=read_bytes(io,address(in,y,x,0),bytes,in->c);
            if (rc) return rc;
        }
        for(c=0;c<in->c;c++) input[c]=(float)bytes[c]*in->scale;
            for (j = 0; j < 2; j++) if (oc+j < out->c) {
                for(c = 0; c < in->c; c++) values[j]+=input[c]*weights[j][c];
            }
            memcpy(&packed, values, sizeof packed);
            {
                uint32_t a = out->address + ((y*out->w+x)*out->padded_c+oc)*4;
                int rc = io->write64(io->context, a, packed);
                if(rc) return rc;
            }
        }
    }
    return 0;
}

#ifdef YOLO_CACHED_RUNTIME
#ifdef __GNUC__
__attribute__((optimize("O3")))
#endif
static int64_t head_dot(const int8_t *input,const int32_t *weight,
                        uint32_t channels,int partial_safe)
{
    uint32_t c;
    int64_t sum=0;
    if(partial_safe) {
        /* Weight-load validation bounds every four-term sum for all INT8
         * inputs, so no signed overflow occurs before widening. */
        for(c=0;c<channels;c+=4) {
            int32_t partial=(int32_t)input[c]*weight[c]
                           +(int32_t)input[c+1]*weight[c+1]
                           +(int32_t)input[c+2]*weight[c+2]
                           +(int32_t)input[c+3]*weight[c+3];
            sum+=partial;
        }
    } else for(c=0;c<channels;c++) sum+=(int64_t)input[c]*weight[c];
    return sum;
}

#ifdef __GNUC__
__attribute__((optimize("O3")))
#endif
static int32_t head_dot_q16_i16(const int8_t *input,const int16_t *weight,
                                uint32_t channels)
{
    uint32_t c;
    int32_t sum=0;
    for(c=0;c<channels;c+=4)
        sum+=(int32_t)input[c]*weight[c]
            +(int32_t)input[c+1]*weight[c+1]
            +(int32_t)input[c+2]*weight[c+2]
            +(int32_t)input[c+3]*weight[c+3];
    return sum;
}

static int head_load_q16(const yolo_io_t *io,uint32_t address,
                         uint32_t channels,int16_t *target)
{
    float weights[256];
    uint32_t c,bound=0;
    int rc=read_bytes(io,address,weights,channels*4u);
    if(rc) return rc;
    for(c=0;c<channels;c++) {
        float value=weights[c]*65536.0f;
        int32_t q;
        if(!(value>=-32768.0f && value<=32767.0f)) return YOLO_INVALID;
        q=(int32_t)(value>=0?value+.5f:value-.5f);
        if(q<INT16_MIN || q>INT16_MAX) return YOLO_INVALID;
        target[c]=(int16_t)q;
        bound+=(uint32_t)(q<0?-q:q)*128u;
    }
    /* 256 products of INT8 and INT16 fit in unsigned 32 bits. */
    return bound>INT32_MAX?YOLO_INVALID:0;
}

static int head_cached_q16(const yolo_io_t *io,const yolo_op_t *op,
                           const yolo_tensor_t *in,const yolo_tensor_t *out)
{
    uint32_t oc,px,j,c;
    int sparse=(yolo_runtime_options&YOLO_FAST_SPARSE_HEAD)!=0;
    int16_t object_weights[3][256];
    float object_bias[3],factor=in->scale/65536.0f;
    uint32_t capacity=(uint32_t)(sizeof scratch.head_q16 /
                                sizeof scratch.head_q16[0])/in->c;
    capacity&=~7u;
    if(capacity>40) capacity=40;
    if(sparse) for(j=0;j<3;j++) {
        int rc=float_read(io,op->head_bias+(j*11+4)*4,&object_bias[j]);
        if(rc) return rc;
        rc=head_load_q16(io,op->head_weight+(j*11+4)*in->c*4,
                         in->c,object_weights[j]);
        if(rc) return rc;
    }
    for(oc=0;oc<out->padded_c;) {
        uint32_t block=out->padded_c-oc;
        float biases[40]={0};
        if(block>capacity) block=capacity;
        for(j=0;j<block && oc+j<out->c;j++) {
            int rc=float_read(io,op->head_bias+(oc+j)*4,&biases[j]);
            if(rc) return rc;
            rc=head_load_q16(io,op->head_weight+(oc+j)*in->c*4,
                             in->c,scratch.head_q16+j*in->c);
            if(rc) return rc;
        }
        for(px=0;px<(uint32_t)out->h*out->w;px++) {
            int8_t input[256];
            float values[40]={0};
            float object[3]={0};
            int rc=read_bytes(io,in->address+px*in->c,input,in->c);
            if(rc) return rc;
            if(sparse) for(c=0;c<3;c++)
                object[c]=(float)head_dot_q16_i16(input,object_weights[c],in->c)
                          *factor+object_bias[c];
            for(j=0;j<block && oc+j<out->c;j++) {
                uint32_t anchor=(oc+j)/11;
                if(sparse && (oc+j)%11==4) values[j]=object[anchor];
                else if(!sparse || object[anchor]>=yolo_head_logit_floor) {
                    int32_t sum=head_dot_q16_i16(input,scratch.head_q16+j*in->c,in->c);
                    values[j]=(float)sum*factor+biases[j];
                }
            }
            rc=write_bytes(io,out->address+(px*out->padded_c+oc)*4,
                           values,block*4u);
            if(rc) return rc;
        }
        oc+=block;
    }
    return 0;
}

static int head_cached(const yolo_io_t *io,const yolo_op_t *op,
                       const yolo_tensor_t *tensors)
{
    const yolo_tensor_t *in=&tensors[op->inputs[0]],*out=&tensors[op->output];
    uint32_t oc,px,j,c;
    if(out->c!=33 || !in->c || in->c>256 || in->h!=out->h || in->w!=out->w ||
       in->padded_c!=in->c || (in->c&7) || out->padded_c!=40)
        return YOLO_INVALID;
    int q16=(yolo_runtime_options&YOLO_FAST_INT_HEAD)!=0;
    if(q16) return head_cached_q16(io,op,in,out);
    for(oc=0;oc<out->padded_c;oc+=8) {
        float biases[8]={0},weights[256];
        int safe[8]={0};
        for(j=0;j<8 && oc+j<out->c;j++) {
            int rc=float_read(io,op->head_bias+(oc+j)*4,&biases[j]);
            if(rc) return rc;
            rc=read_bytes(io,op->head_weight+(oc+j)*in->c*4,weights,in->c*4u);
            if(rc) return rc;
            for(c=0;c<in->c;c++) {
                float value=weights[c]*16777216.0f;
                if(!(value>=-2147483520.0f && value<=2147483520.0f))
                    return YOLO_INVALID;
                scratch.head_q24[j][c]=(int32_t)(value>=0?value+.5f:value-.5f);
            }
            safe[j]=1;
            for(c=0;c<in->c;c+=4) {
                uint32_t k;
                uint64_t bound=0;
                for(k=0;k<4;k++) {
                    int64_t w=scratch.head_q24[j][c+k];
                    bound+=(uint64_t)(w<0?-w:w)*128u;
                }
                if(bound>INT32_MAX) safe[j]=0;
            }
        }
        for(px=0;px<(uint32_t)out->h*out->w;px++) {
            int8_t input[256];
            float values[8]={0};
            int rc=read_bytes(io,in->address+px*in->c,input,in->c);
            if(rc) return rc;
            for(j=0;j<8 && oc+j<out->c;j++) {
                int64_t sum=head_dot(input,scratch.head_q24[j],in->c,safe[j]);
                values[j]=(float)sum*(in->scale/16777216.0f)+biases[j];
            }
            rc=write_bytes(io,out->address+(px*out->padded_c+oc)*4,
                           values,sizeof values);
            if(rc) return rc;
        }
    }
    return 0;
}

static int pool_cached(const yolo_io_t *io,const yolo_tensor_t *in,
                       const yolo_tensor_t *out)
{
    int8_t result[1536];
    uint32_t row=(uint32_t)in->w*in->c,y,x,c,next=0;
    for(y=0;y<out->h;y++) {
        while(next<in->h && next<=y+2) {
            int rc=read_bytes(io,in->address+next*row,result,row);
            if(rc) return rc;
            /* A square maximum is separable: cache each horizontal maximum
             * once, then only compare the five cached rows for every output. */
            for(x=0;x<in->w;x++) for(c=0;c<in->c;c++) {
                int kx,best=-128;
                for(kx=-2;kx<=2;kx++) {
                    int xx=(int)x+kx;
                    if(xx>=0 && xx<in->w) {
                        int value=result[(uint32_t)xx*in->c+c];
                        if(value>best) best=value;
                    }
                }
                scratch.pool[next%5][x*in->c+c]=(int8_t)best;
            }
            next++;
        }
        for(x=0;x<out->w;x++) for(c=0;c<out->c;c++) {
            int ky,best=-128;
            for(ky=-2;ky<=2;ky++) {
                int yy=(int)y+ky;
                if(yy<0 || yy>=in->h) continue;
                {
                    int value=scratch.pool[(uint32_t)yy%5][x*in->c+c];
                    if(value>best) best=value;
                }
            }
            result[x*out->c+c]=(int8_t)best;
        }
        {
            int rc=write_bytes(io,out->address+y*row,result,row);
            if(rc) return rc;
        }
    }
    return 0;
}
#endif

int yolo_execute_op(const yolo_io_t *io, const yolo_op_t *op,
                    const yolo_tensor_t *tensors)
{
    const yolo_tensor_t *out, *in;
    uint32_t y, x, c;
    if(!io || !io->read64 || !io->write64 || !op || !tensors ||
       op->count == 0 || op->count > 4) return YOLO_INVALID;
    out = &tensors[op->output];
    in = &tensors[op->inputs[0]];
    if(op->kind == YOLO_CONV) {
        uint32_t cycles;
        if (!io->convolve) return YOLO_INVALID;
        return io->convolve(io->context, &op->conv, &cycles);
    }
    if(op->kind == YOLO_HEAD) {
#ifdef YOLO_CACHED_RUNTIME
        if(yolo_runtime_options&YOLO_FAST_HEAD) return head_cached(io,op,tensors);
#endif
        return head_scalar(io,op,tensors);
    }
    if(out->c != out->padded_c || out->c == 0 || (out->c & 7) ||
       (out->address & 7) || out->h == 0 || out->w == 0)
        return YOLO_INVALID;
    if(op->kind == YOLO_POOL && (op->kernel != 5 || op->stride != 1 ||
       out->h != in->h || out->w != in->w || out->c != in->c))
        return YOLO_INVALID;
    if(op->kind == YOLO_UPSAMPLE && (out->h != 2*in->h ||
       out->w != 2*in->w || out->c != in->c)) return YOLO_INVALID;
    if(op->kind == YOLO_ADD && op->count != 2) return YOLO_INVALID;
    if(op->kind == YOLO_ADD || op->kind == YOLO_CONCAT) {
        uint32_t j, channels = 0;
        for(j=0; j<op->count; j++) {
            const yolo_tensor_t *src = &tensors[op->inputs[j]];
            if(src->h != out->h || src->w != out->w ||
               src->c != src->padded_c || (src->c & 7))
                return YOLO_INVALID;
            if(op->kind == YOLO_ADD && src->c != out->c) return YOLO_INVALID;
            channels += src->c;
        }
        if(op->kind == YOLO_CONCAT && channels != out->c) return YOLO_INVALID;
    }
    if(op->kind != YOLO_ADD && op->kind != YOLO_CONCAT &&
       op->kind != YOLO_UPSAMPLE && op->kind != YOLO_POOL)
        return YOLO_INVALID;
#ifdef YOLO_CACHED_RUNTIME
    if(op->kind==YOLO_CONCAT && (yolo_runtime_options&YOLO_FAST_LINEAR)) {
        uint32_t j,i;
        for(j=0;j<op->count;j++) for(i=0;i<256;i++)
            scratch.scale_lut[j][i]=(unsigned char)clip(
                rounded_q24((int64_t)(int8_t)i*op->ratios[j]));
    }
    if(op->kind==YOLO_POOL && (yolo_runtime_options&YOLO_FAST_POOL) &&
       (uint32_t)in->w*in->c<=sizeof scratch.pool[0])
        return pool_cached(io,in,out);
#endif
    if(op->kind==YOLO_CONCAT && out->c>256 &&
       (yolo_runtime_options&YOLO_FAST_LINEAR) && io->read_bulk && io->write_bulk)
        return concat_wide(io,op,tensors);
    if (io->read_bulk && io->write_bulk &&
        (op->kind == YOLO_ADD ||
         (op->kind == YOLO_CONCAT && out->c <= 256) ||
         (op->kind == YOLO_UPSAMPLE && out->c <= 128)))
        return execute_bulk_linear(io, op, tensors);
    for(y=0; y<out->h; y++) for(x=0; x<out->w; x++) for(c=0; c<out->c; c+=8) {
        int8_t result[8];
        uint64_t word = 0;
        uint32_t lane;
        if(op->kind == YOLO_POOL) {
            int ky,kx;
            for(lane=0;lane<8;lane++) result[lane]=-128;
            for(ky=-2;ky<=2;ky++) for(kx=-2;kx<=2;kx++) {
                int yy=(int)y+ky, xx=(int)x+kx;
                if(yy>=0 && yy<in->h && xx>=0 && xx<in->w) {
                    int8_t bytes[8];
                    int rc=io->read64(io->context,address(in,(uint32_t)yy,(uint32_t)xx,c),&word);
                    if(rc) return rc;
                    memcpy(bytes,&word,8);
                    for(lane=0;lane<8;lane++) if(bytes[lane]>result[lane]) result[lane]=bytes[lane];
                }
            }
        } else {
            uint32_t input_index=0, input_c=c;
            int8_t a[8], b[8]={0};
            const yolo_tensor_t *src=in;
            if(op->kind==YOLO_CONCAT) {
                while(input_index<op->count && input_c>=tensors[op->inputs[input_index]].c)
                    input_c-=tensors[op->inputs[input_index++]].c;
                if(input_index>=op->count) return YOLO_INVALID;
                src=&tensors[op->inputs[input_index]];
            }
            {
                uint32_t yy=op->kind==YOLO_UPSAMPLE?y/2:y;
                uint32_t xx=op->kind==YOLO_UPSAMPLE?x/2:x;
                int rc=io->read64(io->context,address(src,yy,xx,input_c),&word);
                if(rc) return rc;
                memcpy(a,&word,8);
            }
            if(op->kind==YOLO_ADD) {
                int rc=io->read64(io->context,address(&tensors[op->inputs[1]],y,x,c),&word);
                if(rc) return rc;
                memcpy(b,&word,8);
            }
            for(lane=0;lane<8;lane++) {
                int64_t v=(int64_t)a[lane]*op->ratios[input_index];
                if(op->kind==YOLO_ADD) v+=(int64_t)b[lane]*op->ratios[1];
                result[lane]=clip(rounded_q24(v));
            }
        }
        memcpy(&word,result,8);
        {
            int rc=io->write64(io->context,address(out,y,x,c),word);
            if(rc) return rc;
        }
    }
    return 0;
}

int yolo_execute_graph(const yolo_io_t *io, const yolo_op_t *ops, size_t count,
                       const yolo_tensor_t *tensors, size_t ntensors,
                       int *bad_op, uint64_t *conv_cycles)
{
    size_t i,j;
    if(!io || !ops || !tensors) return YOLO_INVALID;
    if(bad_op) *bad_op=-1;
    if(conv_cycles) *conv_cycles=0;
    for(i=0;i<count;i++) {
        int rc=YOLO_INVALID;
        uint32_t started=yolo_clock();
        if(ops[i].count>0 && ops[i].count<=4 && ops[i].output<ntensors) {
            for(j=0;j<ops[i].count;j++) if(ops[i].inputs[j]>=ntensors) break;
            if(j==ops[i].count) {
                if(ops[i].kind==YOLO_CONV && io->convolve) {
                    uint32_t cycles=0;
                    rc=io->convolve(io->context,&ops[i].conv,&cycles);
                    if(!rc && conv_cycles) *conv_cycles+=cycles;
                } else rc=yolo_execute_op(io,&ops[i],tensors);
            }
        }
        if(i<YOLO_PROFILE_OPS) yolo_op_cycles[i]=yolo_clock()-started;
        if(rc) { if(bad_op) *bad_op=(int)i; return rc; }
    }
    return 0;
}

int yolo_acc_read(void *context,uint32_t address,uint64_t *value)
{
    return acc_memory_read64(address,value,*(const uint32_t *)context);
}
int yolo_acc_write(void *context,uint32_t address,uint64_t value)
{
    return acc_memory_write64(address,value,*(const uint32_t *)context);
}
int yolo_acc_read_bulk(void *context,uint32_t address,void *dst,uint32_t bytes)
{
    return acc_memory_read_bulk(address,dst,bytes,*(const uint32_t *)context);
}
int yolo_acc_write_bulk(void *context,uint32_t address,const void *src,uint32_t bytes)
{
    return acc_memory_write_bulk(address,src,bytes,*(const uint32_t *)context);
}
int yolo_acc_convolve(void *context,const acc_layer_t *layer,uint32_t *cycles)
{
    int rc=acc_wait_idle(*(const uint32_t *)context);
    if(rc) return rc;
    acc_program(layer);
    rc=acc_run(*(const uint32_t *)context);
    if(!rc && cycles) *cycles=acc_rd(ACC_CYCLES);
    return rc;
}
