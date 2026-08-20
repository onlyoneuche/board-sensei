#include "BoardSenseiBridge.h"

#include <dlfcn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

typedef void *(*rust_engine_new_fn)(uint8_t);
typedef void (*rust_engine_free_fn)(void *);
typedef void (*rust_engine_set_expected_fn)(void *, uint8_t);
typedef bs_validation_result (*rust_engine_process_note_fn)(void *, uint8_t, uint8_t, uint8_t, uint64_t);

struct bs_bridge_engine {
    void *library;
    void *rust_engine;
    uint8_t expected_pitch;
    rust_engine_free_fn rust_free;
    rust_engine_set_expected_fn rust_set_expected;
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

bs_bridge_engine *bs_bridge_engine_create(uint8_t expected_pitch) {
    bs_bridge_engine *engine = calloc(1, sizeof(bs_bridge_engine));
    if (engine == NULL) {
        return NULL;
    }

    engine->expected_pitch = expected_pitch;
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
        "bs_engine_process_note",
        &engine->rust_process_note,
        sizeof(engine->rust_process_note)
    );

    if (rust_new == NULL || engine->rust_free == NULL
        || engine->rust_set_expected == NULL || engine->rust_process_note == NULL) {
        dlclose(engine->library);
        engine->library = NULL;
        engine->rust_free = NULL;
        engine->rust_set_expected = NULL;
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
    engine->expected_pitch = expected_pitch;
    if (engine->rust_engine != NULL && engine->rust_set_expected != NULL) {
        engine->rust_set_expected(engine->rust_engine, expected_pitch);
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
    if (engine->rust_engine != NULL && engine->rust_process_note != NULL) {
        return engine->rust_process_note(engine->rust_engine, pitch, velocity, channel, timestamp_ns);
    }
    if (velocity == 0) {
        return (bs_validation_result){2, engine->expected_pitch, pitch, 0, 0};
    }
    uint8_t status = pitch == engine->expected_pitch ? 0 : 1;
    return (bs_validation_result){status, engine->expected_pitch, pitch, 0, 0};
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
