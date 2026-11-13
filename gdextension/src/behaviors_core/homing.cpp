#include "native_behavior.h"

namespace godot {

// homing：params[0] = 速度，params[1] = 每秒转向像素。
// state[0] = age（预留，后续可做延迟启动）。
static void homing_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void homing_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	p_state[0] += p_dt;
	const Vector2 target = p_ctx.player;
	Vector2 to_target = target - p_ctx.position;
	if (to_target.length_squared() < 1e-6f) {
		return;
	}
	const Vector2 desired = to_target.normalized() * p_params[0];
	Vector2 vel = *p_ctx.velocity;
	const Vector2 delta = desired - vel;
	const float step = p_params[1] * p_dt;
	if (step <= 0.0f || delta.length() <= step) {
		vel = desired;
	} else {
		vel += delta.normalized() * step;
	}
	*p_ctx.velocity = vel;
	const Vector2 dir = vel.normalized();
	if (dir.length_squared() > 1e-6f) {
		*p_ctx.heading_x = dir.x;
		*p_ctx.heading_y = dir.y;
	}
}

void register_homing() {
	static const NativeBehaviorDef def = {
		"homing", 1, 2, &homing_init, &homing_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
