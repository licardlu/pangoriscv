#include "vision.h"
#include "app_yolo.h"
#include <math.h>
#include <string.h>
uint8_t vision_rgb332(uint16_t v) {
 return (uint8_t)(((v>>8)&0xe0)|((v>>6)&0x1c)|((v>>3)&3));
}
uint32_t vision_thumb_word(const uint16_t *src,unsigned w,unsigned h,unsigned word) {
 if(!src||!w||!h||word>=VISION_THUMB_WORDS)return 0;
 uint32_t v=0;
 for(unsigned j=0;j<4;j++) {
  unsigned p=word*4+j,x=(p%160)*w/160,y=(p/160)*h/120;
  v|=(uint32_t)vision_rgb332(src[y*w+x])<<(j*8);
 }
 return v;
}
static float limit(float x,float maximum) {return x<0?0:x>maximum?maximum:x;}
void vision_pack(VisionPacket *p,const yolo_box_t *b,unsigned n,unsigned w,unsigned h,
                 uint32_t frame,uint32_t elapsed) {
 memset(p,0,sizeof(*p));p->frame=frame;p->elapsed=elapsed;
 if(!w||!h||n>YOLO_MAX_RESULTS||(!b&&n))return;
 p->flags=1;p->counts=n;
 float scores[VISION_BOXES]={0};unsigned shown=0;
 for(unsigned i=0;i<n;i++) {
  if(!isfinite(b[i].x1)||!isfinite(b[i].y1)||!isfinite(b[i].x2)||
     !isfinite(b[i].y2)||!isfinite(b[i].score)||b[i].score<=0||
     b[i].score>1||b[i].category>=YOLO_CLASSES)continue;
  float x1=limit(b[i].x1,(float)w),y1=limit(b[i].y1,(float)h);
  float x2=limit(b[i].x2,(float)w),y2=limit(b[i].y2,(float)h);
  if(x2<=x1||y2<=y1)continue;
  unsigned at=0;while(at<shown&&scores[at]>=b[i].score)at++;
  if(at>=VISION_BOXES)continue;
  if(shown<VISION_BOXES)shown++;
  for(unsigned k=shown-1;k>at;k--){scores[k]=scores[k-1];p->box[k]=p->box[k-1];}
  unsigned ax=(unsigned)(x1*320/w),ay=(unsigned)(y1*240/h);
  unsigned bx=(unsigned)ceilf(x2*320/w),by=(unsigned)ceilf(y2*240/h);
  p->box[at]=(VisionBox){ax|(ay<<16),bx|(by<<16),
   b[i].category|((unsigned)(b[i].score*100+.5f)<<8)|(app_yolo_bin(b[i].category)<<16)};
  scores[at]=b[i].score;
 }
 p->counts|=shown<<8;
}
static void trace_text(void (*put)(void *,char),void *c,const char *s) {
 while(*s)put(c,*s++);
}
static void trace_hex(void (*put)(void *,char),void *c,uint32_t value) {
 static const char digits[]="0123456789abcdef";
 put(c,',');for(int shift=28;shift>=0;shift-=4)put(c,digits[(value>>shift)&15]);
}
void vision_trace(const VisionPacket *p,void (*put)(void *,char),void *c) {
 if(!p||!put)return;
 trace_text(put,c,"V1");trace_hex(put,c,p->frame);trace_hex(put,c,p->elapsed);
 trace_hex(put,c,p->counts);trace_hex(put,c,p->flags);put(c,'\n');
 unsigned shown=(p->counts>>8)&255;if(shown>VISION_BOXES)shown=VISION_BOXES;
 for(unsigned i=0;i<shown;i++) {
  trace_text(put,c,"B1");trace_hex(put,c,p->frame);trace_hex(put,c,p->box[i].xy0);
  trace_hex(put,c,p->box[i].xy1);trace_hex(put,c,p->box[i].info);put(c,'\n');
 }
 trace_text(put,c,"E1");trace_hex(put,c,p->frame);put(c,'\n');
}
