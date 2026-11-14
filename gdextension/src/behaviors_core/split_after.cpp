#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 沿 heading 减速；到 duration 时按概率选两个子弹出模板之一，然后回收自己。
// params:
//   0 accel（px/s²，通常为负）
//   1 duration（秒）
//   2 template_a（未命中）
//   3 template_b（命中）
//   4 chance（0..1）
//   5 child_speed（<=0 = 沿用父弹当前速度）
//   6 sfx_id（-1 = 无）
//   7 spread（未命中时相对 heading 的附加角）
static void split_after_init(float *p_state, const float *p_params) {
	(void)p_params;
	p_state[0] = 0.0f;
	p_state[1] = 0.0f;
}

static void split_after_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	behavior::accelerate(p_ctx, behavior::heading(p_ctx), p_params[0] * p_dt);
	p_state[0] += p_dt;
	if (p_state[1] > 0.0f || p_state[0] < p_params[1]) {
		return;
	}
	p_state[1] = 1.0f;

	const bool hit = behavior::random(p_ctx) < p_params[4];
	const int template_id = (int32_t)(hit ? p_params[3] : p_params[2]);
	Vector2 dir;
	if (hit) {
		dir = p_ctx.player - p_ctx.position;
		if (dir.length_squared() < 1e-6f) {
			dir = behavior::heading(p_ctx);
		} else {
			dir = dir.normalized();
		}
	} else {
		dir = behavior::heading(p_ctx).rotated(p_params[7]);
	}
	const float speed = p_params[5] > 0.0f
		? p_params[5] : p_ctx.velocity->length();
	behavior::emit(p_out, template_id, p_ctx.position, dir * speed);
	behavior::play_sfx(p_out, (int32_t)p_params[6]);
	behavior::kill(p_out);
}

void register_split_after() {
	static const NativeBehaviorDef def = {
		"split_after", 2, 8, &split_after_init, &split_after_tick
	};
	NativeBehaviorRegistry::register_def(def);
}

} // namespace godot
