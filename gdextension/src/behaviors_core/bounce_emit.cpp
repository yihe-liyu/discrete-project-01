#include "native_behavior.h"

namespace godot {

// 撞左/右/上墙 → 请求发射模板，然后请求回收自己。
// params[0] = EmitTemplate.numeric_id
// params[1] = 子弹出速度
static void bounce_emit_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void bounce_emit_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	p_state[0] += p_dt;
	const bool hit_wall = p_ctx.position.x <= p_ctx.field_left
		|| p_ctx.position.x >= p_ctx.field_right
		|| p_ctx.position.y <= p_ctx.field_top;
	if (!hit_wall) {
		return;
	}
	if (p_out.emit_count < 4) {
		NativeBehaviorEmit &e = p_out.emits[p_out.emit_count++];
		e.template_id = (int32_t)p_params[0];
		e.position = p_ctx.position;
		Vector2 dir = (p_ctx.boss - p_ctx.position);
		if (dir.length_squared() < 1e-6f) {
			dir = Vector2(0, 1);
		}
		e.velocity = dir.normalized() * p_params[1];
		e.color = p_ctx.color ? *p_ctx.color : Color(1, 1, 1, 1);
	}
	p_out.despawn = true;
}

void register_bounce_emit() {
	static const NativeBehaviorDef def = {
		"bounce_emit", 1, 2, &bounce_emit_init, &bounce_emit_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
