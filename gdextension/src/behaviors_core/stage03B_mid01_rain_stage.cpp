#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct RainParams {
	float gravity = 0.0f;
	float threshold_y = 0.0f;
	float template_id = -1.0f;
	float offset_y = 0.0f;
	float clear = 1.0f;
	float despawn = 1.0f;
};
struct RainState { float initialized = 0.0f; float age = 0.0f; };

static void rain_stage_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<RainState> state(p_state);
	*state = RainState{};
}

static void rain_stage_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<RainState> state(p_state);
	const auto p = behavior::params_as<RainParams>(p_params);
	if (state->initialized < 0.5f) {
		state->initialized = 1.0f;
		if (p_ctx.position_out) {
			p_ctx.position_out->y += p.offset_y;
			p_ctx.position.y += p.offset_y;
		}
	}
	state->age += p_dt;
	behavior::accelerate(p_ctx, Vector2(0, p.gravity), p_dt);
	if (p_ctx.position.y < p.threshold_y) {
		return;
	}
	if (p.template_id >= 0.0f) {
		behavior::emit(p_out, (int32_t)p.template_id, p_ctx.position, *p_ctx.velocity);
	}
	if (p.clear > 0.5f) {
		behavior::clear_fx(p_out);
	}
	if (p.despawn > 0.5f) {
		behavior::kill(p_out);
	}
}

void register_rain_stage() {
	REGISTER_BEHAVIOR("stage03B.mid01.rain_stage", RainState, RainParams, &rain_stage_init, &rain_stage_tick);
}

} // namespace godot
