#include "app_yolo.h"
unsigned app_yolo_bin(unsigned c) {
 /* New YOLO labels: biodegradable, cardboard, glass, metal, paper, plastic.
  * The integration defines no validated mapping for hazardous/other classes.
  * Keep this model honest: organic -> category 0, recyclable -> category 1,
  * everything else is unmapped. */
 if (c == 0) return 0u;
 return c >= 1 && c <= 5 ? 1u : 255u;
}
int app_yolo_preprocess(const uint16_t *src,unsigned w,unsigned h,int8_t *dst,AppLetterbox *l) {
 if(!src||!dst||!l||!w||!h||w>8192||h>8192)return 0;
 unsigned nw=320,nh=320;
 if(w>=h)nh=(h*320+w/2)/w;else nw=(w*320+h/2)/h;
 if(!nw||!nh)return 0;
 unsigned px=(320-nw)/2,py=(320-nh)/2;
 l->ratio=w>=h?320.f/w:320.f/h;l->pad_x=(float)px;l->pad_y=(float)py;
 for(unsigned y=0;y<320;y++)for(unsigned x=0;x<320;x++) {
  int8_t *p=dst+(y*320+x)*8;p[0]=p[1]=p[2]=57;
  for(unsigned c=3;c<8;c++)p[c]=0;
  if(x>=px&&x<px+nw&&y>=py&&y<py+nh) {
   uint16_t v=src[((y-py)*h/nh)*w+(x-px)*w/nw];
   unsigned r=((v>>11)*255+15)/31,g=(((v>>5)&63)*255+31)/63,b=((v&31)*255+15)/31;
   p[0]=(int8_t)((r*127+127)/255);p[1]=(int8_t)((g*127+127)/255);p[2]=(int8_t)((b*127+127)/255);
  }
 }
 return 1;
}
