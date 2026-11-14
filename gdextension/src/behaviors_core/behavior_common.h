#ifndef BEHAVIOR_COMMON_H
#define BEHAVIOR_COMMON_H

#include "native_behavior.h"
#include <cstring>
#include <type_traits>

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

inline void clear_fx(NativeBehaviorOutcome &p_out) {
	p_out.clear_fx = true;
}

inline void rotate(NativeBehaviorContext &p_ctx, float p_radians) {
	if (p_ctx.velocity) {
		*p_ctx.velocity = p_ctx.velocity->rotated(p_radians);
	}
	if (p_ctx.heading_x && p_ctx.heading_y) {
		const Vector2 h = Vector2(*p_ctx.heading_x, *p_ctx.heading_y).rotated(p_radians);
		*p_ctx.heading_x = h.x;
		*p_ctx.heading_y = h.y;
	}
}

inline float random(NativeBehaviorContext &p_ctx) {
	return p_ctx.rng_float ? p_ctx.rng_float(p_ctx.rng_user) : 0.0f;
}

inline void play_sfx(NativeBehaviorOutcome &p_out, int p_sfx_id) {
	p_out.sfx_id = p_sfx_id;
}

// ── typed params / state ─────────────────────────────────────────
// behavior 仍然只有 float 数组；这里只做编译期布局检查 + memcpy 访问。
template <typename T>
T params_as(const float *p_raw) {
	static_assert(std::is_trivially_copyable<T>::value, "behavior params 必须 trivially copyable");
	static_assert(sizeof(T) % sizeof(float) == 0, "behavior params 大小必须是 float 的整数倍");
	T value{};
	std::memcpy(&value, p_raw, sizeof(T));
	return value;
}

template <typename T>
class State {
public:
	explicit State(float *p_raw) : _raw(p_raw) {
		static_assert(std::is_trivially_copyable<T>::value, "behavior state 必须 trivially copyable");
		static_assert(sizeof(T) % sizeof(float) == 0, "behavior state 大小必须是 float 的整数倍");
		std::memcpy(&_value, _raw, sizeof(T));
	}
	~State() { std::memcpy(_raw, &_value, sizeof(T)); }

	T &operator*() { return _value; }
	T *operator->() { return &_value; }

private:
	float *_raw;
	T _value{};
};

} // namespace behavior
} // namespace godot

// 注册一个 behavior：由 struct 大小推导 state/param 槽数。
#define REGISTER_BEHAVIOR(NAME, STATE_T, PARAM_T, INIT, TICK) \
	static_assert(sizeof(STATE_T) % sizeof(float) == 0, "STATE_T 必须是 float 的整数倍"); \
	static_assert(sizeof(PARAM_T) % sizeof(float) == 0, "PARAM_T 必须是 float 的整数倍"); \
	static_assert(sizeof(STATE_T) <= 8 * sizeof(float), "STATE_T 超过 8 个 float"); \
	static_assert(sizeof(PARAM_T) <= 8 * sizeof(float), "PARAM_T 超过 8 个 float"); \
	static const NativeBehaviorDef _behavior_def_##__LINE__ = { \
		NAME, (int)(sizeof(STATE_T) / sizeof(float)), (int)(sizeof(PARAM_T) / sizeof(float)), INIT, TICK \
	}; \
	NativeBehaviorRegistry::register_def(_behavior_def_##__LINE__)

#endif
