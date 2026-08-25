#ifndef BOARD_SENSEI_MUSIC_H
#define BOARD_SENSEI_MUSIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint8_t status;
    uint8_t expected_pitch;
    uint8_t received_pitch;
    uint8_t reserved;
    float response_time_ms;
} bs_validation_result;

#define BS_MAX_PROMPT_PITCHES 16

typedef struct {
    uint8_t mode;
    uint8_t pitch_count;
    uint16_t spread_ms;
    uint8_t pitches[BS_MAX_PROMPT_PITCHES];
} bs_prompt_config;

void *bs_engine_new(uint8_t expected_pitch);
void bs_engine_free(void *engine);
void bs_engine_set_expected(void *engine, uint8_t expected_pitch);
void bs_engine_configure_prompt(void *engine, bs_prompt_config config);
void bs_engine_reset(void *engine);
bs_validation_result bs_engine_process_note(
    void *engine,
    uint8_t pitch,
    uint8_t velocity,
    uint8_t channel,
    uint64_t timestamp_ns
);

#ifdef __cplusplus
}
#endif

#endif
