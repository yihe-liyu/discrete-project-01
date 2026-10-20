#ifndef DANMAKU_RENDER_BRIDGE_H
#define DANMAKU_RENDER_BRIDGE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <unordered_map>
#include <vector>
#include <cstdint>

namespace godot {

// DanmakuRenderBridge
// 原生渲染批处理：把 BulletMultiMesh 的分组、旋转/fade、填充从 GDScript 搬到 C++。
// 不拥有 MultiMesh，也不读场景节点；宿主传入快照和 MultiMesh。
//
// 输入快照是容量大小；只有前 p_count 行有效。
// group 只返回键 / 行 id / 旋转 / alpha；fill / fill_fx 用同一快照写 MultiMesh。
class DanmakuRenderBridge : public RefCounted {
	GDCLASS(DanmakuRenderBridge, RefCounted)

	// 类型表（注册一次；类型数变化时宿主刷新）
	PackedInt64Array _tex_key_base;   // 纹理 RID id（Atlas 已折入 region hash）；-1 = 不画
	PackedInt32Array _tint_mode;
	PackedInt32Array _kind;
	PackedByteArray _follow_dir;
	PackedFloat32Array _dir_offset;

	// 特效表（发弹/消弹共用；行 fx_type 指向它）
	PackedInt64Array _fx_tex_key;      // 特效贴图 RID id；-1 = 不画
	PackedFloat32Array _fx_duration;
	PackedFloat32Array _fx_scale_from;
	PackedFloat32Array _fx_scale_to;
	PackedFloat32Array _fx_alpha_from;
	PackedFloat32Array _fx_alpha_to;
	PackedInt32Array _fx_tint_mode;

	std::unordered_map<int64_t, std::vector<int>> _buckets;
	std::unordered_map<int64_t, std::vector<int>> _fx_buckets;

protected:
	static void _bind_methods();

public:
	// 类型表：贴图 RID + tint/kind/follow/dir_offset；类型数变化时宿主刷新。
	void set_type_table(const PackedInt64Array &p_tex_key_base, const PackedInt32Array &p_tint_mode, const PackedInt32Array &p_kind, const PackedByteArray &p_follow_dir, const PackedFloat32Array &p_dir_offset);
	int get_type_count() const;
	// 特效表：贴图 RID + 时长 / 缩放 / alpha 曲线 / tint。
	void set_fx_table(const PackedInt64Array &p_tex_key, const PackedFloat32Array &p_duration, const PackedFloat32Array &p_scale_from, const PackedFloat32Array &p_scale_to, const PackedFloat32Array &p_alpha_from, const PackedFloat32Array &p_alpha_to, const PackedInt32Array &p_tint_mode);
	int get_fx_type_count() const;
	// 按纹理/阵营/tint 分组；返回 {keys/starts/rows/rots/alphas} + {fx_keys/fx_starts/fx_rows/fx_rots/fx_alphas/fx_scales}。
	Dictionary group(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedColorArray &p_colors, const PackedInt32Array &p_type_indices, const PackedByteArray &p_factions, const PackedFloat32Array &p_fade_by_kind, const PackedFloat32Array &p_render_rots = PackedFloat32Array(), const PackedFloat32Array &p_fx_phases = PackedFloat32Array(), const PackedInt32Array &p_fx_type_indices = PackedInt32Array());
	// 按 group 的 rows/rots/alphas 写 MultiMesh；start/count 截取。
	void fill(const Ref<MultiMesh> &p_mm, const PackedVector2Array &p_positions, const PackedColorArray &p_colors, const PackedInt32Array &p_rows, const PackedFloat32Array &p_rots, const PackedFloat32Array &p_alphas, int p_start, int p_count) const;
	// 同 fill，额外写特效缩放。
	void fill_fx(const Ref<MultiMesh> &p_mm, const PackedVector2Array &p_positions, const PackedColorArray &p_colors, const PackedInt32Array &p_rows, const PackedFloat32Array &p_rots, const PackedFloat32Array &p_alphas, const PackedFloat32Array &p_scales, int p_start, int p_count) const;

	DanmakuRenderBridge();
	~DanmakuRenderBridge();
};

} // namespace godot

#endif
