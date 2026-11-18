#include "audio_drain.h"
void audio_drain_begin(AudioDrain *a,uint32_t now,uint32_t completed,uint16_t starts){
 *a=(AudioDrain){now,completed,0,starts,0};
}
void audio_drain_submit(AudioDrain *a,uint32_t frames){a->total+=frames;}
int audio_drain_poll(AudioDrain *a,uint32_t now,uint32_t completed,uint16_t starts){
 if(!a->notified&&starts!=a->starts){a->notified=1;return AUDIO_STARTED;}
 if(a->notified&&a->total&&(uint32_t)(completed-a->baseline)>=a->total)return AUDIO_DONE;
 if(!a->notified&&(uint32_t)(now-a->begin)>5000)return AUDIO_FAILED;
 return AUDIO_WAIT;
}
