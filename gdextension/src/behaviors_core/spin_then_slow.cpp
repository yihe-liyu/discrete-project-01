#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct SpinParams {
	float spin = 0.0f;
	float duration = 0.0f;
	float reverse = 0.0f;
	float accel = 0.0f;
	float threshold = 0.0f;
	float clear = 1.0f;
	float despawn = 1.0f;
};
struct SpinState { float phase = 0.0f; float age = 0.0f; };

static void spin_then_slow_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<SpinState> state(p_state);
	*state = SpinState{};
}

static void spin_then_slow_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<SpinState> state(p_state);
	const auto p = behavior::params_as<SpinParams>(p_params);
	if (state->phase < 0.5f) {
		behavior::rotate(p_ctx, p.spin * p_dt);
		state->age += p_dt;
		if (state->age >= p.duration) {
			state->phase = 1.0f;
			state->age = 0.0f;
		}
		return;
	}
	if (state->phase > 1.5f) {
		return;
	}
	behavior::rotate(p_ctx, p.spin * p.reverse * p_dt);
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
	if (p_ctx.velocity->length() > p.threshold) {
		return;
	}
	state->phase = 2.0f;
	if (p.clear > 0.5f) {
		behavior::clear_fx(p_out);
	}
	if (p.despawn > 0.5f) {
		behavior::kill(p_out);
	}
}

void register_spin_then_slow() {
	REGISTER_BEHAVIOR("stage02.enemy02.spin_then_slow", SpinState, SpinParams, &spin_then_slow_init, &spin_then_slow_tick);
}

} // namespace godot
