#ifndef SORTING_APP_H
#define SORTING_APP_H
#include <stdint.h>
enum { ST_IDLE, ST_WAIT_ANSWER, ST_WAIT_CLEAR, ST_FAULT };
enum {
  APP_OK = 0, APP_INVALID = -1, APP_BUSY = -2, APP_DUPLICATE = -3,
  APP_OVERFLOW = -4
};
enum { ACT_PLAY = 1 };
enum {
  VOICE_PROMPT = 1,
  VOICE_CORRECT = 2,
  VOICE_WRONG = 3,
  VOICE_TIMEOUT = 4,
  REWARD_MUSIC0 = 5
};
typedef struct { uint32_t type, id, a, b; } Action;
typedef struct {
  uint32_t state, mode, session, correct, choice, deadline, last_frame, stable,
      stable_class, queue_head, queue_tail, error, seen_frame, points;
  Action queue[32];
} App;
int app_init(App *);
int app_mode(App *, unsigned);
int app_detect(App *, uint32_t frame, unsigned count, unsigned bin,
               unsigned conf_q15, uint32_t now);
int app_answer(App *, uint32_t session, unsigned bin, uint32_t now);
void app_tick(App *, uint32_t now);
int app_pop(App *, Action *);
#endif

