#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct BounceParams {
	float template_id = 0.0f;
	float child_speed = 0.0f;
	float accel = 0.0f;
	float angle = 0.0f;
	float sfx_id = -1.0f;
	float despawn = 1.0f;
};
struct BounceState { float age = 0.0f; float fired = 0.0f; };

static void bounce_emit_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<BounceState> state(p_state);
	*state = BounceState{};
}

static void bounce_emit_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<BounceState> state(p_state);
	const auto p = behavior::params_as<BounceParams>(p_params);
	state->age += p_dt;
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
	const bool hit_wall = p_ctx.position.x <= p_ctx.field_left
		|| p_ctx.position.x >= p_ctx.field_right
		|| p_ctx.position.y <= p_ctx.field_top;
	if (!hit_wall || state->fired > 0.0f) {
		return;
	}
	state->fired = 1.0f;
	Vector2 dir = (p_ctx.boss - p_ctx.position);
	if (dir.length_squared() < 1e-6f) {
		dir = Vector2(0, 1);
	}
	dir = dir.normalized().rotated(p.angle);
	const float child_speed = p.child_speed > 0.0f
		? p.child_speed : p_ctx.velocity->length();
	behavior::emit(p_out, (int32_t)p.template_id, p_ctx.position, dir * child_speed);
	behavior::play_sfx(p_out, (int32_t)p.sfx_id);
	if (p.despawn > 0.5f) {
		behavior::kill(p_out);
	}
}

void register_bounce_emit() {
	REGISTER_BEHAVIOR("bounce_emit", BounceState, BounceParams, &bounce_emit_init, &bounce_emit_tick);
}

} // namespace godot
