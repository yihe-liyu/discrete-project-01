#include "native_behavior.h"
#include "behavior_common.h"
#include <algorithm>

namespace godot {

struct HomingState { float age = 0.0f; };
struct HomingParams {
	float speed = 0.0f;
	float turn = 0.0f;
	float target_mode = 0.0f;   // 0 = player，1 = nearest enemy
	float speed_end = 0.0f;
	float speed_ramp = 0.0f;
	float turn_ramp = 0.0f;
	float dist_weight = 0.0f;
	float steer_until = 0.0f;
};

static void homing_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<HomingState> state(p_state);
	*state = HomingState{};
}

static bool nearest_enemy(const NativeBehaviorContext &p_ctx, Vector2 &r_out) {
	if (p_ctx.enemies == nullptr) {
		return false;
	}
	bool found = false;
	float best = 0.0f;
	for (int i = 0; i < p_ctx.enemies->size(); ++i) {
		const Vector2 p = (*p_ctx.enemies)[i];
		const float d = p_ctx.position.distance_squared_to(p);
		if (!found || d < best) {
			found = true;
			best = d;
			r_out = p;
		}
	}
	return found;
}

static void homing_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<HomingState> state(p_state);
	const auto p = behavior::params_as<HomingParams>(p_params);
	state->age += p_dt;

	// 旧两参数路径：保持既有 homing 语义（朝目标速度向量收敛）。
	if (p.speed_end == 0.0f && p.speed_ramp == 0.0f && p.turn_ramp == 0.0f
			&& p.dist_weight == 0.0f && p.steer_until == 0.0f && p.target_mode == 0.0f) {
		const Vector2 to_target = p_ctx.player - p_ctx.position;
		if (to_target.length_squared() < 1e-6f) {
			return;
		}
		const Vector2 desired = to_target.normalized() * p.speed;
		behavior::steer_toward(p_ctx, desired, p.turn * p_dt);
		const Vector2 dir = p_ctx.velocity->normalized();
		if (dir.length_squared() > 1e-6f) {
			*p_ctx.heading_x = dir.x;
			*p_ctx.heading_y = dir.y;
		}
		return;
	}

	Vector2 target;
	bool has_target = false;
	if (p.target_mode > 0.5f) {
		has_target = nearest_enemy(p_ctx, target);
	} else {
		target = p_ctx.player;
		has_target = true;
	}

	Vector2 dir = p_ctx.velocity->normalized();
	if (dir.length_squared() < 1e-6f) {
		dir = behavior::heading(p_ctx);
	}

	const bool can_steer = p.steer_until <= 0.0f || state->age <= p.steer_until;
	if (has_target && can_steer) {
		const Vector2 diff = target - p_ctx.position;
		const float dist = std::max(diff.length(), 1.0f);
		const float tf = p.turn_ramp <= 0.0f ? 1.0f : std::min(std::max(state->age / p.turn_ramp, 0.0f), 1.0f);
		const float dw = p.dist_weight > 0.0f ? 1.0f + p.dist_weight / (dist + p.dist_weight) : 1.0f;
		const float max_turn = p.turn * tf * dw * p_dt;
		dir = dir.rotated(std::min(std::max(dir.angle_to(diff / dist), -max_turn), max_turn));
	}

	float speed = p_ctx.velocity->length();
	if (p.speed_end > 0.0f && p.speed_ramp > 0.0f) {
		const float f = std::min(std::max(state->age / p.speed_ramp, 0.0f), 1.0f);
		speed = p.speed + (p.speed_end - p.speed) * f;
	}
	*p_ctx.velocity = dir * speed;
	if (p_ctx.heading_x != nullptr && p_ctx.heading_y != nullptr) {
		*p_ctx.heading_x = dir.x;
		*p_ctx.heading_y = dir.y;
	}
}

void register_homing() {
	REGISTER_BEHAVIOR("homing", HomingState, HomingParams, &homing_init, &homing_tick);
}

} // namespace godot
