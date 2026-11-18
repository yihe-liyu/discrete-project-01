#include "danmaku_store.h"
#include "build_stamp.h"
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
	ClassDB::bind_method(D_METHOD("get_position", "id"), &DanmakuStore::get_position);
	ClassDB::bind_method(D_METHOD("get_velocity", "id"), &DanmakuStore::get_velocity);
	ClassDB::bind_method(D_METHOD("get_forward", "id"), &DanmakuStore::get_forward);
	ClassDB::bind_method(D_METHOD("set_forward", "id", "fwd"), &DanmakuStore::set_forward);
	ClassDB::bind_method(D_METHOD("get_positions"), &DanmakuStore::get_positions);
	ClassDB::bind_method(D_METHOD("get_velocities"), &DanmakuStore::get_velocities);
	ClassDB::bind_method(D_METHOD("get_type", "id"), &DanmakuStore::get_type);
	ClassDB::bind_method(D_METHOD("get_type_index", "id"), &DanmakuStore::get_type_index);
	ClassDB::bind_method(D_METHOD("get_faction", "id"), &DanmakuStore::get_faction);
	ClassDB::bind_method(D_METHOD("get_color", "id"), &DanmakuStore::get_color);
	ClassDB::bind_method(D_METHOD("set_color", "id", "color"), &DanmakuStore::set_color);
	ClassDB::bind_method(D_METHOD("get_render_rot", "id"), &DanmakuStore::get_render_rot);
	ClassDB::bind_method(D_METHOD("set_render_rot", "id", "rot"), &DanmakuStore::set_render_rot);
	ClassDB::bind_method(D_METHOD("get_hitbox", "id"), &DanmakuStore::get_hitbox);
	ClassDB::bind_method(D_METHOD("get_wrap", "id"), &DanmakuStore::get_wrap);
	ClassDB::bind_method(D_METHOD("get_spin_rot", "id"), &DanmakuStore::get_spin_rot);
	ClassDB::bind_method(D_METHOD("set_spin_rot", "id", "rot"), &DanmakuStore::set_spin_rot);
	ClassDB::bind_method(D_METHOD("get_elapsed", "id"), &DanmakuStore::get_elapsed);
	ClassDB::bind_method(D_METHOD("get_behavior_state", "id"), &DanmakuStore::get_behavior_state);
	ClassDB::bind_method(D_METHOD("get_behavior_params", "id"), &DanmakuStore::get_behavior_params);
	ClassDB::bind_method(D_METHOD("fill_multimesh", "mm"), &DanmakuStore::fill_multimesh);
	ClassDB::bind_method(D_METHOD("reserve", "n"), &DanmakuStore::reserve);
	ClassDB::bind_method(D_METHOD("set_cull", "cull"), &DanmakuStore::set_cull);
	ClassDB::bind_method(D_METHOD("set_margin", "margin"), &DanmakuStore::set_margin);
	ClassDB::bind_method(D_METHOD("set_out_grace", "id", "grace"), &DanmakuStore::set_out_grace);
	ClassDB::bind_method(D_METHOD("set_wrap", "id", "mask"), &DanmakuStore::set_wrap);
	ClassDB::bind_method(D_METHOD("get_out_grace", "id"), &DanmakuStore::get_out_grace);
	ClassDB::bind_method(D_METHOD("set_default_life", "life"), &DanmakuStore::set_default_life);
	ClassDB::bind_method(D_METHOD("set_hitbox", "id", "radius", "offset", "size", "follow_dir", "dir_offset"), &DanmakuStore::set_hitbox);
	ClassDB::bind_method(D_METHOD("hit_test", "id", "center", "radius"), &DanmakuStore::hit_test);
	ClassDB::bind_method(D_METHOD("hit_test_swept", "id", "center", "radius"), &DanmakuStore::hit_test_swept);
	ClassDB::bind_method(D_METHOD("get_max_step"), &DanmakuStore::get_max_step);
	ClassDB::bind_method(D_METHOD("query_circle", "center", "radius"), &DanmakuStore::query_circle);
	ClassDB::bind_method(D_METHOD("is_broadphase_active"), &DanmakuStore::is_broadphase_active);
	ClassDB::bind_method(D_METHOD("is_grazed", "id"), &DanmakuStore::is_grazed);
	ClassDB::bind_method(D_METHOD("mark_grazed", "id"), &DanmakuStore::mark_grazed);
	ClassDB::bind_method(D_METHOD("set_graze_interval_ticks", "ticks"), &DanmakuStore::set_graze_interval_ticks);
	ClassDB::bind_method(D_METHOD("set_field", "left", "right", "top"), &DanmakuStore::set_field);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &DanmakuStore::set_seed);
	ClassDB::bind_method(D_METHOD("get_rng_state"), &DanmakuStore::get_rng_state);
	ClassDB::bind_method(D_METHOD("set_rng_state", "state"), &DanmakuStore::set_rng_state);
	ClassDB::bind_method(D_METHOD("set_behavior", "id", "behavior", "params"), &DanmakuStore::set_behavior, DEFVAL(PackedFloat32Array()));
	ClassDB::bind_method(D_METHOD("get_behavior", "id"), &DanmakuStore::get_behavior);
	ClassDB::bind_method(D_METHOD("get_behavior_id", "name"), &DanmakuStore::get_behavior_id);
	ClassDB::bind_method(D_METHOD("get_behavior_name", "id"), &DanmakuStore::get_behavior_name);
	ClassDB::bind_method(D_METHOD("behavior_tick", "delta", "player", "boss", "has_boss", "enemies", "anchors"), &DanmakuStore::behavior_tick, DEFVAL(PackedVector2Array()));
	ClassDB::bind_method(D_METHOD("preview_behavior", "behavior", "params", "pos", "vel", "frames", "delta", "player", "enemies", "anchor", "has_anchor"), &DanmakuStore::preview_behavior);
	ClassDB::bind_method(D_METHOD("set_anchor_slot", "id", "slot"), &DanmakuStore::set_anchor_slot);
	ClassDB::bind_method(D_METHOD("get_anchor_slot", "id"), &DanmakuStore::get_anchor_slot);
	ClassDB::bind_method(D_METHOD("clear"), &DanmakuStore::clear);
	ClassDB::bind_method(D_METHOD("despawn", "id"), &DanmakuStore::despawn);
	ClassDB::bind_method(D_METHOD("set_life", "id", "life"), &DanmakuStore::set_life);
	ClassDB::bind_method(D_METHOD("set_fx", "id", "fx"), &DanmakuStore::set_fx);
	ClassDB::bind_method(D_METHOD("set_fx_type", "id", "fx_type"), &DanmakuStore::set_fx_type);
	ClassDB::bind_method(D_METHOD("get_fx_type", "id"), &DanmakuStore::get_fx_type);
	ClassDB::bind_method(D_METHOD("get_fx_type_indices"), &DanmakuStore::get_fx_type_indices);
	ClassDB::bind_method(D_METHOD("spawn_fx", "fx_type", "pos", "color", "faction", "life"), &DanmakuStore::spawn_fx);
	ClassDB::bind_method(D_METHOD("set_timer", "id", "timer"), &DanmakuStore::set_timer);
	ClassDB::bind_method(D_METHOD("set_velocity", "id", "vel"), &DanmakuStore::set_velocity);
	ClassDB::bind_method(D_METHOD("set_position", "id", "pos"), &DanmakuStore::set_position);
	ClassDB::bind_method(D_METHOD("get_life_left", "id"), &DanmakuStore::get_life_left);
	ClassDB::bind_method(D_METHOD("get_fx_phase", "id"), &DanmakuStore::get_fx_phase);
	ClassDB::bind_method(D_METHOD("get_uid", "id"), &DanmakuStore::get_uid);
	ClassDB::bind_method(D_METHOD("find_uid", "uid"), &DanmakuStore::find_uid);
	ClassDB::bind_method(D_METHOD("get_timer", "id"), &DanmakuStore::get_timer);
	ClassDB::bind_method(D_METHOD("get_life_lefts"), &DanmakuStore::get_life_lefts);
	ClassDB::bind_method(D_METHOD("get_fx_phases"), &DanmakuStore::get_fx_phases);
	ClassDB::bind_method(D_METHOD("get_timers"), &DanmakuStore::get_timers);
	ClassDB::bind_method(D_METHOD("get_render_rots"), &DanmakuStore::get_render_rots);
	ClassDB::bind_method(D_METHOD("get_capacity"), &DanmakuStore::get_capacity);
	ClassDB::bind_method(D_METHOD("get_build_id"), &DanmakuStore::get_build_id);
	ClassDB::bind_method(D_METHOD("integrate_batch", "count", "positions", "velocities", "life_left", "fx_phase", "timers", "delta", "cull_pos", "cull_size", "margin"), &DanmakuStore::integrate_batch);
}

void DanmakuStore::setup(int p_capacity, const Rect2 &p_cull) {
	_grid_dirty = true;
	_capacity = p_capacity;
	_cull = p_cull;
	_x.assign(p_capacity, 0.0f);
	_y.assign(p_capacity, 0.0f);
	_px.assign(p_capacity, 0.0f);
	_py.assign(p_capacity, 0.0f);
	_vx.assign(p_capacity, 0.0f);
	_vy.assign(p_capacity, 0.0f);
	_hx.assign(p_capacity, 0.0f);
	_hy.assign(p_capacity, 0.0f);
	_type.assign(p_capacity, 0);
	_faction.assign(p_capacity, 0);
	_fx_type.assign(p_capacity, -1);
	_color.assign(p_capacity, Color(1, 1, 1, 1));
	_life.assign(p_capacity, 0.0f);
	_fx.assign(p_capacity, 0.0f);
	_timer.assign(p_capacity, 0.0f);
	_uids.assign(p_capacity, 0);
	_wrap.assign(p_capacity, 0);
	_next_uid = 1;
	_hb_radius.assign(p_capacity, 0.0f);
	_hb_offx.assign(p_capacity, 0.0f);
	_hb_offy.assign(p_capacity, 0.0f);
	_hb_sizex.assign(p_capacity, 0.0f);
	_hb_sizey.assign(p_capacity, 0.0f);
	_hb_diroff.assign(p_capacity, 0.0f);
	_hb_follow.assign(p_capacity, 0);
	_graze_tick.assign(p_capacity, -1);
	_behavior_id.assign(p_capacity, -1);
	_anchor_slot.assign(p_capacity, -1);
	_pelapsed.assign(p_capacity, 0.0f);
	_bstate.assign(p_capacity * B_STATE_STRIDE, 0.0f);
	_bparams.assign(p_capacity * B_PARAM_STRIDE, 0.0f);
	_frame_tick = 0;
	_out_grace.assign(p_capacity, 0.0f);
	_out_time.assign(p_capacity, 0.0f);
	_render_rot.assign(p_capacity, (float)NAN);
	_spin_rot.assign(p_capacity, 0.0f);
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
	_px[i] = p_pos.x;
	_py[i] = p_pos.y;
	_vx[i] = p_vel.x;
	_vy[i] = p_vel.y;
	{ const Vector2 h = p_vel == Vector2() ? Vector2(0, 1) : p_vel.normalized(); _hx[i] = h.x; _hy[i] = h.y; }
	_type[i] = p_type;
	_faction[i] = p_faction;
	_uids[i] = _next_uid++;
	_fx_type[i] = -1;
	_color[i] = p_color;
	_life[i] = _default_life;
	_out_grace[i] = 0.0f;   // 默认无宽限 → 出界即剔除（原行为）；宿主随后可用 set_out_grace 覆盖
	_out_time[i] = 0.0f;
	_fx[i] = 0.0f;
	_timer[i] = 0.0f;
	// 有状态 spawn 必须整行归零（batch 路径由调用方传数组，stateful 没有）。
	_hb_radius[i] = 0.0f; _hb_offx[i] = 0.0f; _hb_offy[i] = 0.0f;
	_hb_sizex[i] = 0.0f; _hb_sizey[i] = 0.0f; _hb_diroff[i] = 0.0f; _hb_follow[i] = 0;
	_graze_tick[i] = -1;
	_behavior_id[i] = -1;
	_anchor_slot[i] = -1;
	_pelapsed[i] = 0.0f;
	for (int bs = 0; bs < B_STATE_STRIDE; ++bs) { _bstate[i * B_STATE_STRIDE + bs] = 0.0f; }
	for (int bp = 0; bp < B_PARAM_STRIDE; ++bp) { _bparams[i * B_PARAM_STRIDE + bp] = 0.0f; }
	_render_rot[i] = (float)NAN;
	_spin_rot[i] = 0.0f;
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
		_px[i] = pos.x;
		_py[i] = pos.y;
		_vx[i] = vel.x;
		_vy[i] = vel.y;
		{ const Vector2 h = vel == Vector2() ? Vector2(0, 1) : vel.normalized(); _hx[i] = h.x; _hy[i] = h.y; }
		_type[i] = k < p_type.size() ? p_type[k] : 0;
		_faction[i] = k < p_faction.size() ? p_faction[k] : 0;
		_uids[i] = _next_uid++;
		_fx_type[i] = -1;
		_color[i] = k < p_color.size() ? p_color[k] : Color(1, 1, 1, 1);
		_life[i] = _default_life;
		_out_grace[i] = 0.0f;
		_out_time[i] = 0.0f;
		_fx[i] = 0.0f;
		_timer[i] = 0.0f;
												_hb_radius[i] = 0.0f; _hb_offx[i] = 0.0f; _hb_offy[i] = 0.0f;
		_hb_sizex[i] = 0.0f; _hb_sizey[i] = 0.0f; _hb_diroff[i] = 0.0f; _hb_follow[i] = 0;
		_graze_tick[i] = -1;
		_behavior_id[i] = -1;
		for (int bs = 0; bs < B_STATE_STRIDE; ++bs) { _bstate[i * B_STATE_STRIDE + bs] = 0.0f; }
		for (int bp = 0; bp < B_PARAM_STRIDE; ++bp) { _bparams[i * B_PARAM_STRIDE + bp] = 0.0f; }
		_render_rot[i] = (float)NAN;
		_spin_rot[i] = 0.0f;
		++_count;
		++added;
	}
	return added;
}

// 纯特效行：无弹型（_type=-1）、无速度、无碰撞；寿命 = 相位 = p_life，到期由 integrate 回收。
// faction 只用于渲染分批（特效行没有弹型，阵营只能由调用方给）。
int DanmakuStore::spawn_fx(int p_fx_type, const Vector2 &p_pos, const Color &p_color, int p_faction, float p_life) {
	_grid_dirty = true;
	if (_count >= _capacity) {
		_ensure_capacity(_count + 1);
	}
	const int i = _count;
	_x[i] = p_pos.x;
	_y[i] = p_pos.y;
	_px[i] = p_pos.x;
	_py[i] = p_pos.y;
	_vx[i] = 0.0f;
	_vy[i] = 0.0f;
	_hx[i] = 0.0f;
	_hy[i] = 1.0f;
	_type[i] = -1;
	_faction[i] = p_faction;
	_uids[i] = 0;
	_wrap[i] = 0;
	_fx_type[i] = p_fx_type;
	_color[i] = p_color;
	_life[i] = p_life;
	_out_grace[i] = 0.0f;
	_out_time[i] = 0.0f;
	_fx[i] = p_life;
	_timer[i] = 0.0f;
	_hb_radius[i] = 0.0f; _hb_offx[i] = 0.0f; _hb_offy[i] = 0.0f;
	_hb_sizex[i] = 0.0f; _hb_sizey[i] = 0.0f; _hb_diroff[i] = 0.0f; _hb_follow[i] = 0;
	_graze_tick[i] = -1;
	_behavior_id[i] = -1;
	_anchor_slot[i] = -1;
	_pelapsed[i] = 0.0f;
	for (int bs = 0; bs < B_STATE_STRIDE; ++bs) { _bstate[i * B_STATE_STRIDE + bs] = 0.0f; }
	for (int bp = 0; bp < B_PARAM_STRIDE; ++bp) { _bparams[i * B_PARAM_STRIDE + bp] = 0.0f; }
	_render_rot[i] = (float)NAN;
	_spin_rot[i] = 0.0f;
	return _count++;
}

// 按需扩容内部向量（无状态批量入口用：桥接侧不调 setup，_capacity 可能为 0）。
void DanmakuStore::_ensure_capacity(int p_n) {
	if (p_n <= _capacity) {
		return;
	}
	_capacity = p_n;
	_x.resize(p_n); _y.resize(p_n); _vx.resize(p_n); _vy.resize(p_n);
	_px.resize(p_n); _py.resize(p_n);
	_hx.resize(p_n); _hy.resize(p_n);
	_type.resize(p_n); _faction.resize(p_n); _fx_type.resize(p_n); _color.resize(p_n);
	_life.resize(p_n); _fx.resize(p_n); _timer.resize(p_n);
	_uids.resize(p_n);
	_wrap.resize(p_n);
	_hb_radius.resize(p_n); _hb_offx.resize(p_n); _hb_offy.resize(p_n);
	_hb_sizex.resize(p_n); _hb_sizey.resize(p_n); _hb_diroff.resize(p_n);
	_hb_follow.resize(p_n); _graze_tick.resize(p_n); _render_rot.resize(p_n); _spin_rot.resize(p_n);
	_behavior_id.resize(p_n); _anchor_slot.resize(p_n); _pelapsed.resize(p_n); _bstate.resize(p_n * B_STATE_STRIDE); _bparams.resize(p_n * B_PARAM_STRIDE);
	_out_grace.resize(p_n); _out_time.resize(p_n);
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
	_px[p_id] = _px[last];
	_py[p_id] = _py[last];
	_vx[p_id] = _vx[last];
	_vy[p_id] = _vy[last];
	_hx[p_id] = _hx[last];
	_hy[p_id] = _hy[last];
	_type[p_id] = _type[last];
	_faction[p_id] = _faction[last];
	_uids[p_id] = _uids[last];
	_wrap[p_id] = _wrap[last];
	_fx_type[p_id] = _fx_type[last];
	_color[p_id] = _color[last];
	_life[p_id] = _life[last];
	_fx[p_id] = _fx[last];
	_timer[p_id] = _timer[last];
	_hb_radius[p_id] = _hb_radius[last];
	_hb_offx[p_id] = _hb_offx[last];
	_hb_offy[p_id] = _hb_offy[last];
	_hb_sizex[p_id] = _hb_sizex[last];
	_hb_sizey[p_id] = _hb_sizey[last];
	_hb_diroff[p_id] = _hb_diroff[last];
	_hb_follow[p_id] = _hb_follow[last];
	_graze_tick[p_id] = _graze_tick[last];
	_behavior_id[p_id] = _behavior_id[last];
	_anchor_slot[p_id] = _anchor_slot[last];
	_pelapsed[p_id] = _pelapsed[last];
	for (int bs = 0; bs < B_STATE_STRIDE; ++bs) { _bstate[p_id * B_STATE_STRIDE + bs] = _bstate[last * B_STATE_STRIDE + bs]; }
	for (int bp = 0; bp < B_PARAM_STRIDE; ++bp) { _bparams[p_id * B_PARAM_STRIDE + bp] = _bparams[last * B_PARAM_STRIDE + bp]; }
	_out_grace[p_id] = _out_grace[last];
	_out_time[p_id] = _out_time[last];
	_render_rot[p_id] = _render_rot[last];
	_spin_rot[p_id] = _spin_rot[last];
}

// 完整积分循环：寿命 / 出生相位 / 位移 / 计时 / 剔除 —— 与 scripts/kernel/bullet_system.gd 1:1。
void DanmakuStore::integrate(double p_delta) {
	_grid_dirty = true;
	++_frame_tick;
	_max_step = 0.0f;
	const float dt = CLAMP((float)p_delta, 0.0f, MAX_DT);
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
		_px[i] = _x[i];
		_py[i] = _y[i];
		_x[i] += _vx[i] * dt;
		_y[i] += _vy[i] * dt;
		if (_wrap[i] != 0 && _cull.size.x > 0.0f && _cull.size.y > 0.0f) {
			const float right = _cull.position.x + _cull.size.x;
			const float bottom = _cull.position.y + _cull.size.y;
			const int mask = _wrap[i];
			if ((mask & 1) && _x[i] < _cull.position.x) { _x[i] += _cull.size.x; }
			else if ((mask & 2) && _x[i] > right) { _x[i] -= _cull.size.x; }
			if ((mask & 4) && _y[i] < _cull.position.y) { _y[i] += _cull.size.y; }
			else if ((mask & 8) && _y[i] > bottom) { _y[i] -= _cull.size.y; }
		}
		if (_timer[i] > 0.0f) {
			_timer[i] -= dt;
		}
		// 扫掠判定用：记录本帧最大位移；环绕等不连续位移（跨过半屏）不参与扫掠。
		{
			const float dx = _x[i] - _px[i];
			const float dy = _y[i] - _py[i];
			const bool discontinuous = (_cull.size.x > 0.0f && Math::abs(dx) > _cull.size.x * 0.5f)
					|| (_cull.size.y > 0.0f && Math::abs(dy) > _cull.size.y * 0.5f);
			if (discontinuous) {
				_px[i] = _x[i];
				_py[i] = _y[i];
			} else {
				const float step2 = dx * dx + dy * dy;
				if (step2 > _max_step * _max_step) {
					_max_step = Math::sqrt(step2);
				}
			}
		}
		if (cull && !grown.has_point(Vector2(_x[i], _y[i]))) {
			// 出界：grace <= 0 → 立即剔除（原行为，保持不变）；否则累计「连续出界时长」，超时才剔除。
			if (_out_grace[i] <= 0.0f) {
				_swap_remove(i);
			} else {
				_out_time[i] += dt;
				if (_out_time[i] > _out_grace[i]) {
					_swap_remove(i);
				}
			}
		} else {
			_out_time[i] = 0.0f;   // 回到界内 → 计时归零（往返弹回来后不该继续被计时淘汰）
		}
	}
}

// 有状态存储的容量扩容（grow-only）与剔除区注入。
void DanmakuStore::reserve(int p_n) { _ensure_capacity(p_n); }
void DanmakuStore::set_cull(const Rect2 &p_cull) { _cull = p_cull; _grid_dirty = true; }
void DanmakuStore::set_margin(float p_margin) { _margin = p_margin; }
// 逐弹出界宽限：设置时把「已出界时长」归零（新弹才算，改宽限不该立刻触发超时）。
void DanmakuStore::set_out_grace(int p_id, float p_grace) {
	if (!_valid(p_id)) {
		return;
	}
	_out_grace[p_id] = p_grace;
	_out_time[p_id] = 0.0f;
}
void DanmakuStore::set_wrap(int p_id, int p_mask) {
	if (_valid(p_id)) {
		_wrap[p_id] = (unsigned char)(p_mask & 15);
	}
}
float DanmakuStore::get_out_grace(int p_id) const {
	return _valid(p_id) ? _out_grace[p_id] : 0.0f;
}
void DanmakuStore::set_default_life(float p_life) { _default_life = p_life; }
void DanmakuStore::set_field(float p_left, float p_right, float p_top) { _field_left = p_left; _field_right = p_right; _field_top = p_top; }
int DanmakuStore::get_capacity() const { return _capacity; }

String DanmakuStore::get_build_id() const { return String(DANMAKU_BUILD_ID); }

void DanmakuStore::clear() {
	_grid_dirty = true;
	_count = 0;
}

int DanmakuStore::despawn(int p_id) {
	if (!_valid(p_id)) {
		return -1;
	}
	const int moved = _count - 1;
	_swap_remove(p_id);
	return moved == p_id ? -1 : moved;
}

void DanmakuStore::set_life(int p_id, float p_life) { if (_valid(p_id)) { _life[p_id] = p_life; } }
void DanmakuStore::set_fx(int p_id, float p_fx) { if (_valid(p_id)) { _fx[p_id] = p_fx; } }
void DanmakuStore::set_fx_type(int p_id, int p_fx_type) { if (_valid(p_id)) { _fx_type[p_id] = p_fx_type; } }
int DanmakuStore::get_fx_type(int p_id) const { return _valid(p_id) ? _fx_type[p_id] : -1; }
PackedInt32Array DanmakuStore::get_fx_type_indices() const {
	PackedInt32Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = _fx_type[i]; }
	return out;
}
void DanmakuStore::set_timer(int p_id, float p_timer) { if (_valid(p_id)) { _timer[p_id] = p_timer; } }
void DanmakuStore::set_velocity(int p_id, const Vector2 &p_vel) { if (_valid(p_id)) { _vx[p_id] = p_vel.x; _vy[p_id] = p_vel.y; } }
void DanmakuStore::set_position(int p_id, const Vector2 &p_pos) {
	if (!_valid(p_id)) { return; }
	_x[p_id] = p_pos.x; _y[p_id] = p_pos.y;
	// 瞬移：同步上一帧位置，避免扫掠判定在整段位移上产生假命中。
	_px[p_id] = p_pos.x; _py[p_id] = p_pos.y;
	_grid_dirty = true;
}
float DanmakuStore::get_life_left(int p_id) const { return _valid(p_id) ? _life[p_id] : 0.0f; }
float DanmakuStore::get_fx_phase(int p_id) const { return _valid(p_id) ? _fx[p_id] : 0.0f; }
int64_t DanmakuStore::get_uid(int p_id) const { return _valid(p_id) ? _uids[p_id] : 0; }
int DanmakuStore::find_uid(int64_t p_uid) const {
	if (p_uid <= 0) { return -1; }
	for (int i = 0; i < _count; ++i) {
		if (_uids[i] == p_uid) { return i; }
	}
	return -1;
}
float DanmakuStore::get_timer(int p_id) const { return _valid(p_id) ? _timer[p_id] : 0.0f; }

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

// 逐弹渲染朝向覆盖（NAN = 未设，渲染端回退到 velocity 角）。
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
	return _valid(p_id) ? Vector2(_x[p_id], _y[p_id]) : Vector2();
}

PackedVector2Array DanmakuStore::get_positions() const {
	PackedVector2Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = Vector2(_x[i], _y[i]);
	}
	return out;
}

Vector2 DanmakuStore::get_forward(int p_id) const { return _valid(p_id) ? Vector2(_hx[p_id], _hy[p_id]) : Vector2(); }
void DanmakuStore::set_forward(int p_id, const Vector2 &p_fwd) {
	if (!_valid(p_id)) { return; }
	const Vector2 f = p_fwd.normalized();
	_hx[p_id] = f.x; _hy[p_id] = f.y;
}

Vector2 DanmakuStore::get_velocity(int p_id) const {
	return _valid(p_id) ? Vector2(_vx[p_id], _vy[p_id]) : Vector2();
}

PackedVector2Array DanmakuStore::get_velocities() const {
	PackedVector2Array out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) {
		out[i] = Vector2(_vx[i], _vy[i]);
	}
	return out;
}

int DanmakuStore::get_type(int p_id) const { return _valid(p_id) ? _type[p_id] : -1; }
int DanmakuStore::get_type_index(int p_id) const { return _valid(p_id) ? _type[p_id] : -1; }
int DanmakuStore::get_faction(int p_id) const { return _valid(p_id) ? _faction[p_id] : -1; }
Color DanmakuStore::get_color(int p_id) const { return _valid(p_id) ? _color[p_id] : Color(1, 1, 1, 1); }

void DanmakuStore::set_color(int p_id, const Color &p_color) {
	if (_valid(p_id)) { _color[p_id] = p_color; }
}

float DanmakuStore::get_render_rot(int p_id) const {
	return _valid(p_id) ? _render_rot[p_id] : (float)NAN;
}

void DanmakuStore::set_render_rot(int p_id, float p_rot) {
	if (_valid(p_id)) { _render_rot[p_id] = p_rot; }
}

Dictionary DanmakuStore::get_hitbox(int p_id) const {
	Dictionary out;
	if (!_valid(p_id)) { return out; }
	out["radius"] = _hb_radius[p_id];
	out["offset"] = Vector2(_hb_offx[p_id], _hb_offy[p_id]);
	out["size"] = Vector2(_hb_sizex[p_id], _hb_sizey[p_id]);
	out["follow_dir"] = _hb_follow[p_id] != 0;
	out["dir_offset"] = _hb_diroff[p_id];
	return out;
}

int DanmakuStore::get_wrap(int p_id) const {
	return _valid(p_id) ? (int)_wrap[p_id] : 0;
}

float DanmakuStore::get_spin_rot(int p_id) const {
	return _valid(p_id) ? _spin_rot[p_id] : 0.0f;
}

void DanmakuStore::set_spin_rot(int p_id, float p_rot) {
	if (_valid(p_id)) { _spin_rot[p_id] = p_rot; }
}

float DanmakuStore::get_elapsed(int p_id) const {
	return _valid(p_id) ? _pelapsed[p_id] : 0.0f;
}

PackedFloat32Array DanmakuStore::get_behavior_state(int p_id) const {
	PackedFloat32Array out;
	out.resize(B_STATE_STRIDE);
	if (!_valid(p_id)) { return out; }
	for (int s = 0; s < B_STATE_STRIDE; ++s) { out[s] = _bstate[p_id * B_STATE_STRIDE + s]; }
	return out;
}

bool DanmakuStore::set_behavior(int p_id, int p_behavior, const PackedFloat32Array &p_params) {
	if (!_valid(p_id)) { return false; }
	const NativeBehaviorDef *def = NativeBehaviorRegistry::get(p_behavior);
	if (def == nullptr) { return false; }
	_behavior_id[p_id] = p_behavior;
	_pelapsed[p_id] = 0.0f;
	for (int s = 0; s < B_STATE_STRIDE; ++s) { _bstate[p_id * B_STATE_STRIDE + s] = 0.0f; }
	for (int s = 0; s < B_PARAM_STRIDE; ++s) { _bparams[p_id * B_PARAM_STRIDE + s] = 0.0f; }
	const int n = MIN(def->param_count, B_PARAM_STRIDE);
	for (int s = 0; s < n && s < p_params.size(); ++s) {
		_bparams[p_id * B_PARAM_STRIDE + s] = p_params[s];
	}
	if (def->init != nullptr) {
		def->init(&_bstate[p_id * B_STATE_STRIDE], &_bparams[p_id * B_PARAM_STRIDE]);
	}
	return true;
}

int DanmakuStore::get_behavior(int p_id) const {
	return _valid(p_id) ? _behavior_id[p_id] : -1;
}

int DanmakuStore::get_behavior_id(const String &p_name) const {
	return NativeBehaviorRegistry::find_id(p_name);
}

String DanmakuStore::get_behavior_name(int p_id) const {
	return NativeBehaviorRegistry::get_name(p_id);
}

void DanmakuStore::set_anchor_slot(int p_id, int p_slot) {
	if (_valid(p_id)) { _anchor_slot[p_id] = p_slot; }
}

int DanmakuStore::get_anchor_slot(int p_id) const {
	return _valid(p_id) ? _anchor_slot[p_id] : -1;
}

PackedFloat32Array DanmakuStore::get_behavior_params(int p_id) const {
	PackedFloat32Array out;
	out.resize(B_PARAM_STRIDE);
	if (!_valid(p_id)) { return out; }
	for (int s = 0; s < B_PARAM_STRIDE; ++s) { out[s] = _bparams[p_id * B_PARAM_STRIDE + s]; }
	return out;
}

void DanmakuStore::fill_multimesh(const Ref<MultiMesh> &p_mm) const {
	if (p_mm.is_null()) {
		return;
	}
	for (int i = 0; i < _count; ++i) {
		p_mm->set_instance_transform_2d(i, Transform2D(0.0f, Vector2(_x[i], _y[i])));
		p_mm->set_instance_color(i, _color[i]);
	}
}

// 积分加速器。语义必须与 scripts/kernel/bullet_system.gd 的 _physics_process 1:1。
// 与 GDScript 版的唯一区别：这里不在循环里 swap 回收，只记录 dead；调用方按同序重放 despawn。
Dictionary DanmakuStore::integrate_batch(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedFloat32Array &p_life_left, const PackedFloat32Array &p_fx_phase, const PackedFloat32Array &p_timers, double p_delta, const Vector2 &p_cull_pos, const Vector2 &p_cull_size, float p_margin) const {
	const int n = MIN(p_count, MIN(p_positions.size(), p_velocities.size()));
	PackedVector2Array positions = p_positions;   // CoW 共享；下面首次写入时才整块拷贝
	PackedVector2Array velocities = p_velocities;
	PackedFloat32Array life = p_life_left;
	PackedFloat32Array fx = p_fx_phase;
	PackedFloat32Array timers = p_timers;
	PackedInt32Array dead;
	const float dt = CLAMP((float)p_delta, 0.0f, MAX_DT);
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
		// 与 integrate 的 Rect2.has_point 对齐：右/下边界开区间。
		if (cull && (p.x < x0 || p.x >= x1 || p.y < y0 || p.y >= y1)) {
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


void DanmakuStore::_run_behavior_pass(float dt, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchors) {
	_grid_dirty = true;
	_tick_dead.clear();
	_ev_kind.clear(); _ev_local.clear();
	_ev_x.clear(); _ev_y.clear(); _ev_dx.clear(); _ev_dy.clear();
	_ev_color.clear();
	for (int i = 0; i < _count; ++i) {
		_render_rot[i] = (float)NAN;   // 每帧重置；只有 behavior 会设它
		if (_fx[i] > 0.0f) { continue; }   // 出生相位：只画特效，不跑行为
		if (_behavior_id[i] < 0) { continue; }
		_pelapsed[i] += dt;
		const NativeBehaviorDef *bdef = NativeBehaviorRegistry::get(_behavior_id[i]);
		if (bdef != nullptr && bdef->tick != nullptr) {
			NativeBehaviorContext bctx;
			bctx.player = p_player;
			bctx.boss = p_boss;
			bctx.has_boss = p_has_boss;
			bctx.enemies = &p_enemies;
			bctx.position = Vector2(_x[i], _y[i]);
			const int as = _anchor_slot[i];
			if (as >= 0 && as < p_anchors.size()) {
				bctx.anchor = p_anchors[as];
				bctx.has_anchor = true;
			}
			bctx.field_left = _field_left;
			bctx.field_right = _field_right;
			bctx.field_top = _field_top;
			bctx.rng_user = this;
			bctx.rng_float = [](void *p_user) -> float {
				return static_cast<DanmakuStore *>(p_user)->rng_next();
			};
			Vector2 pos_out = bctx.position;
			bctx.position_out = &pos_out;
			bctx.heading_x = &_hx[i];
			bctx.heading_y = &_hy[i];
			bctx.render_rot = &_render_rot[i];
			bctx.spin_rot = &_spin_rot[i];
			bctx.life = &_life[i];
			Vector2 vel(_vx[i], _vy[i]);
			bctx.velocity = &vel;
			bctx.color = &_color[i];
			NativeBehaviorOutcome bout;
			bdef->tick(&_bstate[i * B_STATE_STRIDE], &_bparams[i * B_PARAM_STRIDE], bctx, bout, dt);
			_vx[i] = vel.x;
			_vy[i] = vel.y;
			_x[i] = pos_out.x;
			_y[i] = pos_out.y;
			if (bout.despawn) {
				_tick_dead.push_back(i);
			}
			for (int e = 0; e < bout.emit_count; ++e) {
				const NativeBehaviorEmit &req = bout.emits[e];
				_ev_kind.push_back(5);
				_ev_local.push_back(req.template_id);
				_ev_x.push_back(req.position.x); _ev_y.push_back(req.position.y);
				_ev_dx.push_back(req.velocity.x); _ev_dy.push_back(req.velocity.y);
				_ev_color.push_back(req.color);
			}
			if (bout.sfx_id >= 0) {
				_ev_kind.push_back(6);
				_ev_local.push_back(bout.sfx_id);
				_ev_x.push_back(_x[i]); _ev_y.push_back(_y[i]);
				_ev_dx.push_back(0); _ev_dy.push_back(0);
				_ev_color.push_back(_color[i]);
			}
			if (bout.laser_template_id >= 0) {
				_ev_kind.push_back(7);
				_ev_local.push_back(bout.laser_template_id);
				_ev_x.push_back(bout.laser_position.x); _ev_y.push_back(bout.laser_position.y);
				_ev_dx.push_back(bout.laser_direction.x); _ev_dy.push_back(bout.laser_direction.y);
				_ev_color.push_back(_color[i]);
			}
			if (bout.clear_fx) {
				_ev_kind.push_back(3);
				_ev_local.push_back(0);
				_ev_x.push_back(_x[i]); _ev_y.push_back(_y[i]);
				_ev_dx.push_back(0); _ev_dy.push_back(0);
				_ev_color.push_back(_color[i]);
			}
		}
		if (_spin_rot[i] != 0.0f) {
			const float spin_base = std::isnan(_render_rot[i]) ? std::atan2(_vy[i], _vx[i]) : _render_rot[i];
			_render_rot[i] = spin_base + _spin_rot[i];
		}
	}
	std::sort(_tick_dead.begin(), _tick_dead.end(), std::greater<int>());
	_tick_dead.erase(std::unique(_tick_dead.begin(), _tick_dead.end()), _tick_dead.end());
}

Dictionary DanmakuStore::_events_dict() const {
	Dictionary out;
	PackedInt32Array kind, local;
	PackedFloat32Array ex, ey, edx, edy;
	PackedColorArray ecolor;
	for (size_t k = 0; k < _ev_kind.size(); ++k) {
		kind.push_back(_ev_kind[k]); local.push_back(_ev_local[k]);
		ex.push_back(_ev_x[k]); ey.push_back(_ev_y[k]);
		edx.push_back(_ev_dx[k]); edy.push_back(_ev_dy[k]);
		ecolor.push_back(k < _ev_color.size() ? _ev_color[k] : Color(1, 1, 1, 1));
	}
	out["kind"] = kind; out["local"] = local;
	out["x"] = ex; out["y"] = ey; out["dx"] = edx; out["dy"] = edy;
	out["color"] = ecolor;
	return out;
}

PackedVector2Array DanmakuStore::preview_behavior(int p_behavior, const PackedFloat32Array &p_params,
		const Vector2 &p_pos, const Vector2 &p_vel, int p_frames, double p_delta,
		const Vector2 &p_player, const PackedVector2Array &p_enemies,
		const Vector2 &p_anchor, bool p_has_anchor) {
	PackedVector2Array out;
	const NativeBehaviorDef *def = NativeBehaviorRegistry::get(p_behavior);
	if (def == nullptr || def->tick == nullptr || p_frames <= 0 || p_delta <= 0.0) {
		return out;
	}
	const float dt = CLAMP((float)p_delta, 0.0f, MAX_DT);
	float state[B_STATE_STRIDE] = {0.0f};
	float params[B_PARAM_STRIDE] = {0.0f};
	const int pc = MIN(def->param_count, B_PARAM_STRIDE);
	for (int i = 0; i < pc && i < p_params.size(); ++i) {
		params[i] = p_params[i];
	}
	if (def->init != nullptr) {
		def->init(state, params);
	}
	Vector2 pos = p_pos;
	Vector2 vel = p_vel;
	const Vector2 h0 = vel == Vector2() ? Vector2(0, 1) : vel.normalized();
	float hx = h0.x, hy = h0.y;
	float render_rot = (float)NAN, spin_rot = 0.0f, life = 0.0f;
	Color color(1, 1, 1, 1);
	uint32_t rng = 0x9E3779B9u;
	out.push_back(pos);
	const int frames = MIN(p_frames, 10000);
	for (int f = 0; f < frames; ++f) {
		pos += vel * dt;
		NativeBehaviorContext ctx;
		ctx.player = p_player;
		ctx.boss = p_player;
		ctx.has_boss = false;
		ctx.enemies = &p_enemies;
		ctx.position = pos;
		ctx.position_out = &pos;
		ctx.anchor = p_anchor;
		ctx.has_anchor = p_has_anchor;
		ctx.field_left = _field_left;
		ctx.field_right = _field_right;
		ctx.field_top = _field_top;
		ctx.rng_user = &rng;
		ctx.rng_float = [](void *p_user) -> float {
			uint32_t &s = *static_cast<uint32_t *>(p_user);
			s = s * 1664525u + 1013904223u;
			return (float)(s >> 8) * (1.0f / 16777216.0f);
		};
		ctx.heading_x = &hx;
		ctx.heading_y = &hy;
		ctx.render_rot = &render_rot;
		ctx.spin_rot = &spin_rot;
		ctx.life = &life;
		ctx.velocity = &vel;
		ctx.color = &color;
		NativeBehaviorOutcome bout;
		def->tick(state, params, ctx, bout, dt);
		if (bout.despawn) {
			break;
		}
		out.push_back(pos);
	}
	return out;
}

Dictionary DanmakuStore::behavior_tick(double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchors) {
	_run_behavior_pass(CLAMP((float)p_delta, 0.0f, MAX_DT), p_player, p_boss, p_has_boss, p_enemies, p_anchors);
	std::sort(_tick_dead.begin(), _tick_dead.end(), std::greater<int>());
	for (int id : _tick_dead) {
		if (id >= 0 && id < _count) { _swap_remove(id); }
	}
	return _events_dict();
}

void DanmakuStore::set_seed(int p_seed) {
	_rng_state = (uint32_t)((uint64_t)p_seed & 0xFFFFFFFFu);
	if (_rng_state == 0) { _rng_state = 0x9E3779B9u; }
}

int DanmakuStore::get_rng_state() const { return (int)_rng_state; }

void DanmakuStore::set_rng_state(int p_state) {
	_rng_state = (uint32_t)p_state;
	if (_rng_state == 0) { _rng_state = 0x9E3779B9u; }
}

float DanmakuStore::rng_next() { return _rng_float(); }

float DanmakuStore::_rng_float() {
	uint32_t x = _rng_state;
	x ^= x << 13; x ^= x >> 17; x ^= x << 5;
	_rng_state = x;
	return (float)(x >> 8) * (1.0f / 16777216.0f);   // [0,1)
}


// ═══ 判定几何（与 scripts/kernel/collision/hit_geometry.gd 1:1）═══
static bool _circle_rect(const Vector2 &center, float radius, const Vector2 &rect_center, float rot, const Vector2 &size) {
	const Vector2 local = (center - rect_center).rotated(-rot);
	const Vector2 half = size * 0.5f;
	const float dx = MAX(0.0f, Math::abs(local.x) - half.x);
	const float dy = MAX(0.0f, Math::abs(local.y) - half.y);
	return dx * dx + dy * dy <= radius * radius;
}

static float _hit_rot(const Vector2 &vel, unsigned char follow, float diroff) {
	if (follow && vel != Vector2()) {
		return vel.angle() + diroff;
	}
	return 0.0f;
}

// 点到线段的最短距离平方（线段退化时为点-点）。
static float _point_seg_dist2(const Vector2 &p, const Vector2 &a, const Vector2 &b) {
	const Vector2 ab = b - a;
	const float len2 = ab.length_squared();
	float t = 0.0f;
	if (len2 > 0.0f) {
		t = CLAMP((p - a).dot(ab) / len2, 0.0f, 1.0f);
	}
	const Vector2 q = a + ab * t;
	return (p - q).length_squared();
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

// 宿主 BulletSystem 的 _faction 是 PackedByteArray → 需要同型快照。
PackedByteArray DanmakuStore::get_factions_bytes() const {
	PackedByteArray out;
	out.resize(_count);
	for (int i = 0; i < _count; ++i) { out[i] = (unsigned char)_faction[i]; }
	return out;
}

float DanmakuStore::get_max_step() const {
	return _max_step;
}

bool DanmakuStore::hit_test_swept(int p_id, const Vector2 &p_center, float p_radius) const {
	if (hit_test(p_id, p_center, p_radius)) {
		return true;
	}
	if (!_valid(p_id)) { return false; }
	if (_fx[p_id] > 0.0f) { return false; }
	if (_type[p_id] < 0) { return false; }
	const float rot = _hit_rot(Vector2(_vx[p_id], _vy[p_id]), _hb_follow[p_id], _hb_diroff[p_id]);
	const Vector2 off = Vector2(_hb_offx[p_id], _hb_offy[p_id]).rotated(rot);
	const Vector2 a = Vector2(_px[p_id], _py[p_id]) + off;
	const Vector2 b = Vector2(_x[p_id], _y[p_id]) + off;
	const float sx = _hb_sizex[p_id];
	const float sy = _hb_sizey[p_id];
	float reach = _hb_radius[p_id];
	if (sx != 0.0f || sy != 0.0f) {
		reach = 0.5f * Vector2(sx, sy).length();
	}
	const float rr = p_radius + reach;
	return _point_seg_dist2(p_center, a, b) <= rr * rr;
}

void DanmakuStore::set_hitbox(int p_id, float p_radius, const Vector2 &p_offset, const Vector2 &p_size, bool p_follow_dir, float p_dir_offset) {
	if (!_valid(p_id)) { return; }
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
	if (!_valid(p_id)) { return false; }
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

// ═══ 宽相 uniform grid（与 GDScript BulletSystem 同参数/同语义）═══

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

bool DanmakuStore::is_grazed(int p_id) const {
	return _valid(p_id) && _graze_tick[p_id] >= 0
		&& (_frame_tick - _graze_tick[p_id]) < _graze_interval_ticks;
}

void DanmakuStore::mark_grazed(int p_id) { if (_valid(p_id)) { _graze_tick[p_id] = _frame_tick; } }
void DanmakuStore::set_graze_interval_ticks(int p_ticks) { _graze_interval_ticks = p_ticks < 1 ? 1 : p_ticks; }

DanmakuStore::DanmakuStore() {}
DanmakuStore::~DanmakuStore() {}