#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct AccelState { float age = 0.0f; };
struct AccelParams { float ax = 0.0f; float ay = 0.0f; };

static void accel_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<AccelState> state(p_state);
	*state = AccelState{};
}

static void accel_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<AccelState> state(p_state);
	const auto p = behavior::params_as<AccelParams>(p_params);
	state->age += p_dt;
	behavior::accelerate(p_ctx, Vector2(p.ax, p.ay), p_dt);
}

void register_accel() {
	REGISTER_BEHAVIOR("accel", AccelState, AccelParams, &accel_init, &accel_tick);
}

} // namespace godot
