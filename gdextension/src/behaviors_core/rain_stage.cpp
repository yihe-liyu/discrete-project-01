#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 雨弹阶段：首次 tick 可选上移 offset，之后受重力；到 y 阈值时 emit 下一阶段。
// params:
//   0 gravity
//   1 threshold_y
//   2 template_id (-1 = 不 emit)
//   3 offset_y (首次 tick 应用)
//   4 clear_fx (0/1)
//   5 despawn (0/1)
static void rain_stage_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;   // initialized
	p_state[1] = 0.0f;   // age
}

static void rain_stage_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	if (p_state[0] < 0.5f) {
		p_state[0] = 1.0f;
		if (p_ctx.position_out) {
			p_ctx.position_out->y += p_params[3];
			p_ctx.position.y += p_params[3];
		}
	}
	p_state[1] += p_dt;
	behavior::accelerate(p_ctx, Vector2(0, p_params[0]), p_dt);
	if (p_ctx.position.y < p_params[1]) {
		return;
	}
	if (p_params[2] >= 0.0f) {
		behavior::emit(p_out, (int32_t)p_params[2], p_ctx.position, *p_ctx.velocity);
	}
	if (p_params[4] > 0.5f) {
		behavior::clear_fx(p_out);
	}
	if (p_params[5] > 0.5f) {
		behavior::kill(p_out);
	}
}

void register_rain_stage() {
	static const NativeBehaviorDef def = {
		"rain_stage", 2, 6, &rain_stage_init, &rain_stage_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
