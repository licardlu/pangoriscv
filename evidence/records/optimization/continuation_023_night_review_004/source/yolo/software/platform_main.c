/* Static-image bring-up firmware. Camera ownership is a separate integration.
 * Requests: <"YAI1", cmd:u8, reserved:u8, length:u16, address:u32, crc:u32>
 * CRC32 covers the first 12 header bytes then payload. Stop-and-wait replies.
 */
#include "yolo_decode.h"
#include "yolo_contact_policy.h"
#include "yolo_camera_gate.h"
#include <math.h>
#include <stdint.h>

#define OSD_WIDTH 1280u
#define OSD_HEIGHT 720u
#ifndef POLL_LIMIT
#define POLL_LIMIT 100000000u
#endif
#define OSD_ACCEPTANCE_LIMIT 64u
#if defined(YOLO_SINGLE_LABEL) && YOLO_SINGLE_LABEL
#define OSD_ACCEPTANCE_TOKEN 1
#else
#define OSD_ACCEPTANCE_TOKEN 0
#endif

/* YOLO boxes use continuous, exclusive right/bottom edges. The frontend's
 * comparisons are inclusive integer pixel coordinates, so cover exactly the
 * source pixels intersected by the half-open box: floor(left/top), ceil(right/
 * bottom)-1, clipped to the native 1280x720 raster. */
int yolo_box_to_osd(const yolo_box_t *box,uint32_t *xy1,uint32_t *xy2)
{
    float x1,y1,x2,y2;
    uint32_t ix1,iy1,ix2,iy2;
    if(!box || !xy1 || !xy2 ||
       !isfinite(box->x1) || !isfinite(box->y1) ||
       !isfinite(box->x2) || !isfinite(box->y2) ||
       !(box->x2>box->x1 && box->y2>box->y1)) return 0;
    x1=box->x1<0.0f?0.0f:box->x1>(float)OSD_WIDTH?(float)OSD_WIDTH:box->x1;
    y1=box->y1<0.0f?0.0f:box->y1>(float)OSD_HEIGHT?(float)OSD_HEIGHT:box->y1;
    x2=box->x2<0.0f?0.0f:box->x2>(float)OSD_WIDTH?(float)OSD_WIDTH:box->x2;
    y2=box->y2<0.0f?0.0f:box->y2>(float)OSD_HEIGHT?(float)OSD_HEIGHT:box->y2;
    if(!(x2>x1 && y2>y1)) return 0;
    ix1=(uint32_t)x1;iy1=(uint32_t)y1;
    ix2=(uint32_t)x2;iy2=(uint32_t)y2;
    if((float)ix2<x2) ix2++;
    if((float)iy2<y2) iy2++;
    ix2--;iy2--;
    *xy1=(iy1<<16)|ix1;
    *xy2=(iy2<<16)|ix2;
    return 1;
}

/* Every successful inference must be committed, including an empty result.
 * The frontend holds the last box and starts its miss timeout only after an
 * explicit empty commit. Inference errors must not call display_results. */
int yolo_osd_should_commit(const yolo_box_t *results,uint32_t count)
{
    return count==0 || results!=0;
}

#if !defined(BBOX_OSD_TEST) || defined(BBOX_OSD_MMIO_TEST)
static yolo_box_t boxes[YOLO_MAX_RESULTS];
static yolo_camera_gate_t camera_gate;
#ifndef BBOX_OSD_TEST
static int stereo_accept_target(const yolo_box_t*);
#endif

static int display_results(uint32_t count)
{
    uint32_t left,i,state=0,token=0;
    for(left=0;left<POLL_LIMIT;left++) {
        state=acc_rd(0x98);
        if(!(state&1u))break;
    }
    if(left==POLL_LIMIT) return YOLO_TIMEOUT;
    /* Navigation/quiz ownership can change while inference was running.
     * The frontend rejects these commits; do not consume the camera gate. */
    if(state&0x0eu)return YOLO_CANCELLED;
    if(!yolo_osd_should_commit(boxes,count)) return 0;
    if(OSD_ACCEPTANCE_TOKEN) {
        uint32_t previous=(state>>4)&7u;
        token=previous==7u?1u:previous+1u;
    }
    for(i=0;i<8;i++) {
        acc_wr(0x84,i);
        uint32_t xy1,xy2;
        if(i<count && yolo_box_to_osd(&boxes[i],&xy1,&xy2)) {
            acc_wr(0x88,xy1);acc_wr(0x8c,xy2);
            acc_wr(0x90,0x80000000u|boxes[i].category|
                   (i==0?token<<28:0));
        } else acc_wr(0x90,i==0?token<<28:0);
    }
    if(acc_rd(0x98)&0x0eu)return YOLO_CANCELLED;
    /* An empty staging set signals a successful miss to the RTL hold timer. */
    acc_wr(0x94,1);acc_fence();
    if(OSD_ACCEPTANCE_TOKEN) {
        for(left=0;left<OSD_ACCEPTANCE_LIMIT;left++) {
            state=acc_rd(0x98);
            if(((state>>4)&7u)==token)return YOLO_OK;
            if(state&0x0eu)return YOLO_CANCELLED;
        }
        return YOLO_TIMEOUT;
    }
    return 0;
}

/* Probe and game use identical target selection. A diagnostic request must
 * never create/replace/clear a quiz, even when it selects an object. */
static int camera_results(uint32_t *count,uint32_t waste_classes,uint32_t hand_class,
                          float width,float height,int commit)
{
    yolo_target_t target=yolo_select_contact_target(boxes,*count,waste_classes,
                                                   hand_class,width,height);
    yolo_camera_gate_t next_gate;
    int depth_unknown=0;
#ifndef BBOX_OSD_TEST
    if(commit && target.object_index>=0 && !stereo_accept_target(boxes+target.object_index)) {
        target.object_index=-1;depth_unknown=1;
    }
#endif
    if(commit) {
        next_gate=camera_gate;
        if(depth_unknown)yolo_camera_gate_interrupt(&next_gate);
        else if(!yolo_camera_gate_observe(&next_gate,
            target.object_index>=0 ? boxes+target.object_index : 0))target.object_index=-1;
    }
    if(target.object_index>=0) {boxes[0]=boxes[target.object_index];*count=1;}
    else *count=0;
    if(commit) {
        int status=display_results(*count);
        if(!status)camera_gate=next_gate;
        return status;
    }
    return YOLO_OK;
}

#endif

#ifndef BBOX_OSD_TEST
#include "yolo_runtime.h"
#include "deployment_model.h"
#include "yolo_frame_workspace.h"
#include "benchmark.h"
#include "stereo_calibration.h"
static uint8_t stereo_enabled;
static stereo_gate_t stereo_gate;
static stereo_measurement_t stereo_last;
static uint32_t stereo_poll_tick;
static int stereo_monitor(void);
#ifdef MEDIA_ENABLE
#include "media_board.h"
#include "media_player.h"
#include "model_boot.h"
static uint8_t inference_cancellable;
int yolo_graph_cancelled(void) {
    return inference_cancellable && media_navigation_active();
}
#endif
#include <string.h>

#ifndef CPU_HZ
#define CPU_HZ 27000000u
#endif
#ifdef VEXII_PLATFORM
#define UART ((volatile uint32_t *)(uintptr_t)0x10001000u)
#else
#define UART ((volatile uint32_t *)(uintptr_t)0x30000000u)
#endif
extern int yolo_forward(uint32_t,uint64_t *,int *);
/* The graph has finished before decode starts; reuse its 8 KiB scratch.
 * Legacy scalar platforms retain their independent acquisition/decode union. */
#if defined(VEXII_PLATFORM) || !defined(__riscv)
#define frame_workspace (*yolo_frame_workspace_get())
#else
static yolo_frame_workspace_t frame_workspace;
#endif
static uint8_t model_verified;
static uint8_t autonomous,rx_idle=1;
#ifdef MEDIA_ENABLE
static model_boot_state_t boot_state;
static uint32_t boot_cycles;
static int boot_write(void*context,uint32_t offset,const uint8_t*data,uint32_t n){
    (void)context;
    return acc_memory_write_bulk(YOLO_BLOB_BASE+offset,data,n,POLL_LIMIT);
}
static int boot_load(void*context){
    (void)context;
    return media_player_load_model(YOLO_BLOB_LENGTH,YOLO_BLOB_CRC32,boot_write,0);
}
static int boot_verify(void*context){
    (void)context;uint32_t crc=~0u;
    int rc=acc_memory_crc_bulk(YOLO_BLOB_BASE,YOLO_BLOB_LENGTH,POLL_LIMIT,&crc);
    return rc?rc:~crc==YOLO_BLOB_CRC32?0:YOLO_INVALID;
}
static void boot_model(void){
    uint32_t started=yolo_clock();model_verified=0;autonomous=0;
    model_boot_start(&boot_state,boot_load,boot_verify,0);
    model_verified=boot_state.verified;autonomous=boot_state.autonomous;
    boot_cycles=yolo_clock()-started;
}
#endif
static uint32_t input_loaded;
static uint32_t camera_fast=1;
/* cmd8 returns CPU cycles for the last request, followed by one word per op.
 * cmd9 selects baseline (0) or individual optimizations (bits 0..5). */
static uint32_t profile[8+YOLO_N_OPS];
static yolo_decode_config_t decode_cfg={
    .anchors={{{10,13},{16,30},{33,23}},{{30,61},{62,45},{59,119}},
              {{116,90},{156,198},{373,326}}},
    .strides={8,16,32},.confidence=.25f,.iou=.45f,.ratio=1,
    .original_w=320,.original_h=320
};

static uint32_t crc_update(uint32_t crc,const unsigned char *p,uint32_t n)
{
    uint32_t j;
    while(n--) {
        crc^=*p++;
        for(j=0;j<8;j++) crc=(crc>>1)^(0xedb88320u & (0u-(crc&1u)));
    }
    return crc;
}
static unsigned char receive(void)
{
#ifdef VEXII_PLATFORM
    /* The data register read is also the FIFO pop, so it must never happen
     * while the receive queue is empty: that would return the uninitialised
     * FIFO RAM (X in simulation, garbage on silicon, and it poisons the PC)
     * and would silently discard one byte.  Poll the occupancy field of the
     * status register (bits 29:24) first, then pop exactly one byte. */
    while(!(UART[1] & 0x3f000000u)) {if(rx_idle){
        benchmark_poll();
#ifdef MEDIA_ENABLE
        media_player_poll();
#endif
    }}
    rx_idle=0;
    return (unsigned char)UART[0];
#else
    unsigned char c;
    while(!(UART[1]&2u)) {}
    c=(unsigned char)UART[4];
    UART[1]=0;
    return c;
#endif
}
static void send(unsigned char c)
{
#ifdef VEXII_PLATFORM
    while(!(UART[1]&0x003f0000u)) {}
    UART[0]=c;
#else
    while(UART[1]&1u) {}
    UART[3]=c;
#endif
}
static void reply(uint8_t status,const void *payload,uint16_t n)
{
    unsigned char header[8]={'Y','A','R','1',status,(unsigned char)n,(unsigned char)(n>>8),0};
    const unsigned char *p=payload;
    uint32_t i,crc=crc_update(~0u,header,8);
    crc=~crc_update(crc,p,n);
    for(i=0;i<8;i++) send(header[i]);
    for(i=0;i<n;i++) send(p[i]);
    for(i=0;i<4;i++) send((unsigned char)(crc>>(i*8)));
}

static int prepare_snapshot_input(void)
{
    uint32_t y,x;
    acc_wr(0x78,0);
    acc_fence();
    for(y=0;y<320;y++) {
#ifdef MEDIA_ENABLE
        if(yolo_graph_cancelled())return YOLO_CANCELLED;
#endif
        for(x=0;x<320;x++) {
        uint64_t word=57u | (57ull<<8) | (57ull<<16); // letterbox RGB 114
        if(y>=70 && y<250) {
            uint32_t pixel,r,g,b;
            if(camera_fast) {
                word=acc_rd(0xbc);
            } else {
            acc_wr(0x78,(y-70)*320+x);
            acc_fence();
            pixel=acc_rd(0x7c);
            r=(pixel>>11)&31;g=(pixel>>5)&63;b=pixel&31;
            r=(r<<3)|(r>>2);g=(g<<2)|(g>>4);b=(b<<3)|(b>>2);
            r=(r*127+127)/255;g=(g*127+127)/255;b=(b*127+127)/255;
            word=r | ((uint64_t)g<<8) | ((uint64_t)b<<16);
            }
        }
        memcpy(frame_workspace.input_row+x*8u,&word,8);
        }
        {
            int rc=acc_memory_write_bulk(yolo_tensors[0].address+y*320u*8u,
                                          frame_workspace.input_row,
                                          sizeof frame_workspace.input_row,
                                          POLL_LIMIT);
            if(rc) return rc;
        }
    }
    decode_cfg.ratio=.25f;decode_cfg.pad_x=0;decode_cfg.pad_y=70;
    decode_cfg.original_w=1280;decode_cfg.original_h=720;
    return 0;
}

static int capture_input(void)
{
    uint32_t left;
    if(acc_rd(0x80)&1u)return YOLO_IO;
    acc_wr(0x74,1);
    acc_fence();
    for(left=0;left<POLL_LIMIT;left++) {
        uint32_t s=acc_rd(0x80);
        if(s&4) return YOLO_IO;
        // A paired grayscale snapshot is never a valid RGB inference input.
        if((s&11)==2) return prepare_snapshot_input();
    }
    return YOLO_TIMEOUT;
}

/* Stereo diagnostics never create a quiz. The snapshot is immutable until a
 * later capture. Frame-start ticks share CPU_HZ but are NOT exposure times. */
static uint32_t stereo_metadata(uint16_t address);
static int stereo_poll_cancel(void){
    benchmark_poll();
#ifdef MEDIA_ENABLE
    media_player_poll();
    if(media_board_page()==1)return 1;
#endif
    return (stereo_metadata(0xff04)&4u)!=0;
}
#ifndef STEREO_POLL_INTERVAL
#define STEREO_POLL_INTERVAL 256u
#endif
static int capture_stereo_pair(uint32_t metadata[9],int diagnostic,int retain_game_capture)
{
    uint32_t initial=acc_rd(0x80);
    if(!(initial&16u))return YOLO_INVALID;
    if(initial&5u)return YOLO_IO;
    if(acc_rd(0x98)&0x0au)return YOLO_INVALID;
    if(diagnostic)autonomous=0;
    acc_wr(0x74,retain_game_capture?7:3);acc_fence();
    uint32_t state=0;int cancelled=0;
    for(uint32_t left=0;left<POLL_LIMIT;left++){
        if(left%STEREO_POLL_INTERVAL==0){
            int stop=stereo_poll_cancel();
            if(!diagnostic && stop)cancelled=1;
        }
        state=acc_rd(0x80);
        if(state&4u)return YOLO_IO;
        if((state&11u)==10u){
            // Drain the in-flight capture before returning cancellation, so
            // a following RGB request cannot reuse a pending grayscale frame.
            if(cancelled)return YOLO_CANCELLED;
            metadata[0]=0x53545031u;metadata[1]=320;metadata[2]=180;
            metadata[3]=state;metadata[4]=CPU_HZ;
            for(uint32_t i=0;i<4;i++){
                acc_wr(0x78,0xff00u+i);acc_fence();
                metadata[5+i]=acc_rd(0x7c);
            }
            return metadata[8]==0x53545031u?0:YOLO_INVALID;
        }
    }
    return YOLO_TIMEOUT;
}

static uint32_t stereo_metadata(uint16_t address){
    acc_wr(0x78,address);acc_fence();return acc_rd(0x7c);
}
static void stereo_page(unsigned page){acc_wr(0x74,0x80u|(page<<4));acc_fence();}
static uint32_t stereo_milliseconds(void){
#ifdef __riscv
    uint32_t hi,lo,again;
    do{
        __asm__ volatile("csrr %0,mcycleh":"=r"(hi));
        __asm__ volatile("csrr %0,mcycle":"=r"(lo));
        __asm__ volatile("csrr %0,mcycleh":"=r"(again));
    }while(hi!=again);
    return (uint32_t)((((uint64_t)hi<<32)|lo)/(CPU_HZ/1000u));
#else
    return yolo_clock()/(CPU_HZ/1000u);
#endif
}
static unsigned frame_skew_ms(const uint32_t metadata[9]){
    uint32_t difference=metadata[6]-metadata[7];
    if(difference>0x80000000u)difference=0u-difference;
    return (unsigned)(((uint64_t)difference*1000u+CPU_HZ-1u)/CPU_HZ);
}
static uint16_t stereo_raw_word(int x,int y){
    acc_wr(0x78,(uint32_t)y*320u+(uint32_t)x);acc_fence();
    return (uint16_t)acc_rd(0x7c);
}
typedef struct {unsigned reads;uint8_t cancelled;} stereo_reader_t;
static int stereo_read_pixel(void*ctx,unsigned side,int x,int y,uint8_t*out){
    stereo_reader_t*reader=ctx;
    if(reader->cancelled)return -1;
    if(x<0||y<0||x>=320||y>=180)return -1;
    if((++reader->reads&255u)==0){
        if(stereo_poll_cancel()){reader->cancelled=1;return -1;}
    }
    uint16_t pixel=stereo_raw_word(x,y);
    *out=side?(uint8_t)(pixel>>8):(uint8_t)pixel;return 0;
}
static uint8_t stereo_gray565(uint16_t p){
    unsigned r=((p>>11)&31u)*8u+((p>>13)&7u);
    unsigned g=((p>>5)&63u)*4u+((p>>9)&3u);
    unsigned b=(p&31u)*8u+((p>>2)&7u);
    return (uint8_t)((r+g*2u+b)/4u);
}
static int stereo_accept_target(const yolo_box_t*box){
    if(!stereo_enabled)return 1; // Explicit manual mode preserves original behavior.
    if(!box || (stereo_calibration.verified&7u)!=7u || (acc_rd(0x80)&8u))return 0;
    int x=(int)(box->x1*.25f),y=(int)(box->y1*.25f);
    int w=(int)((box->x2-box->x1)*.25f),h=(int)((box->y2-box->y1)*.25f),roi[4];
    if(stereo_rectified_roi(&stereo_calibration,x,y,w,h,roi))return 0;
    // Color inference and the pair use the same physical sensor but different
    // frames. Reject changed scene patches; never silently reuse an old depth.
    uint8_t fingerprint[25];
    for(int j=0;j<5;j++)for(int i=0;i<5;i++)
        fingerprint[j*5+i]=stereo_gray565(stereo_raw_word(x+w*(i+1)/6,y+h*(j+1)/6));
    uint32_t metadata[9];
    if(capture_stereo_pair(metadata,0,1))return 0;
    unsigned difference=0;
    for(int j=0;j<5;j++)for(int i=0;i<5;i++){
        int d=(int)(uint8_t)stereo_raw_word(x+w*(i+1)/6,y+h*(j+1)/6)-fingerprint[j*5+i];
        unsigned magnitude=(unsigned)(d<0?-d:d);
        if(magnitude>48)return 0;
        difference+=magnitude;
    }
    if(difference>25u*12u)return 0;
    stereo_reader_t reader={0};
    stereo_last=stereo_measure(&stereo_calibration,stereo_read_pixel,&reader,
        roi[0],roi[1],roi[2],roi[3],frame_skew_ms(metadata),&frame_workspace.stereo);
    return !reader.cancelled && stereo_last.status==STEREO_NEAR && !(stereo_metadata(0xff04)&4u);
}
static int stereo_monitor(void){
    if(!stereo_enabled)return 1;
    if((stereo_metadata(0xff04)&4u) || (stereo_calibration.verified&7u)!=7u){
        stereo_enabled=0;stereo_page(0);stereo_gate_update(&stereo_gate,0,0,1);return 1;
    }
#ifdef MEDIA_ENABLE
    if(media_board_page()==1)return 0;
#endif
    if(acc_rd(0x98)&0x0au)return 0;
    uint32_t now=yolo_clock();
    if((uint32_t)(now-stereo_poll_tick)<CPU_HZ/10u)return 0;
    stereo_poll_tick=now;
    uint32_t metadata[9];
    int capture_status=capture_stereo_pair(metadata,0,0);
    if(capture_status==YOLO_CANCELLED){
        stereo_enabled=0;stereo_page(0);stereo_gate_update(&stereo_gate,0,0,1);return 0;
    }
    if(capture_status){
        stereo_last=(stereo_measurement_t){0};
    }else{
        stereo_reader_t reader={0};
        stereo_last=stereo_measure(&stereo_calibration,stereo_read_pixel,&reader,
            96,30,128,120,frame_skew_ms(metadata),&frame_workspace.stereo);
        if(reader.cancelled || (stereo_metadata(0xff04)&4u)){
            stereo_enabled=0;stereo_page(0);stereo_gate_update(&stereo_gate,0,0,1);return 0;
        }
    }
    int active=stereo_gate_update(&stereo_gate,stereo_last.status,
        stereo_milliseconds(),0);
    stereo_page(active?1:2);
    return active && stereo_last.status==STEREO_NEAR;
}

static int read_stereo_chunk(uint32_t offset,uint8_t data[256])
{
    uint32_t state=acc_rd(0x80);
    if((state&15u)!=10u || offset>57600u-128u || (offset&127u))return YOLO_INVALID;
    acc_wr(0x78,offset);acc_fence();
    for(uint32_t i=0;i<128;i++){
        uint32_t pixel=acc_rd(0xbc);
        data[i*2]=(uint8_t)pixel;data[i*2+1]=(uint8_t)(pixel>>8);
    }
    return YOLO_OK;
}

/* Reprocess the same immutable camera snapshot twice. This verifies the full
 * packed input, including letterbox/padding channels, independently of YOLO.
 * Timings exclude CRC and acquisition; normal inference still uses cmd6. */
static int compare_camera_inputs(uint32_t result[4])
{
    uint32_t saved_mode=camera_fast,mode,started;
    int status=capture_input();
    if(status) return status;
    for(mode=0;mode<2;mode++) {
        uint32_t crc=~0u;
        camera_fast=mode;
        started=yolo_clock();
        status=prepare_snapshot_input();
        result[2+mode]=yolo_clock()-started;
        if(!status) status=acc_memory_crc_bulk(yolo_tensors[0].address,
                                             320u*320u*8u,POLL_LIMIT,&crc);
        if(status) break;
        result[mode]=~crc;
    }
    camera_fast=saved_mode;
    if(!status && result[0]!=result[1]) status=YOLO_INVALID;
    if(!status) input_loaded=320u*320u*8u;
    return status;
}


static int infer_reply(const yolo_io_t *io,uint32_t limit,int camera)
{
    uint64_t cycles=0;
    int bad=-1,status=0;
    yolo_tensor_t heads[3];
    uint32_t i,count=0,started;
    if(!model_verified || (!camera && input_loaded!=320u*320u*8u)) {
        reply(YOLO_INVALID,0,0);return YOLO_INVALID;
    }
    memset(profile,0,sizeof profile);
    profile[0]=1;profile[1]=CPU_HZ;profile[2]=yolo_runtime_options;profile[3]=YOLO_N_OPS;
    started=yolo_clock();
#ifdef MEDIA_ENABLE
    inference_cancellable=autonomous && camera==1;
#endif
    if(camera) status=capture_input();
    profile[4]=yolo_clock()-started;
    started=yolo_clock();
    /* An anchor's final confidence cannot exceed its objectness. Keep a
     * margin for Q16 rounding; the decoder still applies its own threshold. */
    yolo_head_logit_floor=decode_cfg.confidence<1 ?
        logf(decode_cfg.confidence/(1-decode_cfg.confidence))-.001f : 16.0f;
    if(yolo_head_logit_floor>16) yolo_head_logit_floor=16;
    if(!status) status=yolo_forward(limit,&cycles,&bad);
    profile[5]=yolo_clock()-started;
    for(i=0;i<YOLO_N_OPS;i++) profile[8+i]=yolo_op_cycles[i];
    for(i=0;i<3;i++) heads[i]=yolo_tensors[yolo_outputs[i]];
    started=yolo_clock();
    if(!status) status=yolo_decode(io,heads,&decode_cfg,&frame_workspace.decode,boxes,&count);
    profile[6]=yolo_clock()-started;
    started=yolo_clock();
    /* Only successful inference results may start the frontend miss timer. */
    if(!status && camera) {
        /* Raw static-image requests retain all detections for numerical checks.
         * Camera game commits exactly one target, with matching UART/OSD/bin. */
        status=camera_results(&count,
            YOLO_CLASSES==5 ? 4u : YOLO_CLASSES,
            YOLO_CLASSES==5 ? 4u : UINT32_MAX,
            decode_cfg.original_w,decode_cfg.original_h,camera==1);
    }
    profile[7]=yolo_clock()-started;
#ifdef MEDIA_ENABLE
    inference_cancellable=0;
    if(status==YOLO_CANCELLED){yolo_camera_gate_interrupt(&camera_gate);return status;}
#endif
    if(status) {
        if(camera==1)yolo_camera_gate_interrupt(&camera_gate);
        uint32_t error[2]={(uint32_t)status,(uint32_t)bad};
        reply((uint8_t)status,error,sizeof error);
    } else {
        unsigned char result[4+sizeof boxes];
        memcpy(result,&count,4);memcpy(result+4,boxes,count*sizeof(*boxes));
        reply(0,result,(uint16_t)(4+count*sizeof(*boxes)));
    }
    return status;
}
#ifndef STEREO_PLATFORM_TEST
int main(void)
{
    unsigned char header[16],payload[256];
    uint32_t limit=POLL_LIMIT;
    yolo_io_t io={
        .context=&limit,.read64=yolo_acc_read,.write64=yolo_acc_write,
        .convolve=yolo_acc_convolve,.read_bulk=yolo_acc_read_bulk,
        .write_bulk=yolo_acc_write_bulk
    };
#ifdef VEXII_PLATFORM
    UART[2]=CPU_HZ/(115200u*8u)-1u;
    UART[3]=7;
#else
    UART[2]=(CPU_HZ+57600u)/115200u-1u;
    UART[0]=3;
#endif
#ifdef VEXII_SIM_PRELOAD
    model_verified=1;
    input_loaded=320u*320u*8u;
#endif
    benchmark_init();
    stereo_enabled=(stereo_calibration.verified&7u)==7u;
#ifdef MEDIA_ENABLE
    media_board_init();
#ifndef VEXII_SIM_PRELOAD
    boot_model();
#endif
#endif
    for(;;) {
        if(benchmark_page_active() || (acc_rd(0x98)&0x0eu)
#ifdef MEDIA_ENABLE
           || media_navigation_active()
#endif
        )yolo_camera_gate_interrupt(&camera_gate);
        benchmark_poll();benchmark_run_pending();rx_idle=1;
#ifdef MEDIA_ENABLE
        media_player_poll();
#endif
        if(autonomous && !(UART[1]&0x3f000000u)) {
            int depth_ready=stereo_monitor();
            if(depth_ready && !benchmark_page_active()
#ifdef MEDIA_ENABLE
               && !media_navigation_active()
#endif
               && !(acc_rd(0x98)&0x0eu)) {
                int result=infer_reply(&io,limit,1);
                if(result && result!=YOLO_CANCELLED)autonomous=0;
            }
            continue;
        }
        /* Keep keyboard benchmarks at this top-level safe point even when
         * autonomous recognition is disabled; never enter receive() on idle. */
        if(!(UART[1]&0x3f000000u))continue;
        uint32_t i,address,expected,crc;
        uint16_t n;
        uint8_t cmd,status=0;
        /* Sliding magic synchronization also recovers after an oversized frame. */
        uint32_t magic=0;
        do {magic=(magic<<8)|receive();} while(magic!=0x59414931u);
        memcpy(header,"YAI1",4);
        for(i=4;i<16;i++) header[i]=receive();
        cmd=header[4];n=(uint16_t)(header[6]|header[7]<<8);
        memcpy(&address,header+8,4);memcpy(&expected,header+12,4);
        if(n>sizeof payload) {reply(YOLO_INVALID,0,0);continue;}
        for(i=0;i<n;i++) payload[i]=receive();
        crc=~crc_update(crc_update(~0u,header,12),payload,n);
        if(crc!=expected) {reply(YOLO_INVALID,0,0);continue;}
        if(cmd==1 || cmd==2) {
            uint16_t length=cmd==2?8:n;
            if((address&7) || (length&7) || !length ||
               address<YOLO_BLOB_BASE || address>0x03000000u-length) {
                reply(YOLO_INVALID,0,0);continue;
            }
            if(cmd==2) {
                uint64_t word=0;
                if(n) {reply(YOLO_INVALID,0,0);continue;}
                status=(uint8_t)acc_memory_read64(address,&word,limit);
                reply(status,&word,8);continue;
            }
            if(address<YOLO_BLOB_BASE+YOLO_BLOB_LENGTH) model_verified=0;
            status=(uint8_t)acc_memory_write_bulk(address,payload,n,limit);
            if(address>=yolo_tensors[0].address &&
               address<yolo_tensors[0].address+320u*320u*8u) {
                if(!status && address==yolo_tensors[0].address+input_loaded)
                    input_loaded+=n;
                else if(!status && address==yolo_tensors[0].address) input_loaded=n;
                else input_loaded=0;
                if(input_loaded>320u*320u*8u) input_loaded=0;
            }
        } else if((cmd==3 || cmd==6 || cmd==12) && n==0) {
            infer_reply(&io,limit,cmd==12 ? 2 : cmd==6);
            continue;
        } else if(cmd==21 && n==0 && address==0) {
            uint32_t metadata[9]={0};
            status=(uint8_t)capture_stereo_pair(metadata,1,0);
            reply(status,status?0:metadata,status?0:sizeof metadata);continue;
        } else if(cmd==22 && n==0) {
            status=(uint8_t)read_stereo_chunk(address,payload);
            reply(status,status?0:payload,status?0:256);continue;
        } else if(cmd==23 && n==0 && address<=2u) {
            if(address==1u && (stereo_calibration.verified&7u)!=7u){
                reply(YOLO_INVALID,0,0);continue;
            }
            if(address){
                stereo_enabled=address==1u;stereo_page(0);
                stereo_gate_update(&stereo_gate,0,0,1);
            }
            uint32_t info[8]={0x53444731u,stereo_enabled,stereo_calibration.verified,
                stereo_last.status,stereo_last.valid_points,stereo_last.median_mm,
                stereo_last.uncertainty_mm,stereo_metadata(0xff04)};
            reply(0,info,sizeof info);continue;
        } else if(cmd==7 && n==0 && model_verified) {
            reply(0,0,0);
            /* Poll between frames so page requests and maintenance UART work
             * in autonomous mode. Hardware completes existing lid movements. */
            autonomous=1;
            continue;
        } else if(cmd==13 && n==0 && address<=2u) {
            uint32_t result[1+(sizeof(benchmark_last)+3)/4]={0};
            if(address==1)benchmark_toggle();
            if(address==2)benchmark_request();
            result[0]=acc_rd(0xd0);
            memcpy(result+1,&benchmark_last,sizeof benchmark_last);
            reply(0,result,sizeof result);continue;
        } else if(cmd==15 && n==0 && address==0) {
            uint32_t diagnostic[4]={acc_rd(0xd0),acc_rd(0x98),acc_rd(0xcc),0};
#ifdef BENCHMARK_DEMO_MODE
            diagnostic[3]=0x44454d4fu; /* DEMO: simulated UI, not measured CoreMark */
#elif defined(BENCHMARK_REFERENCE_MODE)
            diagnostic[3]=0x52454631u; /* REF1: stored reference mode */
#endif
            reply(0,diagnostic,sizeof diagnostic);continue;
#ifdef MEDIA_ENABLE
        } else if(cmd==20 && n==0 && address<=1) {
            /* Address 0 is read-only. Address 1 retries boot after inserting
             * a card, only while outside playback and with no quiz active. */
            if(address){
                if(media_board_page()!=0 || (acc_rd(0x98)&0x0eu)){
                    reply(YOLO_INVALID,0,0);continue;
                }
                boot_model();
            }
            uint32_t diagnostic[8]={0x424f5431u,model_verified,autonomous,
                (uint32_t)boot_state.error,boot_cycles,YOLO_BLOB_LENGTH,
                YOLO_BLOB_CRC32,media_board_page()};
            reply(0,diagnostic,sizeof diagnostic);continue;
        } else if(cmd==16 && n==0 && address<=2) {
            uint32_t diagnostic[25]={0x4d454431u+address,acc_rd(0x9c),0};
            memcpy(diagnostic+2,media_player_statistics(),sizeof(media_player_stats_t));
            diagnostic[8]=CPU_HZ;
            if(address && media_board_diagnostics(diagnostic+9))reply(YOLO_INVALID,0,0);
            else if(address==2 && media_player_audio_statistics(diagnostic+16))reply(YOLO_INVALID,0,0);
            else reply(0,diagnostic,(address==2?25u:address?16u:9u)*sizeof(uint32_t));
            continue;
        } else if(cmd==18 && n==0) {
            int rc=media_board_read_frame(address,payload,limit);
            reply(rc?YOLO_INVALID:0,rc?0:payload,rc?0:256);continue;
        } else if(cmd==19 && n==0 && address<=2) {
            if(address)media_player_pause(address==1);
            uint32_t held=media_player_paused();
            reply(0,&held,sizeof held);continue;
#endif
        } else if(cmd==14 && n==0 && address>0 && address<=40000u) {
            benchmark_set_luts(address);
            reply(0,&address,sizeof address);continue;
        } else if(cmd==8 && n==0) {
            reply(0,profile,sizeof profile);continue;
        } else if(cmd==9 && n==0 && address<=63u) {
            yolo_runtime_options=address;
            reply(0,&yolo_runtime_options,sizeof yolo_runtime_options);continue;
        } else if(cmd==10 && n==0 && address<=1u) {
            camera_fast=address;
            reply(0,&camera_fast,sizeof camera_fast);continue;
        } else if(cmd==11 && n==0) {
            uint32_t result[4]={0};
            status=(uint8_t)compare_camera_inputs(result);
            reply(status,result,sizeof result);continue;
        } else if(cmd==4 && n==16) {
            float values[3];
            uint16_t dimensions[2];
            memcpy(values,payload,12);memcpy(dimensions,payload+12,4);
            if(!(values[0]>0) || !dimensions[0] || !dimensions[1]) status=YOLO_INVALID;
            else {
                decode_cfg.ratio=values[0];decode_cfg.pad_x=values[1];decode_cfg.pad_y=values[2];
                decode_cfg.original_w=dimensions[0];decode_cfg.original_h=dimensions[1];
            }
        } else if(cmd==5 && n==0) {
            uint32_t crc_model=~0u;
            status=(uint8_t)acc_memory_crc_bulk(YOLO_BLOB_BASE,
                                                YOLO_BLOB_LENGTH,
                                                limit,&crc_model);
            model_verified=(uint8_t)(!status && ~crc_model==YOLO_BLOB_CRC32);
            if(!model_verified) status=YOLO_INVALID;
        } else status=YOLO_INVALID;
        reply(status,0,0);
    }
}
#endif /* STEREO_PLATFORM_TEST */
#endif
