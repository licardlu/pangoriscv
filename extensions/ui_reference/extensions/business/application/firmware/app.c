#include "app.h"
#include <string.h>

static int due(uint32_t now, uint32_t deadline) {
  return (int32_t)(now - deadline) >= 0;
}

static int queue_space(App *app, unsigned needed) {
  if (app->queue_head - app->queue_tail + needed > 32) {
    app->error = (uint32_t)-APP_OVERFLOW;
    app->state = ST_FAULT;
    return 0;
  }
  return 1;
}

static void push(App *app, unsigned type, uint32_t id, unsigned value,
                 unsigned extra) {
  Action *action = &app->queue[app->queue_head++ % 32];
  action->type = type;
  action->id = id;
  action->a = value;
  action->b = extra;
}

int app_pop(App *app, Action *action) {
  if (!app || !action || app->queue_head == app->queue_tail) return 0;
  *action = app->queue[app->queue_tail++ % 32];
  return 1;
}

int app_init(App *app) {
  if (!app) return APP_INVALID;
  memset(app, 0, sizeof(*app));
  app->correct = 255;
  app->choice = 255;
  app->stable_class = 255;
  app->state = ST_IDLE;
  return APP_OK;
}

int app_mode(App *app, unsigned mode) {
  if (!app || mode > 1) return APP_INVALID;
  if (app->state != ST_IDLE) return APP_BUSY;
  app->mode = mode;
  app->stable = 0;
  app->stable_class = 255;
  return APP_OK;
}

int app_detect(App *app, uint32_t frame, unsigned count, unsigned bin,
               unsigned confidence_q15, uint32_t now) {
  if (!app) return APP_INVALID;
  if (app->seen_frame && (int32_t)(frame - app->last_frame) <= 0)
    return APP_DUPLICATE;
  app->seen_frame = 1;
  app->last_frame = frame;

  if (count == 0) {
    app->stable = 0;
    app->stable_class = 255;
    return APP_OK;
  }
  if (app->state != ST_IDLE) return APP_BUSY;
  /* 0.25 * 32767 truncates to 8191 in the current platform adapter. */
  if (count != 1 || bin > 3 || confidence_q15 < 8191u) {
    app->stable = 0;
    app->stable_class = 255;
    return APP_INVALID;
  }
  if (app->stable_class != bin) {
    app->stable_class = bin;
    app->stable = 0;
  }
  if (++app->stable < 3) return APP_OK;

  if (!queue_space(app, 1)) return APP_OVERFLOW;
  app->session++;
  app->correct = bin;
  app->choice = 255;
  app->stable = 0;
  app->state = app->mode ? ST_WAIT_ANSWER : ST_WAIT_CLEAR;
  app->deadline = app->mode ? now + 15000 : now + 2000;
  push(app, ACT_PLAY, app->session, VOICE_PROMPT, 0);
  return APP_OK;
}

int app_answer(App *app, uint32_t session, unsigned bin, uint32_t now) {
  if (!app || app->state != ST_WAIT_ANSWER) return APP_BUSY;
  if (session != app->session || bin > 3) return APP_INVALID;
  if (due(now, app->deadline)) {
    app_tick(app, now);
    return APP_BUSY;
  }
  if (!queue_space(app, 1)) return APP_OVERFLOW;

  app->choice = bin;
  app->state = ST_WAIT_CLEAR;
  app->deadline = now + 2000;
  if (bin == app->correct) {
    /* Queue the spoken confirmation first.  The service layer starts the
       reward track only after this prompt reports a real audio completion. */
    app->points = app->points > UINT32_MAX - 100u ? UINT32_MAX : app->points + 100u;
    push(app, ACT_PLAY, app->session, VOICE_CORRECT, REWARD_MUSIC0);
  } else {
    push(app, ACT_PLAY, app->session, VOICE_WRONG, 0);
  }
  return APP_OK;
}

void app_tick(App *app, uint32_t now) {
  if (!app) return;
  if (app->state == ST_WAIT_ANSWER && due(now, app->deadline)) {
    if (!queue_space(app, 1)) return;
    push(app, ACT_PLAY, app->session, VOICE_TIMEOUT, 0);
    app->state = ST_WAIT_CLEAR;
  } else if (app->state == ST_WAIT_CLEAR && due(now, app->deadline)) {
    app->state = ST_IDLE;
    app->correct = 255;
    app->choice = 255;
    app->stable = 0;
    app->stable_class = 255;
  }
}
