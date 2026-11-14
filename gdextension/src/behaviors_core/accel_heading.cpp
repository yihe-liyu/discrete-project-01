#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 沿自身 heading 加速；params[0] = 加速度（px/s²）。
static void accel_heading_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void accel_heading_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	p_state[0] += p_dt;
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p_params[0] * p_dt);
}

void register_accel_heading() {
	static const NativeBehaviorDef def = {
		"accel_heading", 1, 1, &accel_heading_init, &accel_heading_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
