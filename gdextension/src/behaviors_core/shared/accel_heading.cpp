#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct AccelHeadingState { float age = 0.0f; };
struct AccelHeadingParams {
	float accel = 0.0f;
	float lifetime = 0.0f;
	float clear = 0.0f;
};

static void accel_heading_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<AccelHeadingState> state(p_state);
	*state = AccelHeadingState{};
}

static void accel_heading_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<AccelHeadingState> state(p_state);
	const auto p = behavior::params_as<AccelHeadingParams>(p_params);
	state->age += p_dt;
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
	if (p.lifetime > 0.0f && state->age >= p.lifetime) {
		if (p.clear > 0.5f) {
			behavior::clear_fx(p_out);
		}
		behavior::kill(p_out);
	}
}

void register_accel_heading() {
	REGISTER_BEHAVIOR("accel_heading", AccelHeadingState, AccelHeadingParams, &accel_heading_init, &accel_heading_tick);
}

} // namespace godot
