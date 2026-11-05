#ifndef APP_SERVICE_H
#define APP_SERVICE_H
#include "app.h"
#include <stdint.h>
typedef struct {
  void *ctx;
  int (*asset)(void *, unsigned);
  int (*play)(void *, unsigned, unsigned);
  void (*view)(void *, const App *, unsigned);
} DeviceOps;
typedef struct {
  App app;
  DeviceOps ops;
  uint8_t keys_down;
  /* Non-zero while one physical audio stream owns the transmitter.  A
   * pending asset is launched only from system_audio_complete(), after the
   * preceding stream has drained successfully. */
  uint32_t pending_audio;
  uint32_t audio_busy;
} System;
int system_init(System *, DeviceOps);
/* Normalized active-high key bits: bit0 selects auto/quiz; bits1..4 answer. */
int system_keys(System *, uint8_t pressed, uint32_t now);
void system_tick(System *, uint32_t);
void system_actions(System *);
int system_audio_complete(System *, int success);
#endif
