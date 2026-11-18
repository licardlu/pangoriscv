/* Compile actual platform callbacks with host MMIO. No UART or device access. */
#include "yolo_runtime.h"
#include "yolo_frame_workspace.h"
#include "media_player.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static stereo_calibration_t stereo_calibration;
#define STEREO_CALIBRATION_H
#define STEREO_PLATFORM_TEST
#define MEDIA_ENABLE
#define POLL_LIMIT 8u
#define STEREO_POLL_INTERVAL 2u
static uint32_t mock_rd(uint32_t);
static void mock_wr(uint32_t,uint32_t);
static uint32_t mock_clock(void);
#define acc_rd mock_rd
#define acc_wr mock_wr
#define acc_fence() ((void)0)
#define yolo_clock mock_clock
#include "platform_main.c"
#undef yolo_clock
#undef acc_rd
#undef acc_wr
#undef acc_fence

static uint32_t ticks,state=0x12,pointer,lock_flags,manual,page_request,last_capture;
static unsigned error_mode,polls,cancel_poll,mmio_reads,scene_change;
static unsigned capture_latency,capture_remaining,captures;
static uint8_t image[2][180][320];
static yolo_frame_workspace_t shared;
yolo_frame_workspace_t*yolo_frame_workspace_get(void){return &shared;}
static uint32_t mock_clock(void){return ticks;}
uint32_t media_board_page(void){return 0;}
int media_navigation_active(void){return 0;}
void benchmark_poll(void){polls++;if(cancel_poll && polls>=cancel_poll)manual=4;}
void media_player_poll(void){}
static uint32_t mock_rd(uint32_t off){
    mmio_reads++;
    if(off==0x80){
        if(capture_remaining && --capture_remaining==0)state=26;
        return state;
    }
    if(off==0x98)return lock_flags;
    if(off==0x7c){
        if(pointer==0xff04)return manual|page_request;
        if(pointer==0xff00)return 0x12340042;
        if(pointer==0xff01)return 5400000;
        if(pointer==0xff02)return 5400000+54000;
        if(pointer==0xff03)return 0x53545031;
        assert(pointer<57600);
        unsigned y=pointer/320,x=pointer%320;
        unsigned l=image[0][y][x],r=image[1][y][x];
        if(state&8)return (uint8_t)(l+scene_change)|(r<<8);
        return ((l>>3)<<11)|((l>>2)<<5)|(l>>3);
    }
    if(off==0xbc){uint32_t pixel=mock_rd(0x7c);pointer++;return pixel;}
    assert(0);return 0;
}
static void mock_wr(uint32_t off,uint32_t value){
    if(off==0x78){pointer=value;return;}
    assert(off==0x74);
    if(value&128){page_request=(value>>4)&3;return;}
    last_capture=value;
    captures++;capture_remaining=capture_latency;
    state=error_mode==1?20:error_mode==2?25:26;
    if(!error_mode && capture_remaining)state=25;
}
static void reset(int disparity){
    stereo_calibration_t*c=&stereo_calibration;
    memset(c,0,sizeof(*c));
    c->width=320;c->height=180;c->max_disparity=96;c->max_skew_ms=5;
    c->limit_mm=200;c->error_mm=5;c->verified=7;c->focal_baseline_q8=6000*256;
    for(unsigned side=0;side<2;side++){
        stereo_camera_t*k=c->camera+side;
        k->fx=k->fy=200;k->cx=160;k->cy=90;
        float inverse[9]={.005f,0,-.8f,0,.005f,-.45f,0,0,1};
        float forward[9]={200,0,160,0,200,90,0,0,1};
        memcpy(k->inverse_rectified,inverse,sizeof inverse);
        memcpy(k->forward_rectified,forward,sizeof forward);
    }
    uint32_t random=14587;
    for(unsigned y=0;y<180;y++)for(unsigned x=0;x<320;x++){
        random^=random<<13;random^=random>>17;random^=random<<5;
        image[0][y][x]=(uint8_t)random;
    }
    memset(image[1],0,sizeof image[1]);
    for(int y=0;y<180;y++)for(int x=0;x<320-disparity;x++)
        image[1][y][x]=image[0][y][x+disparity];
    ticks=54000000;state=0x12;pointer=lock_flags=manual=page_request=0;
    error_mode=polls=cancel_poll=scene_change=0;autonomous=1;stereo_enabled=1;
    capture_latency=capture_remaining=captures=0;
    stereo_poll_tick=0;memset(&stereo_gate,0,sizeof stereo_gate);
}
int main(void){
    uint32_t metadata[9];uint8_t chunk[256];
    reset(40);
    assert(!capture_stereo_pair(metadata,1,0)&&!autonomous&&last_capture==3);
    assert(metadata[0]==0x53545031&&metadata[5]==0x12340042&&frame_skew_ms(metadata)==1);
    metadata[6]=0xfffffff0;metadata[7]=0x20;assert(frame_skew_ms(metadata)==1);
    assert(!read_stereo_chunk(0,chunk));
    for(unsigned i=0;i<128;i++)assert(chunk[2*i]==image[0][0][i]&&chunk[2*i+1]==image[1][0][i]);
    assert(read_stereo_chunk(1,chunk)==YOLO_INVALID);
    assert(read_stereo_chunk(57600,chunk)==YOLO_INVALID);
    lock_flags=2;assert(capture_stereo_pair(metadata,0,0)==YOLO_INVALID);lock_flags=0;
    error_mode=1;assert(capture_stereo_pair(metadata,0,0)==YOLO_IO);
    state=18;
    error_mode=2;assert(capture_stereo_pair(metadata,0,0)==YOLO_TIMEOUT);
    unsigned starts=captures;
    assert(capture_stereo_pair(metadata,0,0)==YOLO_IO&&captures==starts);
    assert(capture_input()==YOLO_IO&&captures==starts);
    reset(40);capture_latency=6;cancel_poll=1;
    assert(capture_stereo_pair(metadata,0,0)==YOLO_CANCELLED);
    assert(polls>=3 && !(state&1u) && !capture_remaining);
    reset(40);capture_latency=6;cancel_poll=1;
    assert(!capture_stereo_pair(metadata,1,0)); // Diagnostics still drain/service UI.
    assert(polls>=3 && !(state&1u));
    reset(40);assert(!stereo_monitor()&&page_request==2);
    ticks+=54000000;assert(stereo_monitor()&&page_request==1&&stereo_last.status==STEREO_NEAR);
    yolo_box_t box={400,120,880,600,.9f,0};
    state=0x12;assert(stereo_accept_target(&box)&&last_capture==7);
    state=0x12;scene_change=80;assert(!stereo_accept_target(&box));
    reset(20);state=0x12;assert(!stereo_accept_target(&box));
    reset(30);state=0x12;assert(!stereo_accept_target(&box));
    reset(40);cancel_poll=1;assert(!stereo_monitor()&&!stereo_enabled&&page_request==0);
    stereo_reader_t reader={.reads=255};uint8_t pixel;
    assert(stereo_read_pixel(&reader,0,30,30,&pixel)==-1&&reader.cancelled);
    unsigned before=mmio_reads;assert(stereo_read_pixel(&reader,0,31,30,&pixel)==-1);
    assert(mmio_reads==before);
    reset(40);stereo_calibration.verified=1;
    assert(!stereo_accept_target(&box));
    assert(stereo_monitor()&&!stereo_enabled&&page_request==0);
    puts("TEST_PASS stereo_platform metadata/chunks/errors/near/far/boundary/scene-change/manual-cancel/uncalibrated");
    return 0;
}
