#ifndef APPLICATION_VISION_H
#define APPLICATION_VISION_H
#include "yolo_decode.h"
#define VISION_BOXES 8u
#define VISION_THUMB_WORDS 4800u
typedef struct {uint32_t xy0,xy1,info;} VisionBox;
typedef struct {uint32_t frame,elapsed,counts,flags;VisionBox box[VISION_BOXES];} VisionPacket;
/* xy1 is exclusive, in a 320x240 display viewport. counts: raw[7:0], shown[15:8]. */
void vision_pack(VisionPacket *,const yolo_box_t *,unsigned,unsigned,unsigned,uint32_t,uint32_t);
uint8_t vision_rgb332(uint16_t);
uint32_t vision_thumb_word(const uint16_t *,unsigned,unsigned,unsigned);
void vision_trace(const VisionPacket *,void (*)(void *,char),void *);
#endif
