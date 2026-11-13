#include "native_behavior.h"

namespace godot {

// 最小 behavior pack：直线运动。内核不解释任何运动逻辑；
// linear 只证明 registry / 行字段 / tick 调度链路，tick 故意为空。
static void linear_init(float *p_state, const float *p_params) {
	(void)p_state;
	(void)p_params;
}

static void linear_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_state;
	(void)p_params;
	(void)p_ctx;
	(void)p_out;
	(void)p_dt;
}

void register_linear() {
	static const NativeBehaviorDef def = {
		"linear", 0, 0, &linear_init, &linear_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
