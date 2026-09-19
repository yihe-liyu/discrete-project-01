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
#include <cstdint>

namespace godot {

// N2-real：原生 SoA 存储 + 积分 + 剔除 + 实例缓冲写入。
// 每弹携带 type / faction / color，供渲染与后续宿主规则使用。
// **批量 spawn**（spawn_batch）避免逐弹跨语言边界。
class DanmakuStore : public RefCounted {
	GDCLASS(DanmakuStore, RefCounted)

	std::vector<float> _x, _y, _vx, _vy;
	// 自身朝向（出生取自初速；rotate / set_heading 改；accel_heading 读）—— 与速度解耦，v=0 仍有效
	std::vector<float> _hx, _hy;
	std::vector<int> _type, _faction;
	// 逐行特效型下标（发弹/消弹共用；-1 = 无特效）。相位内该行只画特效，不动不判定。
	std::vector<int> _fx_type;
	std::vector<Color> _color;
	std::vector<float> _life, _fx, _timer;
	float _default_life = 20.0f;
	std::vector<float> _hb_radius, _hb_offx, _hb_offy, _hb_sizex, _hb_sizey, _hb_diroff;
	std::vector<unsigned char> _hb_follow, _grazed;
	// V19：逐弹渲染朝向覆盖（NAN = 未设，渲染按 velocity 推）。位置 op 只写它，不再借道 velocity。
	std::vector<float> _render_rot;
	float _field_left = 0.0f, _field_right = 0.0f, _field_top = 0.0f;

	// K1：确定性 PRNG（单通道；种子由宿主 RNG 派生）。抽取顺序 = 弹行遍历顺序 → 回放可复现。
	uint32_t _rng_state = 0x9E3779B9u;

	// L3：packed program 执行（列式；op/args 全局拼接，program 只存偏移）。
	static const int SLOT_STRIDE = 8;
	PackedInt32Array _p_ops, _p_move_start, _p_move_count, _p_until, _p_act_start, _p_act_count, _p_phase_base, _p_slots;
	PackedFloat32Array _p_args;
	std::vector<int> _program, _pphase, _ptick;
	std::vector<float> _pelapsed, _pnext, _pendx, _pendy, _pslots;
	std::vector<unsigned char> _phasend;
	// V1：相位首帧标志从「每弹一个 bool」改为「每槽一个 bit」——否则同相位的两个有状态
	// 初始化 unit（anchor_drift / drift）会互相消费掉 fresh，后者用未初始化的槽（实测瞬移到原点）。
	// bit s = 槽 s 在本相位尚未初始化。
	std::vector<uint32_t> _pslot_fresh;
	static const int OPS_ARGS = 12;
	std::vector<int> _tick_dead;
	std::vector<int> _ev_kind, _ev_prog, _ev_local, _ev_bullet, _ev_variant;
	std::vector<float> _ev_x, _ev_y, _ev_dx, _ev_dy, _ev_val;
	int _capacity = 0;
	int _count = 0;
	Rect2 _cull;
	float _margin = 0.0f;

	// L3.5-4b-pre：宽相 uniform grid（参数与 GDScript `BulletSystem` 一致；查询前按需重建）。
	// mutable：`query_circle` / `overlap_pairs` 是 const，但需要惰性重建网格。
	static constexpr float GRID_CELL = 64.0f;
	static constexpr int GRID_MIN_COUNT = 64;
	static constexpr int GRID_MAX_CELLS = 8192;
	mutable bool _grid_dirty = true;
	mutable bool _grid_active = false;
	mutable int _grid_gx = 0;
	mutable int _grid_gy = 0;
	mutable Vector2 _grid_origin;
	mutable float _grid_max_bound = 0.0f;
	mutable std::vector<int> _grid_head, _grid_prev, _grid_next, _grid_cell_of;

protected:
	static void _bind_methods();

public:
	void setup(int p_capacity, const Rect2 &p_cull);
	int spawn(const Vector2 &p_pos, const Vector2 &p_vel, int p_type = 0, int p_faction = 0, const Color &p_color = Color(1, 1, 1, 1));
	int spawn_batch(const PackedVector2Array &p_pos, const PackedVector2Array &p_vel, const PackedInt32Array &p_type, const PackedInt32Array &p_faction, const PackedColorArray &p_color);
	void integrate(double p_delta);
	int get_active_count() const;
	int get_program(int p_id) const;
	Vector2 get_position(int p_id) const;
	Vector2 get_velocity(int p_id) const;
	Vector2 get_forward(int p_id) const;
	void set_forward(int p_id, const Vector2 &p_fwd);
	PackedVector2Array get_positions() const;
	PackedVector2Array get_velocities() const;
	int get_type(int p_id) const;
	int get_faction(int p_id) const;
	Color get_color(int p_id) const;
	// N2 存储段：原生持有 SoA；积分/回收语义与 GDScript 内核 1:1。
	void reserve(int p_n);
	void set_cull(const Rect2 &p_cull);
	void set_margin(float p_margin);
	void set_default_life(float p_life);
	void set_field(float p_left, float p_right, float p_top);
	void set_seed(int p_seed);
	// L3.5-1：判定（与 GDScript 内核 1:1）
	void set_hitbox(int p_id, float p_radius, const Vector2 &p_offset, const Vector2 &p_size, bool p_follow_dir, float p_dir_offset);
	bool hit_test(int p_id, const Vector2 &p_center, float p_radius) const;
	PackedInt32Array query_circle(const Vector2 &p_center, float p_search_radius) const;
	// 宽相是否已启用（诊断 / 测试；调用过 query_circle 后才反映最近一次重建结果）。
	bool is_broadphase_active() const;
	// L3.5-4a：批量重叠（几何整体下沉，杜绝 O(弹×目标) 次跨界）。返回扁平对 [bullet, target, ...]。
	PackedInt32Array overlap_pairs(int p_faction, const PackedVector2Array &p_targets, const PackedFloat32Array &p_radii) const;
	PackedColorArray get_colors() const;
	PackedInt32Array get_type_indices() const;
	PackedInt32Array get_factions() const;
	PackedByteArray get_factions_bytes() const;
	void _run_behavior_pass(float p_dt, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchor_base);
	Dictionary _events_dict() const;
	// L3.5-3：无状态行为批（数组进/出，不做 swap；回收由调用方按 dead 重放）—— 与 integrate_batch 同款模式。
	Dictionary behavior_batch(int p_count, const PackedVector2Array &p_pos, const PackedVector2Array &p_vel,
			const PackedFloat32Array &p_life, const PackedFloat32Array &p_fx,
			const PackedInt32Array &p_program, const PackedInt32Array &p_phase, const PackedInt32Array &p_tick,
			const PackedFloat32Array &p_elapsed, const PackedFloat32Array &p_slots,
			double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies,
			const PackedVector2Array &p_anchor_base = PackedVector2Array());
	bool is_grazed(int p_id) const;
	void mark_grazed(int p_id);
	void clear();
	int despawn(int p_id);
	void set_life(int p_id, float p_life);
	void set_fx(int p_id, float p_fx);
	void set_fx_type(int p_id, int p_fx_type);
	int get_fx_type(int p_id) const;
	PackedInt32Array get_fx_type_indices() const;
	// 纯特效行：_type=-1、无速度/碰撞，寿命=相位=p_life（到期 integrate 回收）。faction 只定渲染分批。
	int spawn_fx(int p_fx_type, const Vector2 &p_pos, const Color &p_color, int p_faction, float p_life);
	void set_timer(int p_id, float p_timer);
	void set_velocity(int p_id, const Vector2 &p_vel);
	void set_position(int p_id, const Vector2 &p_pos);
	float get_life_left(int p_id) const;
	float get_fx_phase(int p_id) const;
	float get_timer(int p_id) const;
	PackedFloat32Array get_life_lefts() const;
	PackedFloat32Array get_fx_phases() const;
	PackedFloat32Array get_timers() const;
	PackedFloat32Array get_render_rots() const;
	int get_capacity() const;
	void fill_multimesh(const Ref<MultiMesh> &p_mm) const;

	// N2.2：无状态「积分加速器」——对宿主传入的 SoA 数组跑完整积分/寿命/出生相位/剔除循环，
	// 返回新数组 + 本帧应回收的行 id（**不做 swap**：回收由 GDScript 侧按既有契约重放，
	// 保证颜色/行为等 GDScript 专有字段的行身份一致）。数组按值 CoW 进出，无跨帧状态。
	void _swap_remove(int p_id);
	void _ensure_capacity(int p_n);
	// L3.5-4b-pre：宽相网格（惰性重建；与 GDScript `_ensure_broadphase/_rebuild_broadphase/_cell_index` 同序）。
	void _ensure_broadphase() const;
	void _rebuild_broadphase() const;
	int _cell_index(int p_i) const;
	PackedInt32Array _query_circle_grid(const Vector2 &p_center, float p_search_radius) const;

	// L3：注册一个编译后的 program，返回 program_id。
	int register_program(const PackedInt32Array &p_ops, const PackedFloat32Array &p_args,
			const PackedInt32Array &p_move_start, const PackedInt32Array &p_move_count,
			const PackedInt32Array &p_until, const PackedInt32Array &p_act_start,
			const PackedInt32Array &p_act_count, int p_phase_count, int p_slots);
	void set_program(int p_id, int p_program);
	// 跑一帧所有 program；返回事件（emit/sfx/call），由宿主 drain。
	Dictionary behavior_tick(double p_delta, const Vector2 &p_player, const Vector2 &p_boss, bool p_has_boss, const PackedVector2Array &p_enemies, const PackedVector2Array &p_anchor_base = PackedVector2Array());
	Vector2 _target_pos(int p_tg, const Vector2 &from, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, bool &r_ok);
	Vector2 _resolve_dir(int p_dk, int p_tg, float angle, const Vector2 &pos, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, const Vector2 &forward, float p_prob, float rnd);
	float _rng_float();
	float _rng_range(float a, float b);
	// V10：方向表达式的随机消耗点显式化（RANDOM/CHANCE 各抽一次；其余 0 次）。
	float _draw_dir_rnd(int p_dk);
	void _exec_move(int i, int prog, float *slots, int ins, float dt, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies, const PackedVector2Array &anchor_base);
	bool _check_until(int i, float *slots, int ins, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies);
	void _exec_action(int i, int prog, float *slots, int ins, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies);
	// V11：瞬时变换的单一实现（Move case 7/8 与 Action case 43/44 共用）。
	void _apply_set_heading(int i, const float *a, const Vector2 &player, const Vector2 &boss, bool has_boss, const PackedVector2Array &enemies);
	void _apply_set_speed(int i, const float *a);

	Dictionary integrate_batch(int p_count, const PackedVector2Array &p_positions, const PackedVector2Array &p_velocities, const PackedFloat32Array &p_life_left, const PackedFloat32Array &p_fx_phase, const PackedFloat32Array &p_timers, double p_delta, const Vector2 &p_cull_pos, const Vector2 &p_cull_size, float p_margin) const;

	DanmakuStore();
	~DanmakuStore();
};

} // namespace godot

#endif