#include "danmaku_store.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform2d.hpp>

using namespace godot;

void DanmakuStore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "capacity", "cull"), &DanmakuStore::setup);
	ClassDB::bind_method(D_METHOD("spawn", "pos", "vel", "type", "faction", "color"), &DanmakuStore::spawn, DEFVAL(0), DEFVAL(0), DEFVAL(Color(1, 1, 1, 1)));
	ClassDB::bind_method(D_METHOD("spawn_batch", "pos", "vel", "type", "faction", "color"), &DanmakuStore::spawn_batch);
	ClassDB::bind_method(D_METHOD("integrate", "delta"), &DanmakuStore::integrate);
	ClassDB::bind_method(D_METHOD("get_active_count"), &DanmakuStore::get_active_count);
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

DanmakuStore::DanmakuStore() {}
DanmakuStore::~DanmakuStore() {}