#ifndef MEDIA_PLAYER_H
#define MEDIA_PLAYER_H
#include <stdint.h>
typedef struct {
    int (*read)(void*,uint32_t,uint32_t*);
    int (*write)(void*,uint32_t,uint32_t);
    uint32_t (*milliseconds)(void*);
    uint32_t (*page)(void*);
    void *context;
} media_player_io_t;
typedef struct {uint32_t frames,skipped,errors;int32_t last_error;uint32_t index,state;} media_player_stats_t;
void media_player_setup(const media_player_io_t*,uint32_t clock_hz,uint16_t width,uint16_t height);
void media_player_poll(void);
void media_player_pause(int paused);
int media_player_paused(void);
const media_player_stats_t *media_player_statistics(void);
int media_player_audio_statistics(uint32_t result[9]);
typedef int (*media_model_write_fn)(void*,uint32_t,const uint8_t*,uint32_t);
/* Boot only, before playback: MODEL.BIN must match the firmware's size/CRC.
 * The caller must independently verify DDR before enabling inference. */
int media_player_load_model(uint32_t length,uint32_t crc,media_model_write_fn,void*);
#endif
