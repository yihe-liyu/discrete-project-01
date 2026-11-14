#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 持续旋转渲染朝向，并沿 heading 加速。params[0]=spin(rad/s)，params[1]=accel。
struct SpinAccelParams { float spin = 0.0f; float accel = 0.0f; };
struct SpinAccelState { float age = 0.0f; };

static void spin_accel_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<SpinAccelState> state(p_state);
	*state = SpinAccelState{};
}

static void spin_accel_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_out;
	behavior::State<SpinAccelState> state(p_state);
	const auto p = behavior::params_as<SpinAccelParams>(p_params);
	state->age += p_dt;
	if (p_ctx.render_rot) {
		*p_ctx.render_rot += p.spin * p_dt;
	}
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.accel * p_dt);
}

void register_spin_accel() {
	REGISTER_BEHAVIOR("spin_accel", SpinAccelState, SpinAccelParams, &spin_accel_init, &spin_accel_tick);
}

} // namespace godot
