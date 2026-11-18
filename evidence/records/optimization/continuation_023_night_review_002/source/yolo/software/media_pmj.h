#ifndef MEDIA_PMJ_H
#define MEDIA_PMJ_H
#include <stdint.h>
enum {PMJ_OK=0,PMJ_IO=-30,PMJ_FORMAT=-31,PMJ_RANGE=-32,PMJ_CRC=-33};
typedef struct {
    int (*read)(void*,uint32_t offset,void*,uint32_t length);
    void *context;
    uint32_t size;
} media_pmj_reader_t;
typedef struct {
    media_pmj_reader_t file;
    uint32_t count,fps,index_offset,payload_offset;
    uint16_t width,height;
} media_pmj_t;
typedef struct {uint32_t offset,length,crc32,pts_ms;} media_pmj_frame_t;
uint32_t media_crc32_update(uint32_t,const uint8_t*,uint32_t);
int media_pmj_open(media_pmj_t*,const media_pmj_reader_t*);
int media_pmj_frame(media_pmj_t*,uint32_t index,media_pmj_frame_t*);
int media_pmj_check_frame(media_pmj_t*,const media_pmj_frame_t*);
#endif
