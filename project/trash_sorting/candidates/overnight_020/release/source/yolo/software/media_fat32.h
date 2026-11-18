#ifndef MEDIA_FAT32_H
#define MEDIA_FAT32_H
#include <stdint.h>

/* A read-only 512-byte block interface; no write/erase API is provided. */
typedef int (*media_sector_read_fn)(void *,uint32_t,uint8_t [512]);
enum { MEDIA_OK=0,MEDIA_EOF=1,MEDIA_IO=-1,MEDIA_FORMAT=-2,
       MEDIA_NOT_FOUND=-3,MEDIA_CHAIN=-4,MEDIA_RANGE=-5 };
typedef struct {
    media_sector_read_fn read;
    void *context;
    uint32_t partition,total_sectors,fat_start,fat_sectors,data_start;
    uint32_t clusters,root_cluster,cached_fat_sector;
    uint8_t sectors_per_cluster,fat_cached;
    uint8_t fat_cache[512],sector[512];
} media_fat32_t;
typedef struct {
    media_fat32_t *fs;
    uint32_t first_cluster,size,cached_cluster,cached_index;
} media_file_t;
typedef struct {uint32_t lba,skip,length;} media_extent_t;
int media_fat32_mount(media_fat32_t *,media_sector_read_fn,void *,uint32_t);
int media_fat32_open(media_fat32_t *,const char short_name[11],media_file_t *);
int media_fat32_read(media_file_t *,uint32_t offset,void *,uint32_t length);
/* Map the next portion of a file within one SD sector, without reading it. */
int media_fat32_map(media_file_t *,uint32_t offset,media_extent_t *);
#endif
