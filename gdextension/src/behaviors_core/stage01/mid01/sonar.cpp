#include "native_behavior.h"
#include "behavior_common.h"

namespace godot {

// 声呐弹：靠近自机 → 折返；靠近 Boss → 炸开一圈 + 可选串型弹，然后消失。
// params:
//   0 return_radius
//   1 flower_template
//   2 string_template
//   3 flower_count
//   4 string_mode (0 none / 1 hard 4 / 2 lunatic 16)
//   5 string_speed_base
struct SonarParams {
	float return_radius = 0.0f;
	float flower_template = -1.0f;
	float string_template = -1.0f;
	float flower_count = 0.0f;
	float string_mode = 0.0f;
	float string_speed_base = 400.0f;
};
struct SonarState { float phase = 0.0f; float tick = 0.0f; };

static constexpr float PI_F = 3.14159265f;
static constexpr float TAU_F = 6.28318530f;
static constexpr float PLAYER_NEAR = 150.0f;
static constexpr float FLOWER_SPEED = 400.0f;

static void sonar_init(float *p_state, const float *p_params) {
	(void)p_params;
	behavior::State<SonarState> state(p_state);
	*state = SonarState{};
}

static void sonar_tick(float *p_state, const float *p_params,
		NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
	(void)p_dt;
	behavior::State<SonarState> state(p_state);
	const auto p = behavior::params_as<SonarParams>(p_params);
	state->tick += 1.0f;
	const bool check = ((int)state->tick % 3) == 0;

	if (state->phase < 0.5f) {
		if (!check) {
			return;
		}
		const Vector2 to_player = p_ctx.player - p_ctx.position;
		if (to_player.length() > PLAYER_NEAR) {
			return;
		}
		const Vector2 away = (p_ctx.position - p_ctx.player);
		const Vector2 dir = away.length_squared() > 1e-6f ? away.normalized() : behavior::heading(p_ctx);
		const float speed = p_ctx.velocity->length();
		*p_ctx.velocity = dir * speed;
		*p_ctx.heading_x = dir.x;
		*p_ctx.heading_y = dir.y;
		state->phase = 1.0f;
		return;
	}
	if (!check) {
		return;
	}
	const Vector2 to_boss = p_ctx.boss - p_ctx.position;
	if (to_boss.length() > p.return_radius) {
		return;
	}

	// on_end_heading(random_dir(PI))：以当前朝向为中心随机一整圈。
	const float a = -PI_F + 2.0f * PI_F * behavior::random(p_ctx);
	const Vector2 new_dir = behavior::heading(p_ctx).rotated(a);
	const float speed = p_ctx.velocity->length();
	*p_ctx.velocity = new_dir * speed;
	*p_ctx.heading_x = new_dir.x;
	*p_ctx.heading_y = new_dir.y;

	const int flower_count = (int)p.flower_count;
	const float flower_step = flower_count > 0 ? TAU_F / (float)flower_count : 0.0f;
	for (int i = 0; i < flower_count; ++i) {
		behavior::emit(p_out, (int32_t)p.flower_template, p_ctx.position,
			new_dir.rotated(flower_step * i) * FLOWER_SPEED);
	}

	const int mode = (int)p.string_mode;
	if (mode == 1) {
		const Vector2 away = (p_ctx.position - p_ctx.boss);
		const Vector2 base = away.length_squared() > 1e-6f ? away.normalized() : new_dir;
		for (int i = 0; i < 4; ++i) {
			behavior::emit(p_out, (int32_t)p.string_template, p_ctx.position,
				base * (p.string_speed_base + i * 50.0f));
		}
	} else if (mode == 2) {
		const Vector2 away = (p_ctx.position - p_ctx.boss);
		const Vector2 base = away.length_squared() > 1e-6f ? away.normalized() : new_dir;
		const float spread = 1.0f / TAU_F / 6.0f;
		for (int i = 0; i < 8; ++i) {
			behavior::emit(p_out, (int32_t)p.string_template, p_ctx.position,
				base.rotated(spread) * (p.string_speed_base + i * 50.0f));
			behavior::emit(p_out, (int32_t)p.string_template, p_ctx.position,
				base.rotated(-spread) * (p.string_speed_base + i * 50.0f));
		}
	}

	behavior::play_sfx(p_out, SFX_KIRA);
	behavior::kill(p_out);
}

void register_sonar() {
	REGISTER_BEHAVIOR("stage01.mid01.sonar", SonarState, SonarParams, &sonar_init, &sonar_tick);
}

} // namespace godot
