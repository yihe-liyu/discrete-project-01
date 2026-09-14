#include "danmaku_store.h"
#include <godot_cpp/core/class_db.hpp>
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
	ClassDB::bind_method(D_METHOD("behavior_batch", "count", "positions", "velocities", "life", "fx", "program", "phase", "tick", "elapsed", "slots", "delta", "player", "boss", "has_boss", "enemies"), &DanmakuStore::behavior_batch);
	ClassDB::bind_method(D_METHOD("get_position", "id"), &DanmakuStore::get_position);
	ClassDB::bind_method(D_METHOD("get_velocity", "id"), &DanmakuStore::get_velocity);
	ClassDB::bind_method(D_METHOD("get_positions"), &DanmakuStore::get_positions);
	ClassDB::bind_method(D_METHOD("get_velocities"), &DanmakuStore::get_velocities);
	ClassDB::bind_method(D_METHOD("get_type", "id"), &DanmakuStore::get_type);
	ClassDB::bind_method(D_METHOD("get_faction", "id"), &DanmakuStore::get_faction);
	ClassDB::bind_method(D_METHOD("get_color", "id"), &DanmakuStore::get_color);
	ClassDB::bind_method(D_METHOD("fill_multimesh", "mm"), &DanmakuStore::fill_multimesh);
	ClassDB::bind_method(D_METHOD("set_margin", "margin"), &DanmakuStore::set_margin);
	ClassDB::bind_method(D_METHOD("set_default_life", "life"), &DanmakuStore::set_default_life);
	ClassDB::bind_method(D_METHOD("set_hitbox", "id", "radius", "offset", "size", "follow_dir", "dir_offset"), &DanmakuStore::set_hitbox);
	ClassDB::bind_method(D_METHOD("hit_test", "id", "center", "radius"), &DanmakuStore::hit_test);
	ClassDB::bind_method(D_METHOD("query_circle", "center", "radius"), &DanmakuStore::query_circle);
	ClassDB::bind_method(D_METHOD("is_grazed", "id"), &DanmakuStore::is_grazed);
	ClassDB::bind_method(D_METHOD("mark_grazed", "id"), &DanmakuStore::mark_grazed);
	ClassDB::bind_method(D_METHOD("set_field", "left", "right", "top"), &DanmakuStore::set_field);
	ClassDB::bind_method(D_METHOD("register_program", "ops", "args", "move_start", "move_count", "until", "act_start", "act_count", "phase_count", "slots"), &DanmakuStore::register_program);
	ClassDB::bind_method(D_METHOD("set_program", "id", "program"), &DanmakuStore::set_program);
	ClassDB::bind_method(D_METHOD("get_program", "id"), &DanmakuStore::get_program);
	ClassDB::bind_method(D_METHOD("behavior_tick", "delta", "player", "boss", "has_boss", "enemies"), &DanmakuStore::behavior_tick);
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
	ClassDB::bind_method(D_METHOD("get_capacity"), &DanmakuStore::get_capacity);
	ClassDB::bind_method(D_METHOD("integrate_batch", "count", "positions", "velocities", "life_left", "fx_phase", "timers", "delta", "cull_pos", "cull_size", "margin"), &DanmakuStore::integrate_batch);
}

void DanmakuStore::setup(int p_capacity, const Rect2 &p_cull) {
	_capacity = p_capacity;
	_cull = p_cull;
	_x.assign(p_capacity, 0.0f);
	_y.assign(p_capacity, 0.0f);
	_vx.assign(p_capacity, 0.0f);
	_vy.assign(p_capacity, 0.0f);
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
	_pfresh.assign(p_capacity, 1);
	_phasend.assign(p_capacity, 0);
	_hb_radius.assign(p_capacity, 0.0f);
	_hb_offx.assign(p_capacity, 0.0f);
	_hb_offy.assign(p_capacity, 0.0f);
	_hb_sizex.assign(p_capacity, 0.0f);
	_hb_sizey.assign(p_capacity, 0.0f);
	_hb_diroff.assign(p_capacity, 0.0f);
	_hb_follow.assign(p_capacity, 0);
	_grazed.assign(p_capacity, 0);
	_count = 0;
}

int DanmakuStore::spawn(const Vector2 &p_pos, const Vector2 &p_vel, int p_type, int p_faction, const Color &p_color) {
	if (_count >= _capacity) {
		return -1;
	}
	const int i = _count;
	_x[i] = p_pos.x;
	_y[i] = p_pos.y;
	_vx[i] = p_vel.x;
	_vy[i] = p_vel.y;
	_type[i] = p_type;
	_faction[i] = p_faction;
	_color[i] = p_color;
	_life[i] = _default_life;
	_fx[i] = 0.0f;
	_timer[i] = 0.0f;
	return _count++;
}

int DanmakuStore::spawn_batch(const PackedVector2Array &p_pos, const PackedVector2Array &p_vel, const PackedInt32Array &p_type, const PackedInt32Array &p_faction, const PackedColorArray &p_color) {
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
		_type[i] = k < p_type.size() ? p_type[k] : 0;
		_faction[i] = k < p_faction.size() ? p_faction[k] : 0;
		_color[i] = k < p_color.size() ? p_color[k] : Color(1, 1, 1, 1);
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
	_type.resize(p_n); _faction.resize(p_n); _color.resize(p_n);
	_life.resize(p_n); _fx.resize(p_n); _timer.resize(p_n);
	_program.resize(p_n); _pphase.resize(p_n); _ptick.resize(p_n);
	_pelapsed.resize(p_n); _pnext.resize(p_n); _pendx.resize(p_n); _pendy.resize(p_n);
	_pslots.resize(p_n * SLOT_STRIDE);
	_pfresh.resize(p_n); _phasend.resize(p_n);
	_hb_radius.resize(p_n); _hb_offx.resize(p_n); _hb_offy.resize(p_n);
	_hb_sizex.resize(p_n); _hb_sizey.resize(p_n); _hb_diroff.resize(p_n);
	_hb_follow.resize(p_n); _grazed.resize(p_n);
}

// swap-with-last 回收：把尾行整行搬进空槽（新增字段必须在这里同步）。
void DanmakuStore::_swap_remove(int p_id) {
	const int last = --_count;
	if (p_id == last) {
		return;
	}
	_x[p_id] = _x[last];
	_y[p_id] = _y[last];
	_vx[p_id] = _vx[last];
	_vy[p_id] = _vy[last];
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
	_pfresh[p_id] = _pfresh[last];
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
}

// 完整积分循环：寿命 / 出生相位 / 位移 / 计时 / 剔除 —— 与 scripts/kernel/bullet_system.gd 1:1。
void DanmakuStore::integrate(double p_delta) {
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

void DanmakuStore::set_margin(float p_margin) { _margin = p_margin; }
void DanmakuStore::set_default_life(float p_life) { _default_life = p_life; }
void DanmakuStore::set_field(float p_left, float p_right, float p_top) { _field_left = p_left; _field_right = p_right; _field_top = p_top; }
int DanmakuStore::get_capacity() const { return _capacity; }

void DanmakuStore::clear() {
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
void DanmakuStore::set_position(int p_id, const Vector2 &p_pos) { _x[p_id] = p_pos.x; _y[p_id] = p_pos.y; }
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
	_pfresh[p_id] = 1;
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

Vector2 DanmakuStore::_resolve_dir(int p_dk, int p_tg, float angle, const Vector2 &pos, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies) {
	if (p_dk == 0) {
		return Vector2(sin(angle), -cos(angle));
	}
	bool ok = false;
	const Vector2 tp = _target_pos(p_tg, pos, player, boss, has_boss, enemies, ok);
	Vector2 base = Vector2(0, 1);
	if (ok) {
		base = (p_dk == 1 ? (tp - pos) : (pos - tp)).normalized();
	}
	return base.rotated(angle);
}

void DanmakuStore::_exec_move(int i, float *slots, int ins, float dt, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies) {
	const int op = _p_ops[ins];
	const float *a = &_p_args[ins * OPS_ARGS];
	Vector2 v(_vx[i], _vy[i]);
	switch (op) {
		case 1: // accel_world
			_vx[i] = v.x + a[0] * dt;
			_vy[i] = v.y + a[1] * dt;
			break;
		case 2: { // accel_heading
			const Vector2 dir = v.normalized();
			if (dir != Vector2()) {
				_vx[i] = v.x + dir.x * a[0] * dt;
				_vy[i] = v.y + dir.y * a[0] * dt;
			}
			break;
		}
		case 3: { // rotate
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
			const Vector2 r = v.rotated(step);
			_vx[i] = r.x;
			_vy[i] = r.y;
			break;
		}
		case 4: { // steer
			const Vector2 cur = v.normalized();
			if (cur == Vector2()) { break; }
			const float ramp = a[2];
			const float factor = ramp <= 0.0f ? 1.0f : CLAMP(_pelapsed[i] / ramp, 0.0f, 1.0f);
			Vector2 rotated = cur;
			const float su = a[6];
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
			const float sf = a[4];
			const float sp2 = sf + (a[5] - sf) * factor;
			const Vector2 nv = std::isnan(sf) ? rotated * v.length() : rotated * sp2;
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
		case 6: // scale_speed
			_vx[i] = v.x * a[0];
			_vy[i] = v.y * a[0];
			break;
		case 7: { // set_heading (move)
			const Vector2 d = _resolve_dir((int)a[0], (int)a[1], a[2], Vector2(_x[i], _y[i]), player, boss, has_boss, enemies);
			if (d != Vector2()) {
				const float sp = v.length();
				_vx[i] = d.x * sp;
				_vy[i] = d.y * sp;
			}
			break;
		}
		case 8: { // set_speed
			const Vector2 d = v.normalized();
			if (d != Vector2()) {
				_vx[i] = d.x * a[0];
				_vy[i] = d.y * a[0];
			}
			break;
		}
		case 9: { // anchor_drift
			const int si = (int)a[7];
			Vector2 base = player + Vector2(a[1], a[2]);
			const float adir_x = sin(a[3]);
			const float adir_y = -cos(a[3]);
			if (_pfresh[i]) {
				slots[si] = a[6];
				_pfresh[i] = 0;
			} else {
				slots[si] = slots[si] + a[4] * dt;
			}
			_x[i] = base.x + adir_x * slots[si];
			_y[i] = base.y + adir_y * slots[si];
			if (((int)a[5] & 2) != 0) {
				_vx[i] = adir_x;
				_vy[i] = adir_y;
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
	switch (op) {
		case 20: // never
			return false;
		case 21: // elapsed
			return _pelapsed[i] >= a[0];
		case 22: { // near
			const int et = (int)a[3];
			if (et > 0 && _ptick[i] % et != 0) { return false; }
			if (a[2] > 0.0f) {
				if (_pelapsed[i] < _pnext[i]) { return false; }
				_pnext[i] = _pelapsed[i] + a[2];
			}
			bool ok = false;
			const Vector2 from(_x[i], _y[i]);
			const Vector2 tp = _target_pos((int)a[0], from, player, boss, has_boss, enemies, ok);
			if (!ok) { return false; }
			return from.distance_to(tp) < a[1];
		}
		case 23: { // at_wall
			const int mask = (int)a[0];
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
			const float sv = slots[(int)a[0]];
			return (int)a[1] == 0 ? sv >= a[2] : sv <= a[2];
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
			if (a[5] > 0.5f && _phasend[i]) { at = Vector2(_pendx[i], _pendy[i]); }
			float speed = Vector2(_vx[i], _vy[i]).length();
			if (a[4] > 0.0f) { speed = a[4]; }
			const Vector2 dir = _resolve_dir((int)a[1], (int)a[2], a[3], at, player, boss, has_boss, enemies);
			_ev_kind.push_back(0);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(at.x); _ev_y.push_back(at.y);
			_ev_dx.push_back(dir.x); _ev_dy.push_back(dir.y);
			_ev_val.push_back(speed);
			break;
		}
		case 41: // sfx
			_ev_kind.push_back(1);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(0); _ev_y.push_back(0); _ev_dx.push_back(0); _ev_dy.push_back(0);
			_ev_val.push_back(a[1]);
			break;
		case 42: // despawn
			_tick_dead.push_back(i);
			break;
		case 43: { // set_heading (action)
			const Vector2 d = _resolve_dir((int)a[0], (int)a[1], a[2], Vector2(_x[i], _y[i]), player, boss, has_boss, enemies);
			if (d != Vector2()) {
				const float sp = Vector2(_vx[i], _vy[i]).length();
				_vx[i] = d.x * sp;
				_vy[i] = d.y * sp;
			}
			break;
		}
		case 44: { // set_speed (action)
			const Vector2 d = Vector2(_vx[i], _vy[i]).normalized();
			if (d != Vector2()) {
				_vx[i] = d.x * a[0];
				_vy[i] = d.y * a[0];
			}
			break;
		}
		case 45: // call
			_ev_kind.push_back(2);
			_ev_prog.push_back(prog);
			_ev_local.push_back((int)a[0]);
			_ev_bullet.push_back(i);
			_ev_x.push_back(_x[i]); _ev_y.push_back(_y[i]);
			_ev_dx.push_back(0); _ev_dy.push_back(0); _ev_val.push_back(0);
			break;
		default:
			break;
	}
}

void DanmakuStore::_run_behavior_pass(float dt, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies) {
	_tick_dead.clear();
	_ev_kind.clear(); _ev_prog.clear(); _ev_local.clear(); _ev_bullet.clear();
	_ev_x.clear(); _ev_y.clear(); _ev_dx.clear(); _ev_dy.clear(); _ev_val.clear();
	const int phase_total = _p_move_start.size();
	for (int i = 0; i < _count; ++i) {
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
			_exec_move(i, slots, ms + k, dt, p_player, p_boss, p_has_boss, p_enemies);
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
			_pfresh[i] = 1;
			_phasend[i] = 0;
			for (int s = 0; s < SLOT_STRIDE; ++s) { slots[s] = 0.0f; }
		}
	}
}

Dictionary DanmakuStore::_events_dict() const {
	Dictionary out;
	PackedInt32Array kind, eprog, local, bullet;
	PackedFloat32Array ex, ey, edx, edy, eval;
	for (size_t k = 0; k < _ev_kind.size(); ++k) {
		kind.push_back(_ev_kind[k]); eprog.push_back(_ev_prog[k]); local.push_back(_ev_local[k]); bullet.push_back(_ev_bullet[k]);
		ex.push_back(_ev_x[k]); ey.push_back(_ev_y[k]); edx.push_back(_ev_dx[k]); edy.push_back(_ev_dy[k]); eval.push_back(_ev_val[k]);
	}
	out["kind"] = kind; out["eprog"] = eprog; out["local"] = local; out["bullet"] = bullet;
	out["x"] = ex; out["y"] = ey; out["dx"] = edx; out["dy"] = edy; out["val"] = eval;
	return out;
}

Dictionary DanmakuStore::behavior_tick(double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies) {
	_run_behavior_pass((float)p_delta, p_player, p_boss, p_has_boss, p_enemies);
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
		double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies) {
	const int n = MIN(p_count, MIN(p_pos.size(), p_vel.size()));
	_ensure_capacity(n);
	_count = n;
	for (int i = 0; i < _count; ++i) {
		_x[i] = p_pos[i].x; _y[i] = p_pos[i].y;
		_vx[i] = p_vel[i].x; _vy[i] = p_vel[i].y;
		_life[i] = i < p_life.size() ? p_life[i] : 0.0f;
		_fx[i] = i < p_fx.size() ? p_fx[i] : 0.0f;
		_program[i] = i < p_program.size() ? p_program[i] : -1;
		_pphase[i] = i < p_phase.size() ? p_phase[i] : 0;
		_ptick[i] = i < p_tick.size() ? p_tick[i] : 0;
		_pelapsed[i] = i < p_elapsed.size() ? p_elapsed[i] : 0.0f;
		for (int s = 0; s < SLOT_STRIDE; ++s) {
			const int k = i * SLOT_STRIDE + s;
			_pslots[k] = k < p_slots.size() ? p_slots[k] : 0.0f;
		}
	}
	_run_behavior_pass((float)p_delta, p_player, p_boss, p_has_boss, p_enemies);
	PackedVector2Array opos, ovel;
	PackedFloat32Array olife, ofx, oelapsed, oslots;
	PackedInt32Array oprog, ophase, otick, odead;
	opos.resize(_count); ovel.resize(_count);
	olife.resize(_count); ofx.resize(_count); oelapsed.resize(_count);
	oprog.resize(_count); ophase.resize(_count); otick.resize(_count);
	oslots.resize(_count * SLOT_STRIDE);
	for (int i = 0; i < _count; ++i) {
		opos[i] = Vector2(_x[i], _y[i]);
		ovel[i] = Vector2(_vx[i], _vy[i]);
		olife[i] = _life[i]; ofx[i] = _fx[i]; oelapsed[i] = _pelapsed[i];
		oprog[i] = _program[i]; ophase[i] = _pphase[i]; otick[i] = _ptick[i];
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

PackedInt32Array DanmakuStore::query_circle(const Vector2 &p_center, float p_search_radius) const {
	PackedInt32Array out;
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