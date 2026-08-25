#include "BoardSenseiBridge.h"

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

typedef void *(*rust_engine_new_fn)(uint8_t);
typedef void (*rust_engine_free_fn)(void *);
typedef void (*rust_engine_set_expected_fn)(void *, uint8_t);
typedef void (*rust_engine_configure_prompt_fn)(void *, bs_prompt_config);
typedef void (*rust_engine_reset_fn)(void *);
typedef bs_validation_result (*rust_engine_process_note_fn)(void *, uint8_t, uint8_t, uint8_t, uint64_t);

struct bs_bridge_engine {
    void *library;
    void *rust_engine;
    bs_prompt_config prompt;
    bool held[128];
    bool attacked[BS_MAX_PROMPT_PITCHES];
    uint64_t attack_times[BS_MAX_PROMPT_PITCHES];
    rust_engine_free_fn rust_free;
    rust_engine_set_expected_fn rust_set_expected;
    rust_engine_configure_prompt_fn rust_configure_prompt;
    rust_engine_reset_fn rust_reset;
    rust_engine_process_note_fn rust_process_note;
};

struct bs_level_meter {
    atomic_uint bits;
};

static void load_symbol(void *library, const char *name, void *destination, size_t size) {
    void *symbol = dlsym(library, name);
    if (symbol != NULL) {
        memcpy(destination, &symbol, size);
    }
}

static void clear_prompt_attacks(bs_bridge_engine *engine) {
    memset(engine->attacked, 0, sizeof(engine->attacked));
    memset(engine->attack_times, 0, sizeof(engine->attack_times));
}

static int expected_index(const bs_bridge_engine *engine, uint8_t pitch) {
    for (uint8_t index = 0; index < engine->prompt.pitch_count; index++) {
        if (engine->prompt.pitches[index] == pitch) {
            return index;
        }
    }
    return -1;
}

static bs_validation_result result_for(
    const bs_bridge_engine *engine,
    uint8_t status,
    uint8_t received_pitch
) {
    uint8_t expected = engine->prompt.pitch_count > 0 ? engine->prompt.pitches[0] : 0;
    return (bs_validation_result){status, expected, received_pitch, 0, 0};
}

bs_bridge_engine *bs_bridge_engine_create(uint8_t expected_pitch) {
    bs_bridge_engine *engine = calloc(1, sizeof(bs_bridge_engine));
    if (engine == NULL) {
        return NULL;
    }

    engine->prompt.mode = BS_PROMPT_SINGLE_NOTE;
    engine->prompt.pitch_count = 1;
    engine->prompt.pitches[0] = expected_pitch;
    const char *configured_path = getenv("BOARD_SENSEI_RUST_LIB");
    const char *path = configured_path != NULL
        ? configured_path
        : "rust/target/release/libboard_sensei_music.dylib";

    engine->library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (engine->library == NULL) {
        return engine;
    }

    rust_engine_new_fn rust_new = NULL;
    load_symbol(engine->library, "bs_engine_new", &rust_new, sizeof(rust_new));
    load_symbol(engine->library, "bs_engine_free", &engine->rust_free, sizeof(engine->rust_free));
    load_symbol(
        engine->library,
        "bs_engine_set_expected",
        &engine->rust_set_expected,
        sizeof(engine->rust_set_expected)
    );
    load_symbol(
        engine->library,
        "bs_engine_configure_prompt",
        &engine->rust_configure_prompt,
        sizeof(engine->rust_configure_prompt)
    );
    load_symbol(engine->library, "bs_engine_reset", &engine->rust_reset, sizeof(engine->rust_reset));
    load_symbol(
        engine->library,
        "bs_engine_process_note",
        &engine->rust_process_note,
        sizeof(engine->rust_process_note)
    );

    if (rust_new == NULL || engine->rust_free == NULL
        || engine->rust_set_expected == NULL || engine->rust_configure_prompt == NULL
        || engine->rust_reset == NULL || engine->rust_process_note == NULL) {
        dlclose(engine->library);
        engine->library = NULL;
        engine->rust_free = NULL;
        engine->rust_set_expected = NULL;
        engine->rust_configure_prompt = NULL;
        engine->rust_reset = NULL;
        engine->rust_process_note = NULL;
        return engine;
    }

    engine->rust_engine = rust_new(expected_pitch);
    if (engine->rust_engine == NULL) {
        dlclose(engine->library);
        engine->library = NULL;
    }
    return engine;
}

void bs_bridge_engine_destroy(bs_bridge_engine *engine) {
    if (engine == NULL) {
        return;
    }
    if (engine->rust_engine != NULL && engine->rust_free != NULL) {
        engine->rust_free(engine->rust_engine);
    }
    if (engine->library != NULL) {
        dlclose(engine->library);
    }
    free(engine);
}

void bs_bridge_engine_set_expected(bs_bridge_engine *engine, uint8_t expected_pitch) {
    if (engine == NULL) {
        return;
    }
    engine->prompt = (bs_prompt_config){0};
    engine->prompt.mode = BS_PROMPT_SINGLE_NOTE;
    engine->prompt.pitch_count = 1;
    engine->prompt.pitches[0] = expected_pitch;
    clear_prompt_attacks(engine);
    if (engine->rust_engine != NULL && engine->rust_set_expected != NULL) {
        engine->rust_set_expected(engine->rust_engine, expected_pitch);
    }
}

bool bs_bridge_engine_configure_prompt(
    bs_bridge_engine *engine,
    uint8_t mode,
    const uint8_t *pitches,
    uint8_t pitch_count,
    uint16_t spread_ms
) {
    if (engine == NULL || pitches == NULL || pitch_count == 0
        || pitch_count > BS_MAX_PROMPT_PITCHES || mode > BS_PROMPT_FRESH_ATTACK_SET) {
        return false;
    }
    for (uint8_t index = 0; index < pitch_count; index++) {
        if (pitches[index] > 127) {
            return false;
        }
    }

    engine->prompt = (bs_prompt_config){0};
    engine->prompt.mode = mode;
    engine->prompt.pitch_count = pitch_count;
    engine->prompt.spread_ms = spread_ms;
    memcpy(engine->prompt.pitches, pitches, pitch_count);
    clear_prompt_attacks(engine);
    if (engine->rust_engine != NULL && engine->rust_configure_prompt != NULL) {
        engine->rust_configure_prompt(engine->rust_engine, engine->prompt);
    }
    return true;
}

void bs_bridge_engine_reset(bs_bridge_engine *engine) {
    if (engine == NULL) {
        return;
    }
    memset(engine->held, 0, sizeof(engine->held));
    clear_prompt_attacks(engine);
    if (engine->rust_engine != NULL && engine->rust_reset != NULL) {
        engine->rust_reset(engine->rust_engine);
    }
}

bs_validation_result bs_bridge_engine_process_note(
    bs_bridge_engine *engine,
    uint8_t pitch,
    uint8_t velocity,
    uint8_t channel,
    uint64_t timestamp_ns
) {
    if (engine == NULL) {
        return (bs_validation_result){255, 0, pitch, 0, 0};
    }
    if (pitch > 127) {
        return result_for(engine, 255, pitch);
    }
    if (engine->rust_engine != NULL && engine->rust_process_note != NULL) {
        return engine->rust_process_note(engine->rust_engine, pitch, velocity, channel, timestamp_ns);
    }
    if (velocity == 0) {
        engine->held[pitch] = false;
        return result_for(engine, 2, pitch);
    }

    engine->held[pitch] = true;
    int index = expected_index(engine, pitch);
    if (index < 0) {
        clear_prompt_attacks(engine);
        return result_for(engine, 1, pitch);
    }

    if (engine->prompt.mode == BS_PROMPT_SINGLE_NOTE) {
        return result_for(engine, 0, pitch);
    }

    if (engine->prompt.mode == BS_PROMPT_EXACT_HELD_SET) {
        for (uint16_t note = 0; note < 128; note++) {
            bool expected = expected_index(engine, (uint8_t)note) >= 0;
            if (engine->held[note] != expected) {
                return result_for(engine, 3, pitch);
            }
        }
        return result_for(engine, 0, pitch);
    }

    uint64_t spread_ns = (uint64_t)engine->prompt.spread_ms * 1000000;
    for (uint8_t candidate = 0; candidate < engine->prompt.pitch_count; candidate++) {
        if (engine->attacked[candidate] && timestamp_ns > engine->attack_times[candidate]
            && timestamp_ns - engine->attack_times[candidate] > spread_ns) {
            engine->attacked[candidate] = false;
        }
    }
    engine->attacked[index] = true;
    engine->attack_times[index] = timestamp_ns;

    uint64_t earliest = UINT64_MAX;
    uint64_t latest = 0;
    for (uint8_t candidate = 0; candidate < engine->prompt.pitch_count; candidate++) {
        if (!engine->attacked[candidate]) {
            return result_for(engine, 3, pitch);
        }
        if (engine->attack_times[candidate] < earliest) earliest = engine->attack_times[candidate];
        if (engine->attack_times[candidate] > latest) latest = engine->attack_times[candidate];
    }
    if (latest - earliest <= spread_ns) {
        clear_prompt_attacks(engine);
        return result_for(engine, 0, pitch);
    }
    clear_prompt_attacks(engine);
    return result_for(engine, 3, pitch);
}

bool bs_bridge_engine_uses_rust(const bs_bridge_engine *engine) {
    return engine != NULL && engine->rust_engine != NULL;
}

bs_level_meter *bs_level_meter_create(void) {
    bs_level_meter *meter = calloc(1, sizeof(bs_level_meter));
    if (meter != NULL) {
        atomic_init(&meter->bits, 0);
    }
    return meter;
}

void bs_level_meter_destroy(bs_level_meter *meter) {
    free(meter);
}

void bs_level_meter_store(bs_level_meter *meter, float level) {
    if (meter == NULL) {
        return;
    }
    unsigned int bits = 0;
    memcpy(&bits, &level, sizeof(level));
    atomic_store_explicit(&meter->bits, bits, memory_order_relaxed);
}

float bs_level_meter_load(const bs_level_meter *meter) {
    if (meter == NULL) {
        return 0.0f;
    }
    unsigned int bits = atomic_load_explicit(&meter->bits, memory_order_relaxed);
    float level = 0.0f;
    memcpy(&level, &bits, sizeof(level));
    return level;
}
