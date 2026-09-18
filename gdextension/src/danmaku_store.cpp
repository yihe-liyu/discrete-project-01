#include "danmaku_store.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <cmath>
#include <algorithm>
#include <functional>

using namespace godot;

void DanmakuStore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "capacity", "cull"), &DanmakuStore::setup);
	ClassDB::bind_method(D_METHOD("spawn", "pos", "vel", "type", "faction", "color"), &DanmakuStore::spawn, DEFVAL(0), DEFVAL(0), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("spawn_batch", "pos", "vel", "type", "faction", "color"), &DanmakuStore::spawn_batch);
	ClassDB::bind_method(D_METHOD("integrate", "delta"), &DanmakuStore::integrate);
	ClassDB::bind_method(D_METHOD("get_active_count"), &DanmakuStore::get_active_count);
	ClassDB::bind_method(D_METHOD("get_colors"), &DanmakuStore::get_colors);
	ClassDB::bind_method(D_METHOD("get_type_indices"), &DanmakuStore::get_type_indices);
	ClassDB::bind_method(D_METHOD("get_factions"), &DanmakuStore::get_factions);
	ClassDB::bind_method(D_METHOD("get_factions_bytes"), &DanmakuStore::get_factions_bytes);
	ClassDB::bind_method(D_METHOD("behavior_batch", "count", "positions", "velocities", "life", "fx", "program", "phase", "tick", "elapsed", "slots", "delta", "player", "boss", "has_boss", "enemies", "anchor_base"), &DanmakuStore::behavior_batch, DEFVAL(PackedVector2Array()));
	ClassDB::bind_method(D_METHOD("get_position", "id"), &DanmakuStore::get_position);
	ClassDB::bind_method(D_METHOD("get_velocity", "id"), &DanmakuStore::get_velocity);
	ClassDB::bind_method(D_METHOD("get_forward", "id"), &DanmakuStore::get_forward);
	ClassDB::bind_method(D_METHOD("set_forward", "id", "fwd"), &DanmakuStore::set_forward);
	ClassDB::bind_method(D_METHOD("get_positions"), &DanmakuStore::get_positions);
	ClassDB::bind_method(D_METHOD("get_velocities"), &DanmakuStore::get_velocities);
	ClassDB::bind_method(D_METHOD("get_type", "id"), &DanmakuStore::get_type);
	ClassDB::bind_method(D_METHOD("get_faction", "id"), &DanmakuStore::get_faction);
	ClassDB::bind_method(D_METHOD("get_color", "id"), &DanmakuStore::get_color);
	ClassDB::bind_method(D_METHOD("fill_multimesh", "mm"), &DanmakuStore::fill_multimesh);
	ClassDB::bind_method(D_METHOD("reserve", "n"), &DanmakuStore::reserve);
	ClassDB::bind_method(D_METHOD("set_cull", "cull"), &DanmakuStore::set_cull);
	ClassDB::bind_method(D_METHOD("set_margin", "margin"), &DanmakuStore::set_margin);
	ClassDB::bind_method(D_METHOD("set_default_life", "life"), &DanmakuStore::set_default_life);
	ClassDB::bind_method(D_METHOD("set_hitbox", "id", "radius", "offset", "size", "follow_dir", "dir_offset"), &DanmakuStore::set_hitbox);
	ClassDB::bind_method(D_METHOD("hit_test", "id", "center", "radius"), &DanmakuStore::hit_test);
	ClassDB::bind_method(D_METHOD("query_circle", "center", "radius"), &DanmakuStore::query_circle);
	ClassDB::bind_method(D_METHOD("is_broadphase_active"), &DanmakuStore::is_broadphase_active);
	ClassDB::bind_method(D_METHOD("overlap_pairs", "faction", "targets", "radii"), &DanmakuStore::overlap_pairs);
	ClassDB::bind_method(D_METHOD("is_grazed", "id"), &DanmakuStore::is_grazed);
	ClassDB::bind_method(D_METHOD("mark_grazed", "id"), &DanmakuStore::mark_grazed);
	ClassDB::bind_method(D_METHOD("set_field", "left", "right", "top"), &DanmakuStore::set_field);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &DanmakuStore::set_seed);
	ClassDB::bind_method(D_METHOD("register_program", "ops", "args", "move_start", "move_count", "until", "act_start", "act_count", "phase_count", "slots"), &DanmakuStore::register_program);
	ClassDB::bind_method(D_METHOD("set_program", "id", "program"), &DanmakuStore::set_program);
	ClassDB::bind_method(D_METHOD("get_program", "id"), &DanmakuStore::get_program);
	ClassDB::bind_method(D_METHOD("behavior_tick", "delta", "player", "boss", "has_boss", "enemies", "anchor_base"), &DanmakuStore::behavior_tick, DEFVAL(PackedVector2Array()));
	ClassDB::bind_method(D_METHOD("clear"), &DanmakuStore::clear);
	ClassDB::bind_method(D_METHOD("despawn", "id"), &DanmakuStore::despawn);
	ClassDB::bind_method(D_METHOD("set_life", "id", "life"), &DanmakuStore::set_life);
	ClassDB::bind_method(D_METHOD("set_fx", "id", "fx"), &DanmakuStore::set_fx);
	ClassDB::bind_method(D_METHOD("set_timer", "id", "timer"), &DanmakuStore::set_timer);
	ClassDB::bind_method(D_METHOD("set_velocity", "id", "vel"), &DanmakuStore::set_velocity);
	ClassDB::bind_method(D_METHOD("set_position", "id", "pos"), &DanmakuStore::set_position);
	ClassDB::bind_method(D_METHOD("get_life_left", "id"), &DanmakuStore::get_life_left);
	ClassDB::bind_method(D_METHOD("get_fx_phase", "id"), &DanmakuStore::get_fx_phase);
	ClassDB::bind_method(D_METHOD("get_timer", "id"), &DanmakuStore::get_timer);
	ClassDB::bind_method(D_METHOD("get_life_lefts"), &DanmakuStore::get_life_lefts);
	ClassDB::bind_method(D_METHOD("get_fx_phases"), &DanmakuStore::get_fx_phases);
	ClassDB::bind_method(D_METHOD("get_timers"), &DanmakuStore::get_timers);
	ClassDB::bind_method(D_METHOD("get_render_rots"), &DanmakuStore::get_render_rots);
	ClassDB::bind_method(D_METHOD("get_capacity"), &DanmakuStore::get_capacity);
	ClassDB::bind_method(D_METHOD("integrate_batch", "count", "positions", "velocities", "life_left", "fx_phase", "timers", "delta", "cull_pos", "cull_size", "margin"), &DanmakuStore::integrate_batch);
}

void DanmakuStore::setup(int p_capacity, const Rect2 &p_cull) {
	_grid_dirty = true;
	_capacity = p_capacity;
	_cull = p_cull;
	_x.assign(p_capacity, 0.0f);
	_y.assign(p_capacity, 0.0f);
	_vx.assign(p_capacity, 0.0f);
	_vy.assign(p_capacity, 0.0f);
	_hx.assign(p_capacity, 0.0f);
	_hy.assign(p_capacity, 0.0f);
	_type.assign(p_capacity, 0);
	_faction.assign(p_capacity, 0);
	_color.assign(p_capacity, Color(1, 1, 1, 1));
	_life.assign(p_capacity, 0.0f);
	_fx.assign(p_capacity, 0.0f);
	_timer.assign(p_capacity, 0.0f);
	_program.assign(p_capacity, -1);
	_pphase.assign(p_capacity, 0);
	_ptick.assign(p_capacity, 0);
	_pelapsed.assign(p_capacity, 0.0f);
	_pnext.assign(p_capacity, 0.0f);
	_pendx.assign(p_capacity, 0.0f);
	_pendy.assign(p_capacity, 0.0f);
	_pslots.assign(p_capacity * SLOT_STRIDE, 0.0f);
	_pslot_fresh.assign(p_capacity, 0xFFFFFFFFu);
	_phasend.assign(p_capacity, 0);
	_hb_radius.assign(p_capacity, 0.0f);
	_hb_offx.assign(p_capacity, 0.0f);
	_hb_offy.assign(p_capacity, 0.0f);
	_hb_sizex.assign(p_capacity, 0.0f);
	_hb_sizey.assign(p_capacity, 0.0f);
	_hb_diroff.assign(p_capacity, 0.0f);
	_hb_follow.assign(p_capacity, 0);
	_grazed.assign(p_capacity, 0);
	_render_rot.assign(p_capacity, (float)NAN);
	_count = 0;
}

int DanmakuStore::spawn(const Vector2 &p_pos, const Vector2 &p_vel, int p_type, int p_faction, const Color &p_color) {
	_grid_dirty = true;
	if (_count >= _capacity) {
		return -1;
	}
	const int i = _count;
	_x[i] = p_pos.x;
	_y[i] = p_pos.y;
	_vx[i] = p_vel.x;
	_vy[i] = p_vel.y;
	{ const Vector2 h = p_vel == Vector2() ? Vector2(0, 1) : p_vel.normalized(); _hx[i] = h.x; _hy[i] = h.y; }
	_type[i] = p_type;
	_faction[i] = p_faction;
	_color[i] = p_color;
	_life[i] = _default_life;
	_fx[i] = 0.0f;
	_timer[i] = 0.0f;
	// L3.5-4e：有状态 spawn 必须整行归零（batch 路径由调用方传数组，stateful 没有）。
	_program[i] = -1;
	_pphase[i] = 0;
	_ptick[i] = 0;
	_pelapsed[i] = 0.0f;
	_pnext[i] = 0.0f;
	_pendx[i] = 0.0f;
	_pendy[i] = 0.0f;
	_pslot_fresh[i] = 0xFFFFFFFFu;
	_phasend[i] = 0;
	for (int s = 0; s < SLOT_STRIDE; ++s) { _pslots[i * SLOT_STRIDE + s] = 0.0f; }
	_hb_radius[i] = 0.0f; _hb_offx[i] = 0.0f; _hb_offy[i] = 0.0f;
	_hb_sizex[i] = 0.0f; _hb_sizey[i] = 0.0f; _hb_diroff[i] = 0.0f; _hb_follow[i] = 0;
	_grazed[i] = 0;
	_render_rot[i] = (float)NAN;
	return _count++;
}

int DanmakuStore::spawn_batch(const PackedVector2Array &p_pos, const PackedVector2Array &p_vel, const PackedInt32Array &p_type, const PackedInt32Array &p_faction, const PackedColorArray &p_color) {
	_grid_dirty = true;
	const int n = p_pos.size();
	int added = 0;
	for (int k = 0; k < n; ++k) {
		if (_count >= _capacity) {
			break;
		}
		const int i = _count;
		const Vector2 pos = p_pos[k];
		const Vector2 vel = k < p_vel.size() ? p_vel[k] : Vector2();
		_x[i] = pos.x;
		_y[i] = pos.y;
		_vx[i] = vel.x;
		_vy[i] = vel.y;
		{ const Vector2 h = vel == Vector2() ? Vector2(0, 1) : vel.normalized(); _hx[i] = h.x; _hy[i] = h.y; }
		_type[i] = k < p_type.size() ? p_type[k] : 0;
		_faction[i] = k < p_faction.size() ? p_faction[k] : 0;
		_color[i] = k < p_color.size() ? p_color[k] : Color(1, 1, 1, 1);
		_life[i] = _default_life;
		_fx[i] = 0.0f;
		_timer[i] = 0.0f;
		_program[i] = -1;
		_pphase[i] = 0;
		_ptick[i] = 0;
		_pelapsed[i] = 0.0f;
		_pnext[i] = 0.0f;
		_pendx[i] = 0.0f;
		_pendy[i] = 0.0f;
		_pslot_fresh[i] = 0xFFFFFFFFu;
		_phasend[i] = 0;
		for (int s = 0; s < SLOT_STRIDE; ++s) { _pslots[i * SLOT_STRIDE + s] = 0.0f; }
		_hb_radius[i] = 0.0f; _hb_offx[i] = 0.0f; _hb_offy[i] = 0.0f;
		_hb_sizex[i] = 0.0f; _hb_sizey[i] = 0.0f; _hb_diroff[i] = 0.0f; _hb_follow[i] = 0;
		_grazed[i] = 0;
		_render_rot[i] = (float)NAN;
		++_count;
		++added;
	}
	return added;
}

// 按需扩容内部向量（behavior_batch 无状态入口用：桥接侧不调 setup，_capacity 可能为 0）。
void DanmakuStore::_ensure_capacity(int p_n) {
	if (p_n <= _capacity) {
		return;
	}
	_capacity = p_n;
	_x.resize(p_n); _y.resize(p_n); _vx.resize(p_n); _vy.resize(p_n);
	_hx.resize(p_n); _hy.resize(p_n);
	_type.resize(p_n); _faction.resize(p_n); _color.resize(p_n);
	_life.resize(p_n); _fx.resize(p_n); _timer.resize(p_n);
	_program.resize(p_n); _pphase.resize(p_n); _ptick.resize(p_n);
	_pelapsed.resize(p_n); _pnext.resize(p_n); _pendx.resize(p_n); _pendy.resize(p_n);
	_pslots.resize(p_n * SLOT_STRIDE);
	_pslot_fresh.resize(p_n); _phasend.resize(p_n);
	_hb_radius.resize(p_n); _hb_offx.resize(p_n); _hb_offy.resize(p_n);
	_hb_sizex.resize(p_n); _hb_sizey.resize(p_n); _hb_diroff.resize(p_n);
	_hb_follow.resize(p_n); _grazed.resize(p_n); _render_rot.resize(p_n);
}

// swap-with-last 回收：把尾行整行搬进空槽（新增字段必须在这里同步）。
void DanmakuStore::_swap_remove(int p_id) {
	_grid_dirty = true;
	const int last = --_count;
	if (p_id == last) {
		return;
	}
	_x[p_id] = _x[last];
	_y[p_id] = _y[last];
	_vx[p_id] = _vx[last];
	_vy[p_id] = _vy[last];
	_hx[p_id] = _hx[last];
	_hy[p_id] = _hy[last];
	_type[p_id] = _type[last];
	_faction[p_id] = _faction[last];
	_color[p_id] = _color[last];
	_life[p_id] = _life[last];
	_fx[p_id] = _fx[last];
	_timer[p_id] = _timer[last];
	_program[p_id] = _program[last];
	_pphase[p_id] = _pphase[last];
	_ptick[p_id] = _ptick[last];
	_pelapsed[p_id] = _pelapsed[last];
	_pnext[p_id] = _pnext[last];
	_pendx[p_id] = _pendx[last];
	_pendy[p_id] = _pendy[last];
	_pslot_fresh[p_id] = _pslot_fresh[last];
	_phasend[p_id] = _phasend[last];
	for (int s = 0; s < SLOT_STRIDE; ++s) {
		_pslots[p_id * SLOT_STRIDE + s] = _pslots[last * SLOT_STRIDE + s];
	}
	_hb_radius[p_id] = _hb_radius[last];
	_hb_offx[p_id] = _hb_offx[last];
	_hb_offy[p_id] = _hb_offy[last];
	_hb_sizex[p_id] = _hb_sizex[last];
	_hb_sizey[p_id] = _hb_sizey[last];
	_hb_diroff[p_id] = _hb_diroff[last];
	_hb_follow[p_id] = _hb_follow[last];
	_grazed[p_id] = _grazed[last];
	_render_rot[p_id] = _render_rot[last];
}

// 完整积分循环：寿命 / 出生相位 / 位移 / 计时 / 剔除 —— 与 scripts/kernel/bullet_system.gd 1:1。
void DanmakuStore::integrate(double p_delta) {
	_grid_dirty = true;
	const float dt = (float)p_delta;
	const bool cull = _cull.has_area();
	const Rect2 grown = _cull.grow(_margin);
	for (int i = _count - 1; i >= 0; --i) {
		if (_life[i] >= 0.0f) {
			_life[i] -= dt;
			if (_life[i] <= 0.0f) {
				_swap_remove(i);
				continue;
			}
		}
		if (_fx[i] > 0.0f) {
			_fx[i] -= dt;
			if (_fx[i] > 0.0f) {
				continue;
			}
			_fx[i] = 0.0f;
		}
		_x[i] += _vx[i] * dt;
		_y[i] += _vy[i] * dt;
		if (_timer[i] > 0.0f) {
			_timer[i] -= dt;
		}
		if (cull && !grown.has_point(Vector2(_x[i], _y[i]))) {
			_swap_remove(i);
		}
	}
}

// L3.5-4e：有状态存储的容量扩容（grow-only）与剔除区注入。
void DanmakuStore::reserve(int p_n) { _ensure_capacity(p_n); }
void DanmakuStore::set_cull(const Rect2 &p_cull) { _cull = p_cull; _grid_dirty = true; }
void DanmakuStore::set_margin(float p_margin) { _margin = p_margin; }
void DanmakuStore::set_default_life(float p_life) { _default_life = p_life; }
void DanmakuStore::set_field(float p_left, float p_right, float p_top) { _field_left = p_left; _field_right = p_right; _field_top = p_top; }
int DanmakuStore::get_capacity() const { return _capacity; }

void DanmakuStore::clear() {
	_grid_dirty = true;
	_count = 0;
}

int DanmakuStore::despawn(int p_id) {
	if (p_id < 0 || p_id >= _count) {
		return -1;
	}
	const int moved = _count - 1;
	_swap_remove(p_id);
	return moved == p_id ? -1 : moved;
}

void DanmakuStore::set_life(int p_id, float p_life) { _life[p_id] = p_life; }
void DanmakuStore::set_fx(int p_id, float p_fx) { _fx[p_id] = p_fx; }
void DanmakuStore::set_timer(int p_id, float p_timer) { _timer[p_id] = p_timer; }
void DanmakuStore::set_velocity(int p_id, const Vector2 &p_vel) { _vx[p_id] = p_vel.x; _vy[p_id] = p_vel.y; }
void DanmakuStore::set_position(int p_id, const Vector2 &p_pos) {
	_x[p_id] = p_pos.x; _y[p_id] = p_pos.y;
	_grid_dirty = true;
}
float DanmakuStore::get_life_left(int p_id) const { return _life[p_id]; }
float DanmakuStore::get_fx_phase(int p_id) const { return _fx[p_id]; }
float DanmakuStore::get_timer(int p_id) const { return _timer[p_id]; }

PackedFloat32Array DanmakuStore::get_life_lefts() const {
	PackedFloat32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = _life[i];
	}
	return out;
}

PackedFloat32Array DanmakuStore::get_fx_phases() const {
	PackedFloat32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = _fx[i];
	}
	return out;
}

PackedFloat32Array DanmakuStore::get_timers() const {
	PackedFloat32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = _timer[i];
	}
	return out;
}

// V19：逐弹渲染朝向覆盖（NAN = 未设，渲染端回退到 velocity 角）。
PackedFloat32Array DanmakuStore::get_render_rots() const {
	PackedFloat32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = _render_rot[i];
	}
	return out;
}

int DanmakuStore::get_active_count() const {
	return _count;
}

Vector2 DanmakuStore::get_position(int p_id) const {
	return Vector2(_x[p_id], _y[p_id]);
}

PackedVector2Array DanmakuStore::get_positions() const {
	PackedVector2Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = Vector2(_x[i], _y[i]);
	}
	return out;
}

Vector2 DanmakuStore::get_forward(int p_id) const { return Vector2(_hx[p_id], _hy[p_id]); }
void DanmakuStore::set_forward(int p_id, const Vector2 &p_fwd) {
	const Vector2 f = p_fwd.normalized();
	_hx[p_id] = f.x; _hy[p_id] = f.y;
}

Vector2 DanmakuStore::get_velocity(int p_id) const {
	return Vector2(_vx[p_id], _vy[p_id]);
}

PackedVector2Array DanmakuStore::get_velocities() const {
	PackedVector2Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = Vector2(_vx[i], _vy[i]);
	}
	return out;
}

int DanmakuStore::get_type(int p_id) const { return _type[p_id]; }
int DanmakuStore::get_faction(int p_id) const { return _faction[p_id]; }
Color DanmakuStore::get_color(int p_id) const { return _color[p_id]; }

void DanmakuStore::fill_multimesh(const Ref<MultiMesh> &p_mm) const {
	if (p_mm.is_null()) {
		return;
	}
	for (int i = 0; i < _count; ++i) {
		p_mm->set_instance_transform_2d(i, Transform2D(0.0f, Vector2(_x[i], _y[i])));
		p_mm->set_instance_color(i, _color[i]);
	}
}

// N2.2：积分加速器。语义必须与 scripts/kernel/bullet_system.gd 的 _physics_process 1:1。
// 与 GDScript 版的唯一区别：这里**不**在循环里 swap 回收，只记录 dead；调用方按同序重放 despawn。
Dictionary DanmakuStore::integrate_batch(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedFloat32Array &p_life_left, const PackedFloat32Array &p_fx_phase, const PackedFloat32Array &p_timers, double p_delta, const Vector2 &p_cull_pos, const Vector2 &p_cull_size, float p_margin) const {
	const int n = MIN(p_count, MIN(p_positions.size(), p_velocities.size()));
	PackedVector2Array positions = p_positions;   // CoW 共享；下面首次写入时才整块拷贝
	PackedVector2Array velocities = p_velocities;
	PackedFloat32Array life = p_life_left;
	PackedFloat32Array fx = p_fx_phase;
	PackedFloat32Array timers = p_timers;
	PackedInt32Array dead;
	const float dt = (float)p_delta;
	const bool cull = p_cull_size.x > 0.0f && p_cull_size.y > 0.0f;
	const float x0 = p_cull_pos.x - p_margin;
	const float y0 = p_cull_pos.y - p_margin;
	const float x1 = p_cull_pos.x + p_cull_size.x + p_margin;
	const float y1 = p_cull_pos.y + p_cull_size.y + p_margin;
	for (int i = n - 1; i >= 0; --i) {
		if (life[i] >= 0.0f) {
			life[i] -= dt;
			if (life[i] <= 0.0f) {
				dead.push_back(i);
				continue;
			}
		}
		if (fx[i] > 0.0f) {
			fx[i] -= dt;
			if (fx[i] > 0.0f) {
				continue;
			}
			fx[i] = 0.0f;
		}
		const Vector2 p = positions[i] + velocities[i] * dt;
		positions[i] = p;
		if (timers[i] > 0.0f) {
			timers[i] -= dt;
		}
		if (cull && (p.x < x0 || p.x > x1 || p.y < y0 || p.y > y1)) {
			dead.push_back(i);
		}
	}
	Dictionary out;
	out["positions"] = positions;
	out["velocities"] = velocities;
	out["life_left"] = life;
	out["fx_phase"] = fx;
	out["timers"] = timers;
	out["dead"] = dead;
	return out;
}


// ═══ L3：packed program 执行器（与 GDScript 参考解释器 LifecycleBehavior 1:1）═══

int DanmakuStore::register_program(const PackedInt32Array &p_ops, const PackedFloat32Array &p_args,
		const PackedInt32Array &p_move_start, const PackedInt32Array &p_move_count,
		const PackedInt32Array &p_until, const PackedInt32Array &p_act_start,
		const PackedInt32Array &p_act_count, int p_phase_count, int p_slots) {
	// V20：`_pslots` 按固定 SLOT_STRIDE 分行索引；p_slots 超行宽会越界写进下一颗弹的行。
	// 显式拒绝（返回 -1），由宿主跳过注册并报错——不再静默串行。
	// 注意：这里**不发引擎消息**（原生 warning/error 会被 GUT 记为 Unexpected Errors）； 由调用方按返回值 -1 报告。
	if (p_slots > SLOT_STRIDE) {
		return -1;
	}
	const int pid = _p_phase_base.size();
	const int ops_base = _p_ops.size();
	_p_phase_base.append(_p_move_start.size());
	_p_slots.append(p_slots);
	for (int i = 0; i < p_phase_count; ++i) {
		_p_move_start.append(p_move_start[i] + ops_base);
		_p_move_count.append(p_move_count[i]);
		_p_until.append(p_until[i] + ops_base);
		_p_act_start.append(p_act_start[i] + ops_base);
		_p_act_count.append(p_act_count[i]);
	}
	for (int i = 0; i < p_ops.size(); ++i) {
		_p_ops.append(p_ops[i]);
	}
	for (int i = 0; i < p_args.size(); ++i) {
		_p_args.append(p_args[i]);
	}
	return pid;
}

int DanmakuStore::get_program(int p_id) const {
	if (p_id < 0 || p_id >= _count) { return -2; }
	return _program[p_id];
}

void DanmakuStore::set_program(int p_id, int p_program) {
	_program[p_id] = p_program;
	_pphase[p_id] = 0;
	_ptick[p_id] = 0;
	_pelapsed[p_id] = 0.0f;
	_pnext[p_id] = 0.0f;
	_pslot_fresh[p_id] = 0xFFFFFFFFu;
	_phasend[p_id] = 0;
	for (int s = 0; s < SLOT_STRIDE; ++s) {
		_pslots[p_id * SLOT_STRIDE + s] = 0.0f;
	}
}

Vector2 DanmakuStore::_target_pos(int p_tg, const Vector2 &from, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, bool &r_ok) {
	if (p_tg == 0) { r_ok = true; return player; }
	if (p_tg == 2) { r_ok = has_boss; return boss; }
	if (p_tg == 1) {
		bool found = false;
		Vector2 best;
		float bd = 1e30f;
		for (int k = 0; k < enemies.size(); ++k) {
			const Vector2 e = enemies[k];
			const float d = from.distance_squared_to(e);
			if (d < bd) { bd = d; best = e; found = true; }
		}
		r_ok = found;
		return best;
	}
	r_ok = false;
	return Vector2();
}

// K1：确定性 PRNG（xorshift32）。种子 0 会退化 → 用黄金比常量兜底。
void DanmakuStore::set_seed(int p_seed) {
	_rng_state = (uint32_t)((uint64_t)p_seed & 0xFFFFFFFFu);
	if (_rng_state == 0) { _rng_state = 0x9E3779B9u; }
}

float DanmakuStore::_rng_float() {
	uint32_t x = _rng_state;
	x ^= x << 13; x ^= x >> 17; x ^= x << 5;
	_rng_state = x;
	return (float)(x >> 8) * (1.0f / 16777216.0f);   // [0,1)
}

float DanmakuStore::_rng_range(float a, float b) { return a + (b - a) * _rng_float(); }

// V9/V10：纯方向解析——不消耗 RNG、不写隐藏分支；随机量 rnd 由调用方显式预抽。
Vector2 DanmakuStore::_resolve_dir(int p_dk, int p_tg, float angle, const Vector2 &pos, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, const Vector2 &forward, float p_prob, float rnd) {
	if (p_dk == 0) {
		return Vector2(sin(angle), -cos(angle));
	}
	if (p_dk == 3) {   // 自身朝向（forward）旋转 angle
		return forward.rotated(angle);
	}
	if (p_dk == 4) {   // 随机：沿自身朝向 ± angle 内随机（rnd ∈ [0,1)）
		return forward.rotated(-angle + 2.0f * angle * rnd);
	}
	if (p_dk == 5) {   // 概率瞄准：rnd < p → 精确朝 target；否则自身朝向旋转 angle
		if (rnd >= p_prob) {
			return forward.rotated(angle);
		}
		p_dk = 1;
		angle = 0.0f;
	}
	bool ok = false;
	const Vector2 tp = _target_pos(p_tg, pos, player, boss, has_boss, enemies, ok);
	Vector2 base = Vector2(0, 1);
	if (ok) {
		base = (p_dk == 1 ? (tp - pos) : (pos - tp)).normalized();
	}
	return base.rotated(angle);
}

// V10：方向表达式的随机消耗点显式化（RANDOM(4)/CHANCE(5) 各抽一次；其余 0 次）。
float DanmakuStore::_draw_dir_rnd(int p_dk) {
	return (p_dk == 4 || p_dk == 5) ? _rng_float() : 0.0f;
}

// V11：set_heading 的单一实现（Move case 7 / Action case 43 共用）。
void DanmakuStore::_apply_set_heading(int i, const float *a, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies) {
	const int dk = (int)a[0];
	const Vector2 d = _resolve_dir(dk, (int)a[1], a[2], Vector2(_x[i], _y[i]), player, boss, has_boss, enemies, Vector2(_hx[i], _hy[i]), a[3], _draw_dir_rnd(dk));
	if (d != Vector2()) {
		const float sp = Vector2(_vx[i], _vy[i]).length();
		_vx[i] = d.x * sp;
		_vy[i] = d.y * sp;
		_hx[i] = d.x; _hy[i] = d.y;
	}
}

// V11：set_speed 的单一实现（Move case 8 / Action case 44 共用）。
void DanmakuStore::_apply_set_speed(int i, const float *a) {
	const Vector2 vv(_vx[i], _vy[i]);
	const float len = vv.length();
	// V15：v=0 时用「朝向」定方向（与 set_heading 对称），不再静默 no-op。
	const Vector2 d = (len > 0.0f) ? vv / len : Vector2(_hx[i], _hy[i]);
	if (d != Vector2()) {
		_vx[i] = d.x * a[0];
		_vy[i] = d.y * a[0];
	}
}

void DanmakuStore::_exec_move(int i, int prog, float *slots, int ins, float dt, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, const PackedVector2Array &p_anchor_base) {
	const int op = _p_ops[ins];
	const float *a = &_p_args[ins * OPS_ARGS];
	Vector2 v(_vx[i], _vy[i]);
	switch (op) {
		case 1: // accel_world
			_vx[i] = v.x + a[0] * dt;
			_vy[i] = v.y + a[1] * dt;
			break;
		case 2: { // accel_heading —— 沿**自身朝向**加速（与速度解耦：v=0 也不失义，可减速→反向）
			const Vector2 dir(_hx[i], _hy[i]);
			if (dir != Vector2()) {
				_vx[i] = v.x + dir.x * a[0] * dt;
				_vy[i] = v.y + dir.y * a[0] * dt;
			}
			break;
		}
		case 3: { // rotate（mode：0=both / 1=velocity only / 2=heading only，V12）
			const int si = (int)a[2];
			const float turned = slots[si];
			float step = a[0] * dt;
			const float limit = a[1];
			if (limit > 0.0f) {
				const float remain = limit - turned;
				if (remain <= 0.0f) { break; }
				step = CLAMP(step, -remain, remain);
			}
			slots[si] = turned + ABS(step);
			const int mode = (int)a[3];
			if (mode != 2) { const Vector2 r = v.rotated(step); _vx[i] = r.x; _vy[i] = r.y; }
			if (mode != 1) { const Vector2 h = Vector2(_hx[i], _hy[i]).rotated(step); _hx[i] = h.x; _hy[i] = h.y; }
			break;
		}
		case 4: { // steer
			const Vector2 cur = v.normalized();
			if (cur == Vector2()) { break; }
			const float ramp = a[2];
			const float factor = ramp <= 0.0f ? 1.0f : CLAMP(_pelapsed[i] / ramp, 0.0f, 1.0f);
			Vector2 rotated = cur;
			const float su = a[4];
			const bool can_steer = su <= 0.0f || _pelapsed[i] <= su;
			if (can_steer) {
				bool ok = false;
				const Vector2 from(_x[i], _y[i]);
				const Vector2 tp = _target_pos((int)a[0], from, player, boss, has_boss, enemies, ok);
				if (ok) {
					const Vector2 diff = tp - from;
					const float dist = MAX(diff.length(), 1.0f);
					float dw = 1.0f;
					if (a[3] > 0.0f) { dw = 1.0f + a[3] / (dist + a[3]); }
					const float max_turn = a[1] * factor * dw * dt;
					rotated = cur.rotated(CLAMP(cur.angle_to(diff / dist), -max_turn, max_turn));
				}
			}
			// V2：steer 只转向、不改速度（速度是独立轴，交给 speed_lerp / set_speed）。
			const Vector2 nv = rotated * v.length();
			_vx[i] = nv.x;
			_vy[i] = nv.y;
			break;
		}
		case 5: { // speed_lerp
			const Vector2 d = v.normalized();
			if (d != Vector2()) {
				const float ramp = a[2];
				const float f = ramp <= 0.0f ? 1.0f : CLAMP(_pelapsed[i] / ramp, 0.0f, 1.0f);
				const Vector2 nv = d * (a[0] + (a[1] - a[0]) * f);
				_vx[i] = nv.x;
				_vy[i] = nv.y;
			}
			break;
		}
		case 6: // speed_mul（每帧乘 → 复利/指数）
			_vx[i] = v.x * a[0];
			_vy[i] = v.y * a[0];
			break;
		case 7: // set_heading (move) —— 同时改「朝向」
			_apply_set_heading(i, a, player, boss, has_boss, enemies);
			break;
		case 8: // set_speed
			_apply_set_speed(i, a);
			break;
		case 9: { // V18 position —— 位置来源统一 op（mode 0=PHASE_START / 1=ANCHOR）
			// 布局：[mode, anchor_id, off.x, off.y, angle, speed, flags, initial, slot, base_sx, base_sy]
			const int mode = (int)a[0];
			const int slot = (int)a[8];
			const float angle = a[4];
			const float speed = a[5];
			const uint32_t bit = 1u << (slot & 31);
			Vector2 base;
			if (mode == 0) { // PHASE_START：基准 = 本弹相位起点（row 级；记进 base 槽）
				const int bx = (int)a[9];
				const int by = (int)a[10];
				if (_pslot_fresh[i] & bit) {
					slots[bx] = _x[i];
					slots[by] = _y[i];
					slots[slot] = a[7];
					_pslot_fresh[i] &= ~bit;
				} else {
					slots[slot] = slots[slot] + speed * dt;
				}
				base = Vector2(slots[bx], slots[by]);
			} else { // ANCHOR：基准由宿主解析成 program 级 base（缺省退回 player + offset）
				base = player + Vector2(a[2], a[3]);
				if (prog >= 0 && prog < p_anchor_base.size()) { base = p_anchor_base[prog]; }
				if (_pslot_fresh[i] & bit) {
					slots[slot] = a[7];
					_pslot_fresh[i] &= ~bit;
				} else {
					slots[slot] = slots[slot] + speed * dt;
				}
			}
			const float adir_x = sin(angle);
			const float adir_y = -cos(angle);
			_x[i] = base.x + adir_x * slots[slot];
			_y[i] = base.y + adir_y * slots[slot];
			// V19：位置 op 只写位置；render_heading 走独立渲染朝向通道，不再借道 velocity。
			if (mode == 1 && (((int)a[6] & 2) != 0)) {
				_render_rot[i] = std::atan2(adir_y, adir_x);
			}
			break;
		}
		default:
			break;
	}
}

bool DanmakuStore::_check_until(int i, float *slots, int ins, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies) {
	const int op = _p_ops[ins];
	const float *a = &_p_args[ins * OPS_ARGS];
	// V6：通用节流头 [every, every_ticks]（所有条件一致；先帧门控，再秒节流）。
	const int et = (int)a[1];
	if (et > 0 && _ptick[i] % et != 0) { return false; }
	if (a[0] > 0.0f) {
		if (_pelapsed[i] < _pnext[i]) { return false; }
		_pnext[i] = _pelapsed[i] + a[0];
	}
	switch (op) {
		case 20: // never
			return false;
		case 21: // elapsed
			return _pelapsed[i] >= a[2];
		case 22: { // near
			bool ok = false;
			const Vector2 from(_x[i], _y[i]);
			const Vector2 tp = _target_pos((int)a[2], from, player, boss, has_boss, enemies, ok);
			if (!ok) { return false; }
			return from.distance_to(tp) < a[3];
		}
		case 23: { // at_wall（纯谓词：只输出相位结束落点，不改弹自身位置）
			const int mask = (int)a[2];
			const Vector2 pos(_x[i], _y[i]);
			Vector2 cl = pos;
			if ((mask & 1) && pos.x <= _field_left) { cl.x = _field_left; }
			else if ((mask & 2) && pos.x >= _field_right) { cl.x = _field_right; }
			if ((mask & 4) && pos.y <= _field_top) { cl.y = _field_top; }
			if (cl != pos) {
				_pendx[i] = cl.x;
				_pendy[i] = cl.y;
				_phasend[i] = 1;
				return true;
			}
			return false;
		}
		case 24: { // state
			const int si = (int)a[2];
			if (si < 0 || si >= SLOT_STRIDE) { return false; }   // V8：slot 边界守卫
			const float sv = slots[si];
			return (int)a[3] == 0 ? sv >= a[4] : sv <= a[4];
		}
		default:
			return false;
	}
}

void DanmakuStore::_exec_action(int i, int prog, float *slots, int ins, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies) {
	const int op = _p_ops[ins];
	const float *a = &_p_args[ins * OPS_ARGS];
	switch (op) {
		case 40: { // emit
			Vector2 at(_x[i], _y[i]);
			if ((int)a[6] == 1 && _phasend[i]) { at = Vector2(_pendx[i], _pendy[i]); }   // V7：at = AT_PHASE_END
			float speed = Vector2(_vx[i], _vy[i]).length();
			if (a[5] > 0.0f) { speed = a[5]; }
			const int dk = (int)a[1];
			const Vector2 dir = _resolve_dir(dk, (int)a[2], a[3], at, player, boss, has_boss, enemies, Vector2(_hx[i], _hy[i]), a[4], _draw_dir_rnd(dk));
			_ev_kind.push_back(0);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(at.x); _ev_y.push_back(at.y);
			_ev_dx.push_back(dir.x); _ev_dy.push_back(dir.y);
			_ev_val.push_back(speed);
			_ev_variant.push_back(0);
			break;
		}
		case 41: // sfx
			_ev_kind.push_back(1);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(0); _ev_y.push_back(0); _ev_dx.push_back(0); _ev_dy.push_back(0);
			_ev_val.push_back(a[1]);
			_ev_variant.push_back(0);
			break;
		case 42: // despawn
			_tick_dead.push_back(i);
			break;
		case 43: // set_heading (action) —— 同时改「朝向」（与 move case 7 同一实现）
			_apply_set_heading(i, a, player, boss, has_boss, enemies);
			break;
		case 44: // set_speed (action)（与 move case 8 同一实现）
			_apply_set_speed(i, a);
			break;
		case 45: // call
			_ev_kind.push_back(2);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(_x[i]); _ev_y.push_back(_y[i]);
			_ev_dx.push_back(0); _ev_dy.push_back(0); _ev_val.push_back(0);
			_ev_variant.push_back(0);
			break;
		case 46: { // V9：变体发射（显式抽一次定分支；两套方向各自解析）
			Vector2 at(_x[i], _y[i]);
			if ((int)a[9] == 1 && _phasend[i]) { at = Vector2(_pendx[i], _pendy[i]); }
			float speed = Vector2(_vx[i], _vy[i]).length();
			if (a[8] > 0.0f) { speed = a[8]; }
			const bool hit = _rng_float() < a[1];   // 显式一次抽取
			const int dk = (int)(hit ? a[2] : a[5]);
			const int tg = (int)(hit ? a[3] : a[6]);
			const float angle = hit ? a[4] : a[7];
			const Vector2 dir = _resolve_dir(dk, tg, angle, at, player, boss, has_boss, enemies, Vector2(_hx[i], _hy[i]), 0.0f, _draw_dir_rnd(dk));
			_ev_kind.push_back(0);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(at.x); _ev_y.push_back(at.y);
			_ev_dx.push_back(dir.x); _ev_dy.push_back(dir.y);
			_ev_val.push_back(speed);
			_ev_variant.push_back(hit ? 1 : 0);
			break;
		}
		default:
			break;
	}
}

void DanmakuStore::_run_behavior_pass(float dt, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchor_base) {
	_grid_dirty = true;
	_tick_dead.clear();
	_ev_kind.clear(); _ev_prog.clear(); _ev_local.clear(); _ev_bullet.clear();
	_ev_x.clear(); _ev_y.clear(); _ev_dx.clear(); _ev_dy.clear(); _ev_val.clear(); _ev_variant.clear();
	const int phase_total = _p_move_start.size();
	for (int i = 0; i < _count; ++i) {
		_render_rot[i] = (float)NAN;   // V19：每帧重置；只有 position(render_heading) 会设它
		const int prog = _program[i];
		if (prog < 0) { continue; }
		const int base = _p_phase_base[prog];
		const int next_base = (prog + 1 < _p_phase_base.size()) ? _p_phase_base[prog + 1] : phase_total;
		const int pc = next_base - base;
		const int ph = _pphase[i];
		if (ph < 0 || ph >= pc) { continue; }
		_ptick[i] += 1;
		_pelapsed[i] += dt;
		float *slots = &_pslots[i * SLOT_STRIDE];
		const int ms = _p_move_start[base + ph];
		const int mc = _p_move_count[base + ph];
		for (int k = 0; k < mc; ++k) {
			_exec_move(i, prog, slots, ms + k, dt, p_player, p_boss, p_has_boss, p_enemies, p_anchor_base);
		}
		if (_check_until(i, slots, _p_until[base + ph], p_player, p_boss, p_has_boss, p_enemies)) {
			const int as = _p_act_start[base + ph];
			const int ac = _p_act_count[base + ph];
			for (int k = 0; k < ac; ++k) {
				_exec_action(i, prog, slots, as + k, p_player, p_boss, p_has_boss, p_enemies);
			}
			_pphase[i] = ph + 1;
			_pelapsed[i] = 0.0f;
			_pnext[i] = 0.0f;
			_pslot_fresh[i] = 0xFFFFFFFFu;
			_phasend[i] = 0;
			for (int s = 0; s < SLOT_STRIDE; ++s) { slots[s] = 0.0f; }
		}
	}
}

Dictionary DanmakuStore::_events_dict() const {
	Dictionary out;
	PackedInt32Array kind, eprog, local, bullet, variant;
	PackedFloat32Array ex, ey, edx, edy, eval;
	for (size_t k = 0; k < _ev_kind.size(); ++k) {
		kind.push_back(_ev_kind[k]); eprog.push_back(_ev_prog[k]); local.push_back(_ev_local[k]); bullet.push_back(_ev_bullet[k]);
		ex.push_back(_ev_x[k]); ey.push_back(_ev_y[k]); edx.push_back(_ev_dx[k]); edy.push_back(_ev_dy[k]); eval.push_back(_ev_val[k]);
		variant.push_back(_ev_variant[k]);
	}
	out["kind"] = kind; out["eprog"] = eprog; out["local"] = local; out["bullet"] = bullet;
	out["x"] = ex; out["y"] = ey; out["dx"] = edx; out["dy"] = edy; out["val"] = eval;
	out["variant"] = variant;
	return out;
}

Dictionary DanmakuStore::behavior_tick(double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchor_base) {
	_run_behavior_pass((float)p_delta, p_player, p_boss, p_has_boss, p_enemies, p_anchor_base);
	std::sort(_tick_dead.begin(), _tick_dead.end(), std::greater<int>());
	for (int id : _tick_dead) {
		if (id >= 0 && id < _count) { _swap_remove(id); }
	}
	return _events_dict();
}

Dictionary DanmakuStore::behavior_batch(int p_count, const PackedVector2Array &p_pos, const PackedVector2Array &p_vel,
		const PackedFloat32Array &p_life, const PackedFloat32Array &p_fx,
		const PackedInt32Array &p_program, const PackedInt32Array &p_phase, const PackedInt32Array &p_tick,
		const PackedFloat32Array &p_elapsed, const PackedFloat32Array &p_slots,
		double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies,
		const PackedVector2Array &p_anchor_base) {
	const int n = MIN(p_count, MIN(p_pos.size(), p_vel.size()));
	_ensure_capacity(n);
	_count = n;
	for (int i = 0; i < _count; ++i) {
		_x[i] = p_pos[i].x; _y[i] = p_pos[i].y;
		_vx[i] = p_vel[i].x; _vy[i] = p_vel[i].y;
		{ const Vector2 h = p_vel[i] == Vector2() ? Vector2(0, 1) : p_vel[i].normalized(); _hx[i] = h.x; _hy[i] = h.y; }
		_life[i] = i < p_life.size() ? p_life[i] : 0.0f;
		_fx[i] = i < p_fx.size() ? p_fx[i] : 0.0f;
		_program[i] = i < p_program.size() ? p_program[i] : -1;
		_pphase[i] = i < p_phase.size() ? p_phase[i] : 0;
		_ptick[i] = i < p_tick.size() ? p_tick[i] : 0;
		_pelapsed[i] = i < p_elapsed.size() ? p_elapsed[i] : 0.0f;
		// batch 路径没有 set_program：新弹首帧（tick/phase 都为 0）把「不随数组传入」的
		// 内部状态初始化成 set_program 同款，否则会残留上一颗弹的值（anchor_drift 首帧漂移错、
		// near 节流错、at_wall 落点残留）。
		if (_ptick[i] == 0 && _pphase[i] == 0) {
			_pnext[i] = 0.0f; _pslot_fresh[i] = 0xFFFFFFFFu; _phasend[i] = 0;
			_pendx[i] = 0.0f; _pendy[i] = 0.0f;
		}
		for (int s = 0; s < SLOT_STRIDE; ++s) {
			const int k = i * SLOT_STRIDE + s;
			_pslots[k] = k < p_slots.size() ? p_slots[k] : 0.0f;
		}
	}
	_run_behavior_pass((float)p_delta, p_player, p_boss, p_has_boss, p_enemies, p_anchor_base);
	PackedVector2Array opos, ovel;
	PackedFloat32Array olife, ofx, oelapsed, oslots, orender;
	PackedInt32Array oprog, ophase, otick, odead;
	opos.resize(_count); ovel.resize(_count);
	olife.resize(_count); ofx.resize(_count); oelapsed.resize(_count);
	oprog.resize(_count); ophase.resize(_count); otick.resize(_count);
	oslots.resize(_count * SLOT_STRIDE);
	orender.resize(_count);
	for (int i = 0; i < _count; ++i) {
		opos[i] = Vector2(_x[i], _y[i]);
		ovel[i] = Vector2(_vx[i], _vy[i]);
		olife[i] = _life[i]; ofx[i] = _fx[i]; oelapsed[i] = _pelapsed[i];
		oprog[i] = _program[i]; ophase[i] = _pphase[i]; otick[i] = _ptick[i];
		orender[i] = _render_rot[i];
		for (int s = 0; s < SLOT_STRIDE; ++s) {
			oslots[i * SLOT_STRIDE + s] = _pslots[i * SLOT_STRIDE + s];
		}
	}
	for (int id : _tick_dead) { odead.push_back(id); }
	Dictionary out = _events_dict();
	out["positions"] = opos; out["velocities"] = ovel;
	out["life"] = olife; out["fx"] = ofx; out["elapsed"] = oelapsed;
	out["program"] = oprog; out["oprogram"] = oprog;
	out["phase"] = ophase; out["tick"] = otick; out["slots"] = oslots;
	out["render_rot"] = orender;
	out["dead"] = odead;
	return out;
}

PackedColorArray DanmakuStore::get_colors() const {
	PackedColorArray out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = _color[i]; }
	return out;
}

PackedInt32Array DanmakuStore::get_type_indices() const {
	PackedInt32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = _type[i]; }
	return out;
}

PackedInt32Array DanmakuStore::get_factions() const {
	PackedInt32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = _faction[i]; }
	return out;
}

// L3.5-4e：宿主 BulletSystem 的 `_faction` 是 PackedByteArray → 需要同型快照。
PackedByteArray DanmakuStore::get_factions_bytes() const {
	PackedByteArray out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = (unsigned char)_faction[i]; }
	return out;
}

// ═══ L3.5-1：判定几何（与 scripts/kernel/collision/hit_geometry.gd 1:1）═══
static bool _circle_rect(const Vector2 &center, float radius, const Vector2 &rect_center, float rot, const Vector2 &size) {
	const Vector2 local = (center - rect_center).rotated(-rot);
	const Vector2 half = size * 0.5f;
	const float dx = MAX(0.0f, ABS(local.x) - half.x);
	const float dy = MAX(0.0f, ABS(local.y) - half.y);
	return dx * dx + dy * dy <= radius * radius;
}

static float _hit_rot(const Vector2 &vel, unsigned char follow, float diroff) {
	if (follow && vel != Vector2()) {
		return vel.angle() + diroff;
	}
	return 0.0f;
}

void DanmakuStore::set_hitbox(int p_id, float p_radius, const Vector2 &p_offset, const Vector2 &p_size, bool p_follow_dir, float p_dir_offset) {
	_grid_dirty = true;
	_hb_radius[p_id] = p_radius;
	_hb_offx[p_id] = p_offset.x;
	_hb_offy[p_id] = p_offset.y;
	_hb_sizex[p_id] = p_size.x;
	_hb_sizey[p_id] = p_size.y;
	_hb_follow[p_id] = p_follow_dir ? 1 : 0;
	_hb_diroff[p_id] = p_dir_offset;
}

bool DanmakuStore::hit_test(int p_id, const Vector2 &p_center, float p_radius) const {
	if (_fx[p_id] > 0.0f) { return false; }
	if (_type[p_id] < 0) { return false; }
	Vector2 hit(_x[p_id], _y[p_id]);
	const float rot = _hit_rot(Vector2(_vx[p_id], _vy[p_id]), _hb_follow[p_id], _hb_diroff[p_id]);
	if (_hb_offx[p_id] != 0.0f || _hb_offy[p_id] != 0.0f) {
		hit += Vector2(_hb_offx[p_id], _hb_offy[p_id]).rotated(rot);
	}
	const float sx = _hb_sizex[p_id];
	const float sy = _hb_sizey[p_id];
	if (sx == 0.0f && sy == 0.0f) {
		const Vector2 d = p_center - hit;
		const float rr = p_radius + _hb_radius[p_id];
		return d.length_squared() <= rr * rr;
	}
	return _circle_rect(p_center, p_radius, hit, rot, Vector2(sx, sy));
}

// L3.5-4a：对所有（阵营匹配、已出生的）弹 × 目标圆做 narrow 判定，一次跨界返回全部命中对。
// p_faction < 0 = 不限阵营。配合「原生权威存储」：几何在原生 O(弹×目标) 跑完，
// GDScript 只处理命中后的宿主规则（伤害 / RNG / 记忆 / 音效），避免逐弹跨界。
PackedInt32Array DanmakuStore::overlap_pairs(int p_faction, const PackedVector2Array &p_targets, const PackedFloat32Array &p_radii) const {
	PackedInt32Array out;
	const int tn = MIN(p_targets.size(), p_radii.size());
	if (tn == 0 || _count == 0) { return out; }
	for (int i = 0; i < _count; ++i) {
		if (p_faction >= 0 && _faction[i] != p_faction) { continue; }
		if (_fx[i] > 0.0f || _type[i] < 0) { continue; }
		for (int t = 0; t < tn; ++t) {
			if (hit_test(i, p_targets[t], p_radii[t])) {
				out.push_back(i);
				out.push_back(t);
			}
		}
	}
	return out;
}

// ═══ L3.5-4b-pre：宽相 uniform grid（与 GDScript `BulletSystem` 同参数/同语义）═══

void DanmakuStore::_ensure_broadphase() const {
	if (!_grid_dirty) { return; }
	_grid_dirty = false;
	_rebuild_broadphase();
}

void DanmakuStore::_rebuild_broadphase() const {
	_grid_active = false;
	const int count = _count;
	if (count < GRID_MIN_COUNT) { return; }
	int gx;
	int gy;
	Vector2 origin;
	if (_cull.size.x > 0.0f && _cull.size.y > 0.0f) {
		origin = _cull.position;
		gx = MAX(1, (int)std::ceil(_cull.size.x / GRID_CELL) + 1);
		gy = MAX(1, (int)std::ceil(_cull.size.y / GRID_CELL) + 1);
	} else {
		Vector2 minp(INFINITY, INFINITY);
		Vector2 maxp(-INFINITY, -INFINITY);
		for (int i = 0; i < count; ++i) {
			minp.x = MIN(minp.x, _x[i]); minp.y = MIN(minp.y, _y[i]);
			maxp.x = MAX(maxp.x, _x[i]); maxp.y = MAX(maxp.y, _y[i]);
		}
		origin = minp;
		gx = MAX(1, (int)std::floor((maxp.x - minp.x) / GRID_CELL) + 1);
		gy = MAX(1, (int)std::floor((maxp.y - minp.y) / GRID_CELL) + 1);
	}
	if (gx * gy > GRID_MAX_CELLS) { return; }   // 坐标异常 / 剔除区过大：退回线性
	_grid_origin = origin;
	_grid_gx = gx;
	_grid_gy = gy;
	_grid_head.assign(gx * gy, -1);
	_grid_prev.assign(count, -1);
	_grid_next.assign(count, -1);
	_grid_cell_of.assign(count, -1);
	float max_bound = 0.0f;
	for (int i = 0; i < count; ++i) {
		const float b = (_hb_sizex[i] != 0.0f || _hb_sizey[i] != 0.0f)
			? Vector2(_hb_sizex[i], _hb_sizey[i]).length() * 0.5f + Vector2(_hb_offx[i], _hb_offy[i]).length()
			: _hb_radius[i];
		max_bound = MAX(max_bound, b);
		const int ci = _cell_index(i);
		_grid_cell_of[i] = ci;
		_grid_prev[i] = -1;
		_grid_next[i] = _grid_head[ci];
		if (_grid_head[ci] >= 0) { _grid_prev[_grid_head[ci]] = i; }
		_grid_head[ci] = i;
	}
	_grid_max_bound = max_bound;
	_grid_active = true;
}

int DanmakuStore::_cell_index(int p_i) const {
	const int cx = CLAMP((int)std::floor((_x[p_i] - _grid_origin.x) / GRID_CELL), 0, _grid_gx - 1);
	const int cy = CLAMP((int)std::floor((_y[p_i] - _grid_origin.y) / GRID_CELL), 0, _grid_gy - 1);
	return cy * _grid_gx + cx;
}

PackedInt32Array DanmakuStore::_query_circle_grid(const Vector2 &p_center, float p_search_radius) const {
	PackedInt32Array out;
	const float reach = p_search_radius + _grid_max_bound;
	const int x0 = CLAMP((int)std::floor((p_center.x - reach - _grid_origin.x) / GRID_CELL), 0, _grid_gx - 1);
	const int x1 = CLAMP((int)std::floor((p_center.x + reach - _grid_origin.x) / GRID_CELL), 0, _grid_gx - 1);
	const int y0 = CLAMP((int)std::floor((p_center.y - reach - _grid_origin.y) / GRID_CELL), 0, _grid_gy - 1);
	const int y1 = CLAMP((int)std::floor((p_center.y + reach - _grid_origin.y) / GRID_CELL), 0, _grid_gy - 1);
	for (int cy = y0; cy <= y1; ++cy) {
		const int row_base = cy * _grid_gx;
		for (int cx = x0; cx <= x1; ++cx) {
			int i = _grid_head[row_base + cx];
			while (i >= 0) {
				if (hit_test(i, p_center, p_search_radius)) { out.push_back(i); }
				i = _grid_next[i];
			}
		}
	}
	return out;
}

bool DanmakuStore::is_broadphase_active() const { return _grid_active; }

PackedInt32Array DanmakuStore::query_circle(const Vector2 &p_center, float p_search_radius) const {
	PackedInt32Array out;
	if (_count == 0) { return out; }
	_ensure_broadphase();
	if (_grid_active) { return _query_circle_grid(p_center, p_search_radius); }
	for (int i = 0; i < _count; ++i) {
		if (_fx[i] > 0.0f) { continue; }
		Vector2 hit(_x[i], _y[i]);
		const bool special = _hb_offx[i] != 0.0f || _hb_offy[i] != 0.0f || _hb_sizex[i] != 0.0f || _hb_sizey[i] != 0.0f;
		if (special) {
			const float rot = _hit_rot(Vector2(_vx[i], _vy[i]), _hb_follow[i], _hb_diroff[i]);
			if (_hb_offx[i] != 0.0f || _hb_offy[i] != 0.0f) {
				hit += Vector2(_hb_offx[i], _hb_offy[i]).rotated(rot);
			}
			if (_hb_sizex[i] != 0.0f || _hb_sizey[i] != 0.0f) {
				if (_circle_rect(p_center, p_search_radius, hit, rot, Vector2(_hb_sizex[i], _hb_sizey[i]))) {
					out.push_back(i);
				}
				continue;
			}
		}
		const Vector2 d = hit - p_center;
		const float r = p_search_radius + _hb_radius[i];
		if (d.length_squared() <= r * r) {
			out.push_back(i);
		}
	}
	return out;
}

bool DanmakuStore::is_grazed(int p_id) const { return _grazed[p_id] != 0; }
void DanmakuStore::mark_grazed(int p_id) { _grazed[p_id] = 1; }

DanmakuStore::DanmakuStore() {}
DanmakuStore::~DanmakuStore() {}