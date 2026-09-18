#include "danmaku_render_bridge.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <cmath>

using namespace godot;

void DanmakuRenderBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_type_table", "tex_key_base", "tint_mode", "kind", "follow_dir", "dir_offset"), &DanmakuRenderBridge::set_type_table);
	ClassDB::bind_method(D_METHOD("get_type_count"), &DanmakuRenderBridge::get_type_count);
	ClassDB::bind_method(D_METHOD("group", "count", "positions", "velocities", "colors", "type_indices", "factions", "fade_by_kind", "render_rots"), &DanmakuRenderBridge::group, DEFVAL(PackedFloat32Array()));
	ClassDB::bind_method(D_METHOD("fill", "mm", "positions", "colors", "rows", "rots", "alphas", "start", "count"), &DanmakuRenderBridge::fill);
}

void DanmakuRenderBridge::set_type_table(const PackedInt64Array &p_tex_key_base, const PackedInt32Array &p_tint_mode, const PackedInt32Array &p_kind, const PackedByteArray &p_follow_dir, const PackedFloat32Array &p_dir_offset) {
	_tex_key_base = p_tex_key_base;
	_tint_mode = p_tint_mode;
	_kind = p_kind;
	_follow_dir = p_follow_dir;
	_dir_offset = p_dir_offset;
}

int DanmakuRenderBridge::get_type_count() const {
	return _tex_key_base.size();
}

Dictionary DanmakuRenderBridge::group(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedColorArray &p_colors, const PackedInt32Array &p_type_indices, const PackedByteArray &p_factions, const PackedFloat32Array &p_fade_by_kind, const PackedFloat32Array &p_render_rots) {
	_buckets.clear();
	// 快照数组是**容量大小**，只有前 p_count 条是活跃的（GDScript 侧用 for i in count 截断）。
	const int n = p_count < p_type_indices.size() ? p_count : p_type_indices.size();
	const int types = _tex_key_base.size();
	for (int i = 0; i < n; ++i) {
		const int ti = p_type_indices[i];
		if (ti < 0 || ti >= types) {
			continue;   // 纯特效行 / 越界
		}
		const int64_t base = _tex_key_base[ti];
		if (base < 0) {
			continue;   // 无贴图
		}
		// 内核 Faction{ENEMY=0, PLAYER=1, NONE=2} → 宿主{PLAYER=0, ENEMY=1, BOMB=2}（与 _host_faction 一致）
		const int kf = i < p_factions.size() ? (int)p_factions[i] : 0;
		int hf = 2;
		if (kf == 0) {
			hf = 1;
		} else if (kf == 1) {
			hf = 0;
		}
		const int tm = ti < _tint_mode.size() ? _tint_mode[ti] : 1;
		const int64_t key = base * 16 + hf * 2 + tm;
		_buckets[key].push_back(i);
	}

	PackedInt64Array keys;
	PackedInt32Array starts;
	PackedInt32Array rows;
	PackedFloat32Array rots;
	PackedFloat32Array alphas;
	const int ng = (int)_buckets.size();
	keys.resize(ng);
	starts.resize(ng + 1);
	int total = 0;
	for (const auto &kv : _buckets) {
		total += (int)kv.second.size();
	}
	rows.resize(total);
	rots.resize(total);
	alphas.resize(total);

	int gi = 0;
	int off = 0;
	for (const auto &kv : _buckets) {
		keys[gi] = kv.first;
		starts[gi] = off;
		for (const int r : kv.second) {
			const int ti = p_type_indices[r];
			const Vector2 v = r < p_velocities.size() ? p_velocities[r] : Vector2();
			const bool follow = ti < _follow_dir.size() && _follow_dir[ti] != 0;
			const float d_off = ti < _dir_offset.size() ? _dir_offset[ti] : 0.0f;
			// V19：优先用逐弹 render_rot 覆盖（位置 op 的 render_heading）；否则回退 velocity 角。
			const bool has_rr = r < p_render_rots.size() && !std::isnan(p_render_rots[r]);
			float rot = 0.0f;
			if (follow && (has_rr || v != Vector2())) {
				const float base_rot = has_rr ? p_render_rots[r] : (float)std::atan2(v.y, v.x);
				rot = base_rot + d_off;
			}
			const int k = ti < _kind.size() ? _kind[ti] : 0;
			const float fade = k < p_fade_by_kind.size() ? p_fade_by_kind[k] : 1.0f;
			rows[off] = r;
			rots[off] = rot;
			alphas[off] = fade < 1.0f ? fade : 1.0f;
			++off;
		}
		++gi;
	}
	starts[ng] = off;

	Dictionary out;
	out["keys"] = keys;
	out["starts"] = starts;
	out["rows"] = rows;
	out["rots"] = rots;
	out["alphas"] = alphas;
	return out;
}

void DanmakuRenderBridge::fill(const Ref<MultiMesh> &p_mm, const PackedVector2Array &p_positions, const PackedColorArray &p_colors, const PackedInt32Array &p_rows, const PackedFloat32Array &p_rots, const PackedFloat32Array &p_alphas, int p_start, int p_count) const {
	if (p_mm.is_null()) {
		return;
	}
	for (int s = 0; s < p_count; ++s) {
		const int idx = p_start + s;
		const int r = p_rows[idx];
		Color c = r < p_colors.size() ? p_colors[r] : Color(1, 1, 1, 1);
		c.a *= p_alphas[idx];
		const Vector2 pos = r < p_positions.size() ? p_positions[r] : Vector2();
		p_mm->set_instance_transform_2d(s, Transform2D(p_rots[idx], Vector2(1.0f, 1.0f), 0.0f, pos));
		p_mm->set_instance_color(s, c);
	}
}

DanmakuRenderBridge::DanmakuRenderBridge() {}
DanmakuRenderBridge::~DanmakuRenderBridge() {}
