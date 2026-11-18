#ifndef MEDIA_SDMMC_H
#define MEDIA_SDMMC_H
#include <stdint.h>
enum {SDMMC_OK=0,SDMMC_IO=-20,SDMMC_TIMEOUT=-21,SDMMC_CANCELLED=-22,
      SDMMC_CRC=-23,SDMMC_RESPONSE=-24,SDMMC_UNSUPPORTED=-25,SDMMC_RANGE=-26};
typedef struct {
    int (*read32)(void*,uint32_t,uint32_t*);
    int (*write32)(void*,uint32_t,uint32_t);
    uint32_t (*milliseconds)(void*);
    int (*cancelled)(void*);
    void *context;
} media_sdmmc_io_t;
typedef struct {
    media_sdmmc_io_t io;
    uint32_t clock_hz,sectors;
    uint16_t rca;
    uint8_t high_capacity,wide,ready;
} media_sdmmc_t;
void media_sdmmc_setup(media_sdmmc_t*,const media_sdmmc_io_t*,uint32_t clock_hz);
int media_sdmmc_init(media_sdmmc_t*);
int media_sdmmc_read(media_sdmmc_t*,uint32_t lba,uint8_t data[512]);
/* Read and verify a sector into the hardware FIFO without copying to CPU RAM. */
int media_sdmmc_read_begin(media_sdmmc_t*,uint32_t lba);
int media_sdmmc_sector_callback(void*,uint32_t,uint8_t[512]);
void media_sdmmc_abort(media_sdmmc_t*);
#endif
