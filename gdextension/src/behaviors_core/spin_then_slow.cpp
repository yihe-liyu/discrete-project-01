#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 先按角速度旋转 duration 秒，再按 reverse_factor 反向旋转并沿 heading 减速；
// 速度 <= threshold 时可选 clear_fx / despawn。
// params:
//   0 spin (rad/s)
//   1 duration (s)
//   2 reverse_factor
//   3 accel (px/s²)
//   4 speed_threshold
//   5 clear_fx (0/1)
//   6 despawn (0/1)
static void spin_then_slow_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;   // phase
	p_state[1] = 0.0f;   // age
}

static void spin_then_slow_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	const int phase = (int)p_state[0];
	if (phase == 0) {
		behavior::rotate(p_ctx, p_params[0] * p_dt);
		p_state[1] += p_dt;
		if (p_state[1] >= p_params[1]) {
			p_state[0] = 1.0f;
			p_state[1] = 0.0f;
		}
		return;
	}
	if (phase != 1) {
		return;
	}
	behavior::rotate(p_ctx, p_params[0] * p_params[2] * p_dt);
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p_params[3] * p_dt);
	if (p_ctx.velocity->length() > p_params[4]) {
		return;
	}
	p_state[0] = 2.0f;
	if (p_params[5] > 0.5f) {
		behavior::clear_fx(p_out);
	}
	if (p_params[6] > 0.5f) {
		behavior::kill(p_out);
	}
}

void register_spin_then_slow() {
	static const NativeBehaviorDef def = {
		"spin_then_slow", 2, 7, &spin_then_slow_init, &spin_then_slow_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
