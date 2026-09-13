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
	PackedVector2Array get_positions() const;
	int get_type(int p_id) const;
	int get_faction(int p_id) const;
	Color get_color(int p_id) const;
	void fill_multimesh(const Ref<MultiMesh> &p_mm) const;

	DanmakuStore();
	~DanmakuStore();
};

} // namespace godot

#endif
