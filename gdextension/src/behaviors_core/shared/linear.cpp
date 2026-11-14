#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct LinearState { float age = 0.0f; };
struct LinearParams { float unused = 0.0f; };

static void linear_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<LinearState> state(p_state);
	*state = LinearState{};
}

static void linear_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_ctx;
	(void)p_out;
	behavior::State<LinearState> state(p_state);
	state->age += p_dt;
}

void register_linear() {
	REGISTER_BEHAVIOR("linear", LinearState, LinearParams, &linear_init, &linear_tick);
}

} // namespace godot
