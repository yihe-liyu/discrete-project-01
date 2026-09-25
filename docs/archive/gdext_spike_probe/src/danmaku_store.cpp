#include "danmaku_store.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform2d.hpp>

using namespace godot;

void DanmakuStore::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "capacity", "cull"), &DanmakuStore::setup);
	ClassDB::bind_method(D_METHOD("spawn", "pos", "vel"), &DanmakuStore::spawn);
	ClassDB::bind_method(D_METHOD("integrate", "delta"), &DanmakuStore::integrate);
	ClassDB::bind_method(D_METHOD("get_active_count"), &DanmakuStore::get_active_count);
	ClassDB::bind_method(D_METHOD("get_position", "id"), &DanmakuStore::get_position);
	ClassDB::bind_method(D_METHOD("fill_multimesh", "mm", "color"), &DanmakuStore::fill_multimesh);
}

void DanmakuStore::setup(int p_capacity, const Rect2 &p_cull) {
	_cull = p_cull;
	_x.assign(p_capacity, 0.0f);
	_y.assign(p_capacity, 0.0f);
	_vx.assign(p_capacity, 0.0f);
	_vy.assign(p_capacity, 0.0f);
	_count = 0;
}

int DanmakuStore::spawn(const Vector2 &p_pos, const Vector2 &p_vel) {
	if (_count >= (int)_x.size()) {
		return -1;
	}
	_x[_count] = p_pos.x;
	_y[_count] = p_pos.y;
	_vx[_count] = p_vel.x;
	_vy[_count] = p_vel.y;
	return _count++;
}

void DanmakuStore::integrate(double p_delta) {
	const float dt = (float)p_delta;
	const bool cull = _cull.has_area();
	const Rect2 grown = _cull.grow(_margin);
	for (int i = _count - 1; i >= 0; --i) {
		_x[i] += _vx[i] * dt;
		_y[i] += _vy[i] * dt;
		if (cull && !grown.has_point(Vector2(_x[i], _y[i]))) {
			--_count;
			if (i != _count) {
				_x[i] = _x[_count];
				_y[i] = _y[_count];
				_vx[i] = _vx[_count];
				_vy[i] = _vy[_count];
			}
		}
	}
}

int DanmakuStore::get_active_count() const {
	return _count;
}

Vector2 DanmakuStore::get_position(int p_id) const {
	return Vector2(_x[p_id], _y[p_id]);
}

void DanmakuStore::fill_multimesh(const Ref<MultiMesh> &p_mm, const Color &p_color) const {
	if (p_mm.is_null()) {
		return;
	}
	for (int i = 0; i < _count; ++i) {
		p_mm->set_instance_transform_2d(i, Transform2D(0.0f, Vector2(_x[i], _y[i])));
		p_mm->set_instance_color(i, p_color);
	}
}

DanmakuStore::DanmakuStore() {}
DanmakuStore::~DanmakuStore() {}
