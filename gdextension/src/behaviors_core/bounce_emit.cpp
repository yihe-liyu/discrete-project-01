#include "native_behavior.h"

namespace godot {

// 撞左/右/上墙 → 请求发射模板，然后请求回收自己。
// params[0] = EmitTemplate.numeric_id
// params[1] = 子弹出速度（<=0 = 沿用父弹当前速度）
// params[2] = 沿自身朝向的加速度（px/s²）
// params[3] = 子弹出方向相对“朝向 Boss”的附加角（弧度）
// params[4] = 撞墙音效下标（-1 = 无）
static void bounce_emit_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
}

static void bounce_emit_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	p_state[0] += p_dt;
	const Vector2 heading(p_ctx.heading_x ? *p_ctx.heading_x : 0.0f,
		p_ctx.heading_y ? *p_ctx.heading_y : 1.0f);
	*p_ctx.velocity += heading * p_params[2] * p_dt;
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
		dir = dir.normalized().rotated(p_params[3]);
		const float child_speed = p_params[1] > 0.0f
			? p_params[1] : p_ctx.velocity->length();
		e.velocity = dir * child_speed;
		e.color = Color(1, 1, 1, 1);
	}
	p_out.sfx_id = (int32_t)p_params[4];
	p_out.despawn = true;
}

void register_bounce_emit() {
	static const NativeBehaviorDef def = {
		"bounce_emit", 1, 5, &bounce_emit_init, &bounce_emit_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
