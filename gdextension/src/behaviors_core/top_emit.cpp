#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct TopParams {
	float accel = 0.0f;
	float template_id = 0.0f;
	float child_speed = 0.0f;
	float sfx_id = -1.0f;
	float angle = 3.14159265f;
};
struct TopState { float fired = 0.0f; };

static void top_emit_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<TopState> state(p_state);
	*state = TopState{};
}

static void top_emit_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<TopState> state(p_state);
	const auto p = behavior::params_as<TopParams>(p_params);
	if (state->fired > 0.0f) {
		return;
	}
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
	if (p_ctx.position.y > p_ctx.field_top) {
		return;
	}
	state->fired = 1.0f;
	const Vector2 dir(sin(p.angle), -cos(p.angle));
	const float speed = p.child_speed > 0.0f ? p.child_speed : p_ctx.velocity->length();
	behavior::emit(p_out, (int32_t)p.template_id, p_ctx.position, dir * speed);
	behavior::play_sfx(p_out, (int32_t)p.sfx_id);
	behavior::kill(p_out);
}

void register_top_emit() {
	REGISTER_BEHAVIOR("top_emit", TopState, TopParams, &top_emit_init, &top_emit_tick);
}

} // namespace godot
