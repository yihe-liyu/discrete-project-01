#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 沿 heading 加速；碰到上墙时 emit 指定模板，随后回收自己。
// params:
//   0 accel (px/s²)
//   1 template_id
//   2 child_speed (<=0 = 父弹当前速度)
//   3 sfx_id (-1 = 无)
//   4 world_angle（BulletLifecycle.world_heading 语义；PI = (0, 1)）
static void top_emit_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void top_emit_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	if (p_state[0] > 0.0f) {
		return;
	}
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p_params[0] * p_dt);
	if (p_ctx.position.y > p_ctx.field_top) {
		return;
	}
	p_state[0] = 1.0f;
	const float angle = p_params[4];
	const Vector2 dir(sin(angle), -cos(angle));
	const float speed = p_params[2] > 0.0f
		? p_params[2] : p_ctx.velocity->length();
	behavior::emit(p_out, (int32_t)p_params[1], p_ctx.position, dir * speed);
	behavior::play_sfx(p_out, (int32_t)p_params[3]);
	behavior::kill(p_out);
}

void register_top_emit() {
	static const NativeBehaviorDef def = {
		"top_emit", 1, 5, &top_emit_init, &top_emit_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
