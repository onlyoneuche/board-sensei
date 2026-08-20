#ifndef BOARD_SENSEI_BRIDGE_H
#define BOARD_SENSEI_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct bs_bridge_engine bs_bridge_engine;
typedef struct bs_level_meter bs_level_meter;

typedef struct {
    uint8_t status;
    uint8_t expected_pitch;
    uint8_t received_pitch;
    uint8_t reserved;
    float response_time_ms;
} bs_validation_result;

bs_bridge_engine *bs_bridge_engine_create(uint8_t expected_pitch);
void bs_bridge_engine_destroy(bs_bridge_engine *engine);
void bs_bridge_engine_set_expected(bs_bridge_engine *engine, uint8_t expected_pitch);
bs_validation_result bs_bridge_engine_process_note(
    bs_bridge_engine *engine,
    uint8_t pitch,
    uint8_t velocity,
    uint8_t channel,
    uint64_t timestamp_ns
);
bool bs_bridge_engine_uses_rust(const bs_bridge_engine *engine);

bs_level_meter *bs_level_meter_create(void);
void bs_level_meter_destroy(bs_level_meter *meter);
void bs_level_meter_store(bs_level_meter *meter, float level);
float bs_level_meter_load(const bs_level_meter *meter);

#ifdef __cplusplus
}
#endif

#endif
