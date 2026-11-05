#include "platform.h"
#include "audio_drain.h"
#ifdef BUSINESS_GATEWAY
#include "platform_business.h"
#endif
#include "vision.h"
#include "board_config.h"
#include "deployment_model.h"
#include "yolo_decode.h"
#include <math.h>
#include "regs.h"
#include <string.h>
static Fat fs;
static SdSpi sd;
static uint32_t gpio = 0x17;

static uint32_t audio_id, audio_left, audio_offset;
/* Asset ID currently being streamed (5..7 are MUSIC0..2). */
static unsigned current_audio_asset;
static unsigned audio_channels;
static int audio_active, audio_sent, audio_notified;
static uint16_t audio_starts;
static uint32_t audio_begin;
static AudioDrain audio_drain;
static uint32_t audio_under;
/* Audio assets are stored on the SD card and streamed through the board's
 * I²S pins to an external amplifier.  The WAV names use FAT 8.3 spelling. */
#define AUDIO_ASSET_COUNT 7u
static const char *names[AUDIO_ASSET_COUNT] = {
    "PROMPT  WAV", "CORRECT WAV", "WRONG   WAV", "TIMEOUT WAV",
    "MUSIC0  WAV", "MUSIC1  WAV", "MUSIC2  WAV"};
uint32_t platform_ms(void) { return REG32(APP_BASE, R_MILLIS); }
void platform_log(const char *s) {
  while (*s) {
    while (REG32(UART_BASE, 4) & 1) {
    }
    REG32(UART_BASE, 0) = (unsigned char)*s++;
  }
}
void platform_idle(void) { __asm__ volatile("nop"); }
static void gpio_set(unsigned bit, int value) {
  if (value)
    gpio |= 1u << bit;
  else
    gpio &= ~(1u << bit);
  REG32(APP_BASE, R_GPIO_OUT) = gpio;
}
static void delay(void *c) {
  (void)c;
  for (volatile unsigned i = 0; i < 70; i++)
    platform_idle();
}
static uint8_t spi(void *c, uint8_t v) {
  (void)c;
  uint8_t r = 0;
  for (int i = 7; i >= 0; i--) {
    gpio_set(3, 0);
    gpio_set(4, (v >> i) & 1);
    delay(0);
    gpio_set(3, 1);
    delay(0);
    r = (r << 1) | !!(REG32(APP_BASE, R_GPIO_IN) & 16);
  }
  gpio_set(3, 0);
  return r;
}
static void cs(void *c, int selected) {
  (void)c;
  gpio_set(2, !selected);
  delay(0);
}
static int index_of(unsigned asset) {
  if (asset >= 1 && asset <= AUDIO_ASSET_COUNT)
    return (int)asset - 1;
  return -1;
}
typedef struct {
  uint32_t address;
  Wav wav;
  int ready;
} CachedAudio;
static CachedAudio audio_cache[AUDIO_ASSET_COUNT];
static uint32_t current_audio_base, consumed_frame;
static void preload_audio(void) {
  uint32_t offset = 0;
  memset(audio_cache, 0, sizeof(audio_cache));
  for (unsigned i = 0; i < AUDIO_ASSET_COUNT; i++) {
    FatFile f;
    Wav wav;
    if (!fat_open(&fs, names[i], &f) || f.size > AUDIO_CAPACITY ||
        f.size > AUDIO_TOTAL_CAPACITY - offset)
      continue;
    uint32_t base = AUDIO_ADDR + offset;
    if (fat_read(&f, (void *)(uintptr_t)base, f.size) != (int)f.size ||
        !wav_parse((const uint8_t *)(uintptr_t)base, f.size, &wav))
      continue;
    audio_cache[i] = (CachedAudio){base, wav, 1};
    offset = (offset + f.size + 63) & ~63u;
  }
}
static int asset(void *c, unsigned id) {
  (void)c;
  int i = index_of(id);
  return i >= 0 && audio_cache[i].ready;
}
static void audio_stop(void *c) {
  (void)c;
  REG32(APP_BASE, R_AUDIO_EN) = 0;
  audio_active = 0;
  audio_left = 0;
  current_audio_asset = 0;
}
static int audio_play(void *c, unsigned id, unsigned request) {
  (void)c;
  int i = index_of(id);
  if (i < 0 || !audio_cache[i].ready)
    return 0;
  audio_stop(0);
  /* Let enable and the final completed-frame Gray counter settle across CDC. */
  uint32_t settle=platform_ms();
  while((uint32_t)(platform_ms()-settle)<1)platform_idle();
  Wav w = audio_cache[i].wav;
  current_audio_base = audio_cache[i].address;
  current_audio_asset = (unsigned)i + 1;
  audio_id = request;
  audio_left = w.bytes;
  audio_offset = w.data;
  audio_channels = w.channels;
  audio_active = 1;
  audio_sent = 0;
  audio_notified = 0;
  audio_begin = platform_ms();
  audio_starts = (uint16_t)REG32(APP_BASE, R_AUDIO_STARTS);
  audio_under=REG32(APP_BASE,R_AUDIO_UNDERRUN);
  audio_drain_begin(&audio_drain,audio_begin,REG32(APP_BASE,R_AUDIO_COMPLETED),audio_starts);
  REG32(APP_BASE, R_AUDIO_EN) = 1;
  return 1;
}
static void view(void *c, const App *a, unsigned confirm) {
  (void)c;
  if (REG32(APP_BASE, R_UI_BUSY))
    return;
  REG32(APP_BASE, R_UI_STATE) = a->state;
  REG32(APP_BASE, R_UI_POINTS) = a->points;
  REG32(APP_BASE, R_UI_SESSION) = a->session;
  uint32_t flags = (a->mode & 1) | ((a->correct & 255) << 8) |
                   ((a->choice & 255) << 16) | ((a->choice < 4) << 23) |
                   ((confirm & 7) << 24);
  /* UI_FLAGS[27] drives the music-playing indicator and [28] advertises the
   * default MUSIC0 asset. The I²S transmitter is in application_soc; no
   * speaker signal is driven directly from a GPIO. */
  flags |= (uint32_t)(audio_active && audio_notified &&
                      current_audio_asset >= 5 && current_audio_asset <= 7)
           << 27;
  flags |= (uint32_t)asset(0, 5) << 28;
  REG32(APP_BASE, R_UI_FLAGS) = flags;
  REG32(APP_BASE, R_UI_COMMIT) = 1;
}
static void audio_poll(System *system) {
  if (!audio_active)
    return;
  unsigned budget=256;
  while (budget-- && audio_left && (REG32(APP_BASE, R_AUDIO_STATUS) & 1)) {
    const uint8_t *p =
        (const uint8_t *)(uintptr_t)(current_audio_base + audio_offset);
    uint16_t l = p[0] | p[1] << 8,
             r = audio_channels == 1 ? l : p[2] | p[3] << 8;
    REG32(APP_BASE, R_AUDIO_DATA) = ((uint32_t)l << 16) | r;
    audio_offset += audio_channels * 2;
    audio_left -= audio_channels * 2;
    audio_sent = 1;
    audio_drain_submit(&audio_drain,1);
  }
  if (!audio_notified &&
      (uint16_t)REG32(APP_BASE, R_AUDIO_STARTS) != audio_starts) {
    audio_notified = 1;
    audio_under=REG32(APP_BASE,R_AUDIO_UNDERRUN);
#ifdef BUSINESS_GATEWAY
    business_event(1,audio_id,0);
#endif
  }
  int state=audio_drain_poll(&audio_drain,platform_ms(),REG32(APP_BASE,R_AUDIO_COMPLETED),
                            (uint16_t)REG32(APP_BASE,R_AUDIO_STARTS));
  int failed=(state==AUDIO_FAILED)||
      (audio_notified&&audio_left&&REG32(APP_BASE,R_AUDIO_UNDERRUN)!=audio_under)||
      (REG32(APP_BASE,R_AUDIO_STATUS)&4);
  if(failed||(!audio_left&&audio_sent&&state==AUDIO_DONE)) {
#ifdef BUSINESS_GATEWAY
    uint32_t id = audio_id;
#endif
    audio_stop(0);
    if (system)
      system_audio_complete(system, failed ? 0 : 1);
#ifdef BUSINESS_GATEWAY
    business_event(failed?3:2,id,0);
#endif
  }
}
int platform_init(System *s) {
  REG32(APP_BASE, R_AUDIO_EN) = 0;
  sd = (SdSpi){0, spi, cs, 0, 30000};

  if (!BOARD_CONFIRMED) {
    platform_log("BLOCKED: board configuration is unverified\r\n");
    return 0;
  }
  if (REG32(APP_BASE, R_VERSION) != 0x10000 || !REG32(APP_BASE, R_DDR_READY) ||
      !sd_init(&sd) || !fat_mount(&fs, sd_read, &sd)) {
    platform_log("FAULT: MMIO/DDR/SD self-test\r\n");
    return 0;
  }
  preload_audio();
  DeviceOps ops = {0, asset, audio_play, view};
  return system_init(s, ops) == APP_OK;
}
void platform_poll(System *s) {
  if (s->app.state == ST_FAULT) {
    audio_stop(0);
    return;
  }
  if (audio_active ||
      (s->app.state != ST_IDLE && s->app.state != ST_WAIT_CLEAR)) {
    consumed_frame = REG32(APP_BASE, R_CAM_ID);
    REG32(APP_BASE, R_CAM_ACK) = consumed_frame;
  }
  audio_poll(s);
  system_tick(s, platform_ms());
}
#ifndef BUSINESS_GATEWAY
static uint32_t crc(const uint8_t *p, unsigned n) {
  uint32_t c = ~0u;
  while (n--) {
    c ^= *p++;
    for (int j = 0; j < 8; j++)
      c = (c >> 1) ^ ((0u - (c & 1)) & 0xedb88320u);
  }
  return ~c;
}
#include "platform_yolo.inc"
#else
unsigned platform_business_init(void){
 REG32(APP_BASE,R_AUDIO_EN)=0;
 sd=(SdSpi){0,spi,cs,0,30000};
 unsigned caps=0;
 if(!BOARD_CONFIRMED)return 0;
 if(REG32(APP_BASE,R_DDR_READY)&&sd_init(&sd)&&fat_mount(&fs,sd_read,&sd)){
  preload_audio();
  /* Capability bit 1 means the complete voice + music set is present. */
  int ready = 1;
  for (unsigned id = 1; id <= AUDIO_ASSET_COUNT; ++id)
    ready &= asset(0, id);
  if (ready) caps |= 2;
 }
 return caps;
}
void platform_business_poll(void){audio_poll(0);}
int platform_business_servo(unsigned bin,uint32_t id,int open){(void)bin;(void)id;(void)open;return 0;}
int platform_business_audio(unsigned id,uint32_t request){return audio_play(0,id,request);}
void platform_business_stop(void){audio_stop(0);}
int platform_business_audio_active(void){return audio_active;}
#endif
