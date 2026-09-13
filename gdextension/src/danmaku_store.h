#ifndef DANMAKU_STORE_H
#define DANMAKU_STORE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
#include <vector>

namespace godot {

// N2-real 起点：原生 SoA 存储 + 积分 + 剔除 + 实例缓冲写入。
// 只做机制（每帧每颗），不含内容 / 规则。
class DanmakuStore : public RefCounted {
	GDCLASS(DanmakuStore, RefCounted)

	std::vector<float> _x, _y, _vx, _vy;
	int _count = 0;
	Rect2 _cull;
	float _margin = 0.0f;

protected:
	static void _bind_methods();

public:
	void setup(int p_capacity, const Rect2 &p_cull);
	int spawn(const Vector2 &p_pos, const Vector2 &p_vel);
	void integrate(double p_delta);
	int get_active_count() const;
	Vector2 get_position(int p_id) const;
	void fill_multimesh(const Ref<MultiMesh> &p_mm, const Color &p_color) const;

	DanmakuStore();
	~DanmakuStore();
};

} // namespace godot

#endif
