#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

struct HomingState { float age = 0.0f; };
struct HomingParams { float speed = 0.0f; float turn = 0.0f; };

static void homing_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<HomingState> state(p_state);
	*state = HomingState{};
}

static void homing_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<HomingState> state(p_state);
	const auto p = behavior::params_as<HomingParams>(p_params);
	state->age += p_dt;
	Vector2 to_target = p_ctx.player - p_ctx.position;
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
}

void register_homing() {
	REGISTER_BEHAVIOR("homing", HomingState, HomingParams, &homing_init, &homing_tick);
}

} // namespace godot
