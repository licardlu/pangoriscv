#include "service.h"
#include <string.h>

static void update(System *system) {
  if (system->ops.view)
    system->ops.view(system->ops.ctx, &system->app, 0);
}

int system_init(System *system, DeviceOps ops) {
  if (!system) return APP_INVALID;
  memset(system, 0, sizeof(*system));
  system->ops = ops;
  int result = app_init(&system->app);
  update(system);
  return result;
}

static int start_audio(System *system, unsigned asset, unsigned request,
                       unsigned next_asset) {
  int available = system->ops.asset &&
                  system->ops.asset(system->ops.ctx, asset);
  int started = available && system->ops.play &&
                system->ops.play(system->ops.ctx, asset, request);
  if (!started) {
    if (system->app.error == 0) system->app.error = 2;
    return 0;
  }
  system->audio_busy = 1;
  system->pending_audio = next_asset;
  return 1;
}

void system_actions(System *system) {
  if (!system) return;
  Action action;
  while (!system->audio_busy && app_pop(&system->app, &action)) {
    if (action.type == ACT_PLAY) {
      (void)start_audio(system, action.a, action.id, action.b);
    }
  }
  update(system);
}

int system_audio_complete(System *system, int success) {
  if (!system || !system->audio_busy) return APP_BUSY;
  unsigned next = system->pending_audio;
  system->pending_audio = 0;
  system->audio_busy = 0;
  if (!success) {
    if (system->app.error == 0) system->app.error = 3;
    update(system);
    return APP_INVALID;
  }
  if (next) {
    /* Start the chained reward only after the completed-frame/underrun
     * callback.  This prevents a second play() from truncating the prompt. */
    if (!start_audio(system, next, system->app.session, 0)) {
      update(system);
      return APP_INVALID;
    }
  } else {
    /* A completed prompt may have been holding an answer action in the app
     * queue.  It is safe to dispatch it now that the transmitter is idle. */
    system_actions(system);
    return APP_OK;
  }
  update(system);
  return APP_OK;
}

int system_keys(System *system, uint8_t pressed, uint32_t now) {
  if (!system) return APP_INVALID;
  uint8_t changed = (uint8_t)(pressed & (uint8_t)~system->keys_down);
  system->keys_down = pressed;
  int result = APP_INVALID;
  if (system->app.state == ST_IDLE && (changed & 1u)) {
    result = app_mode(&system->app, system->app.mode ? 0u : 1u);
  } else if (system->app.state == ST_WAIT_ANSWER) {
    for (unsigned i = 0; i < 4; ++i) {
      if (changed & (1u << (i + 1))) {
        result = app_answer(&system->app, system->app.session, i, now);
        break;
      }
    }
  } else if (!changed) {
    result = APP_OK;
  }
  system_actions(system);
  return result;
}

void system_tick(System *system, uint32_t now) {
  if (!system) return;
  app_tick(&system->app, now);
  system_actions(system);
}
