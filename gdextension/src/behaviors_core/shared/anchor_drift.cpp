#include "native_behavior.h"
#include "behavior_common.h"
#include <cmath>

namespace godot {

struct AnchorDriftParams {
	float angle = 0.0f;    // 0 = 向上；与位置无关
	float speed = 0.0f;    // 沿角度的漂移速度（px/s）
	float initial = 0.0f;  // 首帧位移（避免出生瞬间跳一帧）
	float render = 1.0f;   // >0.5 = 写独立渲染朝向
};
struct AnchorDriftState { float drift = 0.0f; float started = 0.0f; };

static void anchor_drift_init(float *p_state, const float *p_params) {
	const auto p = behavior::params_as<AnchorDriftParams>(p_params);
	behavior::State<AnchorDriftState> state(p_state);
	*state = AnchorDriftState{};
	state->drift = p.initial;
}

static void anchor_drift_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<AnchorDriftState> state(p_state);
	const auto p = behavior::params_as<AnchorDriftParams>(p_params);
	if (!p_ctx.has_anchor) {
		return;
	}
	if (state->started > 0.5f) {
		state->drift += p.speed * p_dt;
	} else {
		state->started = 1.0f;
	}
	const Vector2 dir(std::sin(p.angle), -std::cos(p.angle));
	if (p_ctx.position_out != nullptr) {
		*p_ctx.position_out = p_ctx.anchor + dir * state->drift;
	}
	if (p.render > 0.5f && p_ctx.render_rot != nullptr) {
		*p_ctx.render_rot = std::atan2(dir.y, dir.x);
	}
}

void register_anchor_drift() {
	REGISTER_BEHAVIOR("anchor_drift", AnchorDriftState, AnchorDriftParams, &anchor_drift_init, &anchor_drift_tick);
}

} // namespace godot
