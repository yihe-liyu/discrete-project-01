#ifndef BEHAVIOR_COMMON_H
#define BEHAVIOR_COMMON_H

#include "native_behavior.h"

namespace godot {
namespace behavior {

// 常用移动/动作 helper：只做边界内的机械操作，不隐藏 behavior 逻辑。
inline Vector2 heading(const NativeBehaviorContext &p_ctx) {
	const Vector2 h(p_ctx.heading_x ? *p_ctx.heading_x : 0.0f,
		p_ctx.heading_y ? *p_ctx.heading_y : 1.0f);
	return h.length_squared() > 1e-6f ? h.normalized() : Vector2(0, 1);
}

inline void accelerate(NativeBehaviorContext &p_ctx, const Vector2 &p_accel, float p_dt) {
	if (p_ctx.velocity) {
		*p_ctx.velocity += p_accel * p_dt;
	}
}

// 朝 desired_velocity 靠近，单 tick 最多转 max_delta 的像素速度。
inline void steer_toward(NativeBehaviorContext &p_ctx, const Vector2 &p_desired, float p_max_delta) {
	if (p_ctx.velocity == nullptr) {
		return;
	}
	const Vector2 d = p_desired - *p_ctx.velocity;
	if (p_max_delta <= 0.0f || d.length() <= p_max_delta) {
		*p_ctx.velocity = p_desired;
	} else {
		*p_ctx.velocity += d.normalized() * p_max_delta;
	}
}

inline bool emit(NativeBehaviorOutcome &p_out, int p_template_id, const Vector2 &p_pos,
		const Vector2 &p_vel, const Color &p_color = Color(1, 1, 1, 1)) {
	if (p_out.emit_count >= 4) {
		return false;
	}
	NativeBehaviorEmit &e = p_out.emits[p_out.emit_count++];
	e.template_id = p_template_id;
	e.position = p_pos;
	e.velocity = p_vel;
	e.color = p_color;
	return true;
}

inline void kill(NativeBehaviorOutcome &p_out) {
	p_out.despawn = true;
}

inline float random(NativeBehaviorContext &p_ctx) {
	return p_ctx.rng_float ? p_ctx.rng_float(p_ctx.rng_user) : 0.0f;
}

inline void play_sfx(NativeBehaviorOutcome &p_out, int p_sfx_id) {
	p_out.sfx_id = p_sfx_id;
}

} // namespace behavior
} // namespace godot

#endif
