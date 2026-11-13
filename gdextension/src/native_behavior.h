#ifndef NATIVE_BEHAVIOR_H
#define NATIVE_BEHAVIOR_H

#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <cstdint>
#include <vector>

namespace godot {

// Behavior 每 tick 能看到的受控通道。不暴露 DanmakuStore 的整块 SoA。
struct NativeBehaviorContext {
	Vector2 player;
	Vector2 boss;
	bool has_boss = false;
	const PackedVector2Array *enemies = nullptr;
	Vector2 *velocity = nullptr;
	float *heading_x = nullptr;
	float *heading_y = nullptr;
	float *render_rot = nullptr;
	float *life = nullptr;
};

struct NativeBehaviorDef {
	const char *name = "";
	int state_size = 0;      // 固定 float 槽数，<= 8
	int param_count = 0;     // 固定 float 参数数，<= 8
	void (*init)(float *state, const float *params) = nullptr;
	void (*tick)(float *state, const float *params, NativeBehaviorContext &ctx, float dt) = nullptr;
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
