#ifndef NATIVE_BEHAVIOR_H
#define NATIVE_BEHAVIOR_H

#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/color.hpp>
#include <cstdint>
#include <vector>

namespace godot {

// 固定语义音效；Host 负责映射到 AssetRegistry。
enum BehaviorSfx : int32_t {
	SFX_NONE = -1,
	SFX_KIRA = 0,
};

// Behavior 每 tick 能看到的受控通道。不暴露 DanmakuStore 的整块 SoA。
struct NativeBehaviorContext {
	Vector2 player;
	Vector2 boss;
	bool has_boss = false;
	const PackedVector2Array *enemies = nullptr;
	// 当前位置（只读副本）与可选直写通道；行为需要“自己在哪”时用。
	Vector2 position;
	Vector2 *position_out = nullptr;
	float field_left = 0.0f;
	float field_right = 0.0f;
	float field_top = 0.0f;
	// 确定性 RNG 通道：store 注入；behavior 只通过它抽随机，不碰全局 RNG。
	float (*rng_float)(void *user) = nullptr;
	void *rng_user = nullptr;
	Vector2 *velocity = nullptr;
	float *heading_x = nullptr;
	float *heading_y = nullptr;
	float *render_rot = nullptr;
	float *spin_rot = nullptr;
	Color *color = nullptr;
	float *life = nullptr;
};

struct NativeBehaviorEmit {
	int32_t template_id = 0;
	Vector2 position;
	Vector2 velocity;
	Color color = Color(1, 1, 1, 1);
};

// behavior 每 tick 的延迟动作请求；内核在遍历结束后统一应用。
struct NativeBehaviorLaser {
	int32_t template_id = -1;
	Vector2 position;
	Vector2 direction;
};

struct NativeBehaviorOutcome {
	bool despawn = false;
	int emit_count = 0;
	NativeBehaviorEmit emits[4];
	int32_t sfx_id = -1;   // 由内容层注册的音效下标；-1 = 无
	bool clear_fx = false;  // 回收前播一次消弹消散
	int32_t laser_template_id = -1;
	Vector2 laser_position;
	Vector2 laser_direction = Vector2(0, 1);
};

struct NativeBehaviorDef {
	const char *name = "";
	int state_size = 0;      // 固定 float 槽数，<= 8
	int param_count = 0;     // 固定 float 参数数，<= 8
	void (*init)(float *state, const float *params) = nullptr;
	void (*tick)(float *state, const float *params, NativeBehaviorContext &ctx,
		NativeBehaviorOutcome &out, float dt) = nullptr;
};

// 编译期注册表：pack 初始化时注册，运行期只读。
class NativeBehaviorRegistry {
public:
	static int register_def(const NativeBehaviorDef &p_def);
	static int find_id(const String &p_name);
	static const NativeBehaviorDef *get(int p_id);
	static String get_name(int p_id);
	static int size();

private:
	static std::vector<NativeBehaviorDef> &_defs();
};

void register_behaviors_core();

} // namespace godot

#endif
