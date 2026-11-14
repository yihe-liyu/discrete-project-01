#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct SplitParams {
	float accel = 0.0f;
	float duration = 0.0f;
	float template_a = 0.0f;
	float template_b = 0.0f;
	float chance = 0.0f;
	float child_speed = 0.0f;
	float spread = 0.0f;
};
struct SplitState { float age = 0.0f; float fired = 0.0f; };

static void split_after_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<SplitState> state(p_state);
	*state = SplitState{};
}

static void split_after_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<SplitState> state(p_state);
	const auto p = behavior::params_as<SplitParams>(p_params);
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
	state->age += p_dt;
	if (state->fired > 0.0f || state->age < p.duration) {
		return;
	}
	state->fired = 1.0f;
	const bool hit = behavior::random(p_ctx) < p.chance;
	const int template_id = (int32_t)(hit ? p.template_b : p.template_a);
	Vector2 dir;
	if (hit) {
		dir = p_ctx.player - p_ctx.position;
		dir = dir.length_squared() < 1e-6f ? behavior::heading(p_ctx) : dir.normalized();
	} else {
		dir = behavior::heading(p_ctx).rotated(p.spread);
	}
	const float speed = p.child_speed > 0.0f ? p.child_speed : p_ctx.velocity->length();
	behavior::emit(p_out, template_id, p_ctx.position, dir * speed);
	behavior::play_sfx(p_out, SFX_KIRA);
	behavior::kill(p_out);
}

void register_split_after() {
	REGISTER_BEHAVIOR("split_after", SplitState, SplitParams, &split_after_init, &split_after_tick);
}

} // namespace godot
