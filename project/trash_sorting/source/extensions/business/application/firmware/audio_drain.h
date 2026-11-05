#ifndef AUDIO_DRAIN_H
#define AUDIO_DRAIN_H
#include <stdint.h>
enum { AUDIO_WAIT=0,AUDIO_STARTED=1,AUDIO_DONE=2,AUDIO_FAILED=-1 };
typedef struct { uint32_t begin,baseline,total; uint16_t starts; int notified; } AudioDrain;
void audio_drain_begin(AudioDrain *,uint32_t,uint32_t,uint16_t);
void audio_drain_submit(AudioDrain *,uint32_t);
/* completed counts fully transmitted stereo frames, not popped FIFO entries. */
int audio_drain_poll(AudioDrain *,uint32_t,uint32_t,uint16_t);
#endif
