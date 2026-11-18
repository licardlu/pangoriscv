#include "service.h"
#include <stdio.h>

static unsigned checks, failures;
#define CHECK(x) do { checks++; if (!(x)) { printf("FAIL:%d %s\n", __LINE__, #x); failures++; } } while (0)

static unsigned played[8], played_count;
static unsigned servo_bin = 99, servo_calls;
static int voice_asset(void *ctx, unsigned id) {
  (void)ctx;
  return id >= VOICE_PROMPT && id <= REWARD_MUSIC0;
}
static int voice_play(void *ctx, unsigned id, unsigned event) {
  (void)ctx;
  (void)event;
  if (played_count < sizeof(played) / sizeof(played[0])) played[played_count++] = id;
  return 1;
}
static int servo_action(void *ctx, unsigned bin, unsigned open) {
  (void)ctx;
  if (open && bin < 4) { servo_bin = bin; servo_calls++; return 1; }
  return 0;
}

static void feed(App *app, uint32_t *frame, unsigned count, unsigned bin,
                 unsigned confidence) {
  for (unsigned i = 0; i < 3; ++i) {
    uint32_t id = (*frame)++;
    (void)app_detect(app, id, count, bin, confidence, id * 100);
  }
}

static void automatic_mode_only_announces_detection(void) {
  App app;
  Action action;
  uint32_t frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_mode(&app, 0) == APP_OK);
  feed(&app, &frame, 1, 1, 30000);
  CHECK(app.state == ST_WAIT_CLEAR);
  CHECK(app.correct == 1);
  CHECK(app_pop(&app, &action));
  CHECK(action.type == ACT_PLAY && action.a == VOICE_PROMPT);
  CHECK(!app_pop(&app, &action));
}

static void quiz_answer_plays_reward_music_and_scores(void) {
  App app;
  Action action;
  uint32_t frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_mode(&app, 1) == APP_OK);
  feed(&app, &frame, 1, 2, 30000);
  CHECK(app.state == ST_WAIT_ANSWER);
  CHECK(app_pop(&app, &action) && action.type == ACT_PLAY &&
        action.a == VOICE_PROMPT);
  CHECK(app_answer(&app, app.session, 2, 1000) == APP_OK);
  CHECK(app.state == ST_WAIT_CLEAR);
  CHECK(app_pop(&app, &action) && action.type == ACT_SERVO &&
        action.a == 2 && action.b == 1);
  CHECK(app_pop(&app, &action) && action.type == ACT_PLAY &&
        action.a == VOICE_CORRECT && action.b == REWARD_MUSIC0);
  CHECK(app.points == 100);
  CHECK(app_answer(&app, app.session, 2, 1001) == APP_BUSY);
  CHECK(app.points == 100); /* repeated/held answer cannot award twice */
  CHECK(!app_pop(&app, &action));

  frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_mode(&app, 1) == APP_OK);
  feed(&app, &frame, 1, 2, 30000);
  CHECK(app_pop(&app, &action)); /* prompt */
  CHECK(app_answer(&app, app.session, 0, 1000) == APP_OK);
  CHECK(app_pop(&app, &action) && action.type == ACT_SERVO &&
        action.a == 2 && action.b == 1); /* correct bin opens even if answer is wrong */
  CHECK(app_pop(&app, &action) && action.type == ACT_PLAY &&
        action.a == VOICE_WRONG);
  CHECK(app.points == 0);
  CHECK(!app_pop(&app, &action));
}

static void invalid_and_repeated_detections_do_not_start_a_turn(void) {
  App app;
  Action action;
  uint32_t frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_detect(&app, frame, 2, 1, 30000, 100) == APP_INVALID);
  CHECK(app_detect(&app, ++frame, 1, 4, 30000, 200) == APP_INVALID);
  CHECK(app_detect(&app, ++frame, 1, 1, 8190, 300) == APP_INVALID);
  CHECK(app_detect(&app, ++frame, 1, 1, 30000, 400) == APP_OK);
  CHECK(app_detect(&app, frame, 1, 1, 30000, 500) == APP_DUPLICATE);
  CHECK(app.state == ST_IDLE);
  CHECK(!app_pop(&app, &action));
}

static void quarter_confidence_survives_q15_conversion(void) {
  App app;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_detect(&app, 1, 1, 0, 8191, 100) == APP_OK);
  CHECK(app_detect(&app, 2, 1, 0, 8191, 200) == APP_OK);
  CHECK(app_detect(&app, 3, 1, 0, 8191, 300) == APP_OK);
  CHECK(app.state == ST_WAIT_CLEAR);
}

static void quiz_timeout_announces_without_opening_hardware(void) {
  App app;
  Action action;
  uint32_t frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_mode(&app, 1) == APP_OK);
  feed(&app, &frame, 1, 3, 30000);
  CHECK(app_pop(&app, &action)); /* prompt */
  app_tick(&app, 15300);
  CHECK(app.state == ST_WAIT_CLEAR);
  CHECK(app_pop(&app, &action) && action.type == ACT_PLAY &&
        action.a == VOICE_TIMEOUT);
  CHECK(!app_pop(&app, &action));
}

static void button_answers_dispatch_voice_then_reward_music(void) {
  System system;
  DeviceOps ops = {0, voice_asset, voice_play, 0, servo_action};
  played_count = 0;
  servo_calls = 0; servo_bin = 99;
  CHECK(system_init(&system, ops) == APP_OK);
  CHECK(system_keys(&system, 1u, 0) == APP_OK); /* KEY0 selects quiz */
  CHECK(system_keys(&system, 0, 1) == APP_OK);
  for (uint32_t frame = 1; frame <= 3; ++frame)
    CHECK(app_detect(&system.app, frame, 1, 1, 30000, frame * 100) == APP_OK);
  system_actions(&system);
  CHECK(played_count == 1 && played[0] == VOICE_PROMPT);
  CHECK(system_audio_complete(&system, 1) == APP_OK);
  CHECK(played_count == 1); /* no queued answer yet */
  CHECK(system_keys(&system, 1u << 2, 400) == APP_OK); /* KEY2 = bin 1 */
  CHECK(played_count == 2 && played[1] == VOICE_CORRECT);
  CHECK(servo_calls == 1 && servo_bin == 1);
  CHECK(system.pending_audio == REWARD_MUSIC0);
  system_tick(&system, 2501); /* software state timeout cannot unlock music */
  CHECK(played_count == 2 && system.pending_audio == REWARD_MUSIC0);
  CHECK(system_audio_complete(&system, 1) == APP_OK);
  CHECK(played_count == 3 && played[2] == REWARD_MUSIC0);
  CHECK(system_audio_complete(&system, 1) == APP_OK);
  CHECK(played_count == 3); /* completion is not a duplicate reward */
  CHECK(system_keys(&system, 1u << 2, 410) == APP_OK); /* held key ignored */
  CHECK(played_count == 3);

  /* A failed correctness prompt must not start the reward track. */
  played_count = 0;
  CHECK(system_init(&system, ops) == APP_OK);
  CHECK(system_keys(&system, 1u, 0) == APP_OK);
  CHECK(system_keys(&system, 0, 1) == APP_OK);
  for (uint32_t frame = 1; frame <= 3; ++frame)
    CHECK(app_detect(&system.app, frame, 1, 1, 30000, frame * 100) == APP_OK);
  system_actions(&system);
  CHECK(system_audio_complete(&system, 1) == APP_OK);
  CHECK(system_keys(&system, 1u << 2, 400) == APP_OK);
  CHECK(played_count == 2 && played[1] == VOICE_CORRECT);
  CHECK(servo_calls == 2 && servo_bin == 1);
  CHECK(system_audio_complete(&system, 0) != APP_OK);
  CHECK(played_count == 2);
}

static void points_accumulate_and_saturate(void) {
  App app;
  uint32_t frame = 1;
  CHECK(app_init(&app) == APP_OK);
  CHECK(app_mode(&app, 1) == APP_OK);
  feed(&app, &frame, 1, 2, 30000);
  CHECK(app_answer(&app, app.session, 2, 1000) == APP_OK);
  app_tick(&app, 3001);
  feed(&app, &frame, 1, 1, 30000);
  CHECK(app_answer(&app, app.session, 1, 3100) == APP_OK);
  CHECK(app.points == 200);
  app_tick(&app, 5101);
  app.points = UINT32_MAX - 50;
  feed(&app, &frame, 1, 0, 30000);
  CHECK(app_answer(&app, app.session, 0, 5200) == APP_OK);
  CHECK(app.points == UINT32_MAX);
}

int main(void) {
  automatic_mode_only_announces_detection();
  quiz_answer_plays_reward_music_and_scores();
  invalid_and_repeated_detections_do_not_start_a_turn();
  quarter_confidence_survives_q15_conversion();
  quiz_timeout_announces_without_opening_hardware();
  button_answers_dispatch_voice_then_reward_music();
  points_accumulate_and_saturate();
  printf("SIMPLIFIED_APP_TESTS %u FAILURES %u\n", checks, failures);
  if (!failures) puts("TEST_PASS simplified_app");
  return failures ? 1 : 0;
}
