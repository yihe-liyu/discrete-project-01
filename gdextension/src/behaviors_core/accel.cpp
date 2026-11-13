#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// accel_world：params[0..1] = 世界坐标加速度（px/s²）。
// 与 lifecycle.accel_world 的逐帧语义一致；state 预留。
static void accel_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void accel_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	p_state[0] += p_dt;
	behavior::accelerate(p_ctx, Vector2(p_params[0], p_params[1]), p_dt);
}

void register_accel() {
	static const NativeBehaviorDef def = {
		"accel", 1, 2, &accel_init, &accel_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
