#ifndef DANMAKU_STORE_H
#define DANMAKU_STORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <vector>

namespace godot {

// N2-real：原生 SoA 存储 + 积分 + 剔除 + 实例缓冲写入。
// 每弹携带 type / faction / color，供渲染与后续宿主规则使用。
// **批量 spawn**（spawn_batch）避免逐弹跨语言边界。
class DanmakuStore : public RefCounted {
	GDCLASS(DanmakuStore, RefCounted)

	std::vector<float> _x, _y, _vx, _vy;
	std::vector<int> _type, _faction;
	std::vector<Color> _color;
	std::vector<float> _life, _fx, _timer;
	float _default_life = 20.0f;
	int _capacity = 0;
	int _count = 0;
	Rect2 _cull;
	float _margin = 0.0f;

protected:
	static void _bind_methods();

public:
	void setup(int p_capacity, const Rect2 &p_cull);
	int spawn(const Vector2 &p_pos, const Vector2 &p_vel, int p_type = 0, int p_faction = 0, const Color &p_color = Color(1, 1, 1, 1));
	int spawn_batch(const PackedVector2Array &p_pos, const PackedVector2Array &p_vel, const PackedInt32Array &p_type, const PackedInt32Array &p_faction, const PackedColorArray &p_color);
	void integrate(double p_delta);
	int get_active_count() const;
	Vector2 get_position(int p_id) const;
	Vector2 get_velocity(int p_id) const;
	PackedVector2Array get_positions() const;
	PackedVector2Array get_velocities() const;
	int get_type(int p_id) const;
	int get_faction(int p_id) const;
	Color get_color(int p_id) const;
	// N2 存储段：原生持有 SoA；积分/回收语义与 GDScript 内核 1:1。
	void set_margin(float p_margin);
	void set_default_life(float p_life);
	void clear();
	int despawn(int p_id);
	void set_life(int p_id, float p_life);
	void set_fx(int p_id, float p_fx);
	void set_timer(int p_id, float p_timer);
	void set_velocity(int p_id, const Vector2 &p_vel);
	void set_position(int p_id, const Vector2 &p_pos);
	float get_life_left(int p_id) const;
	float get_fx_phase(int p_id) const;
	float get_timer(int p_id) const;
	PackedFloat32Array get_life_lefts() const;
	PackedFloat32Array get_fx_phases() const;
	PackedFloat32Array get_timers() const;
	int get_capacity() const;
	void fill_multimesh(const Ref<MultiMesh> &p_mm) const;

	// N2.2：无状态「积分加速器」——对宿主传入的 SoA 数组跑完整积分/寿命/出生相位/剔除循环，
	// 返回新数组 + 本帧应回收的行 id（**不做 swap**：回收由 GDScript 侧按既有契约重放，
	// 保证颜色/行为等 GDScript 专有字段的行身份一致）。数组按值 CoW 进出，无跨帧状态。
	void _swap_remove(int p_id);

	Dictionary integrate_batch(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedFloat32Array &p_life_left, const PackedFloat32Array &p_fx_phase, const PackedFloat32Array &p_timers, double p_delta, const Vector2 &p_cull_pos, const Vector2 &p_cull_size, float p_margin) const;

	DanmakuStore();
	~DanmakuStore();
};

} // namespace godot

#endif