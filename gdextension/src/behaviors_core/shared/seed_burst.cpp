#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 种子弹：沿 heading 线性减速到 0；结束时向四周 emit 一圈开花弹。
// params:
//   0 duration
//   1 initial_speed
//   2 template_id
//   3 count
//   4 child_speed
//   5 spread（整圈通常为 TAU）
struct SeedParams {
	float duration = 0.0f;
	float initial_speed = 0.0f;
	float template_id = -1.0f;
	float count = 0.0f;
	float child_speed = 0.0f;
	float spread = 0.0f;
};
struct SeedState { float age = 0.0f; float fired = 0.0f; };

static void seed_burst_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<SeedState> state(p_state);
	*state = SeedState{};
}

static void seed_burst_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::State<SeedState> state(p_state);
	const auto p = behavior::params_as<SeedParams>(p_params);
	state->age += p_dt;
	if (state->age < p.duration) {
		const float remain = 1.0f - state->age / p.duration;
		*p_ctx.velocity = behavior::heading(p_ctx) * (p.initial_speed * remain);
		return;
	}
	if (state->fired > 0.0f) {
		return;
	}
	state->fired = 1.0f;
	const int count = (int)p.count;
	const float step = count > 1 ? p.spread / count : 0.0f;
	for (int i = 0; i < count; ++i) {
		const Vector2 dir = behavior::heading(p_ctx).rotated(step * (float)i);
		behavior::emit(p_out, (int32_t)p.template_id, p_ctx.position, dir * p.child_speed);
	}
	behavior::play_sfx(p_out, SFX_SHOOT);
	behavior::kill(p_out);
}

void register_seed_burst() {
	REGISTER_BEHAVIOR("seed_burst", SeedState, SeedParams, &seed_burst_init, &seed_burst_tick);
}

} // namespace godot
