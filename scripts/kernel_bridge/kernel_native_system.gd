## KernelNativeSystem —— 原生权威存储 + 原生积分/行为/判定（L3.5-4e）。
##
## 归属：**桥接层**。原生 `DanmakuStore` 是**唯一存储**（spawn / despawn / integrate / behavior / collision）。
## 本类维护 GDScript 侧的表（BulletType / render_fade）与**每帧只读快照**，供渲染 / 物理 / 调试**零改**读取。
##
## **契约**：消费方在遍历中 `despawn` **必须倒序** —— 快照在帧内不即时更新；倒序时被 swap 进来的尾行
## 索引更大、已处理过，故安全（现状已如此）。
## 未加载扩展时 `is_native_ready() = false`，调用方退回纯 GDScript 内核（`super`）。
class_name KernelNativeSystem
extends BulletSystem

var _accel: Object = null
## 诊断计数器：真正走了原生路径的帧数。
var native_frames: int = 0

# ── 原生行为执行（由 KernelBulletBackend 装配）──
var native_behaviors: bool = false
var behavior_ctx: BehaviorContext
var behavior_host          # KernelBehaviorHost
var boss_getter: Callable

var _catalog := LifecycleCatalog.new()
var _program_data: Array = []
## 与 _program_data 对齐：每个 program 的锚点参数（无锚点 = null）。
var _program_anchors: Array = []
var _sig_to_program: Dictionary = {}


func _init() -> void:
	super()
	_ensure_native()


func _ensure_native() -> void:
	if _accel == null and ClassDB.class_exists("DanmakuStore"):
		_accel = ClassDB.instantiate("DanmakuStore")
		_accel.setup(initial_capacity, cull_rect)
		# 原生侧不知宿主场域常量：注入（at_wall 判定用）。
		_accel.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
		_accel.set_margin(cull_margin)
		_accel.set_default_life(default_lifetime)


func is_native_ready() -> bool:
	_ensure_native()
	return _accel != null


## 容量变化：基类扩 SoA；原生 store 同步 reserve（grow-only）。
func _ensure_capacity(capacity: int) -> void:
	super(capacity)
	if _accel != null:
		_accel.reserve(_positions.size())


## 发射：基类写 GDScript 快照行；原生写**权威行**（type/faction/color/life/fx/timer/hitbox/program）。
func spawn(bullet_data: BulletType, position: Vector2, velocity: Vector2, color: Color = Color.WHITE, move: StringName = &"", behavior_params: Variant = null) -> int:
	var id: int = super(bullet_data, position, velocity, color, move, behavior_params)
	if _accel != null:
		var nid: int = _accel.spawn(position, velocity, _type_index[id], int(bullet_data.faction), color)
		if nid < 0:
			push_error("[KernelNativeSystem] 原生 store 溢出（capacity=%d）" % _accel.get_capacity())
			return id
		_accel.set_hitbox(nid, bullet_data.hitbox_radius, bullet_data.hitbox_offset, bullet_data.hitbox_size, bullet_data.follow_dir, bullet_data.dir_offset)
		_accel.set_life(nid, _life_left[id])
		_accel.set_fx(nid, _fx_phase[id])
		_accel.set_timer(nid, _timer[id])
		var params: Dictionary = behavior_params if behavior_params is Dictionary else {}
		var prog: int = _program_for(move, params) if native_behaviors else -1
		_accel.set_program(nid, prog)
	return id


## 回收：基类 swap 快照行 + 原生 swap 权威行（同一状态出发 → 保持同序）。
func despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	super(id)
	if _accel != null:
		_accel.despawn(id)


## 清空：两边都清。
func clear() -> void:
	super()
	if _accel != null:
		_accel.clear()


## 写访问器：快照 + 原生一起写（工具 / 测试 / 回退行为都可能调）。
func set_velocity(id: int, value: Vector2) -> void:
	super(id, value)
	if _accel != null:
		_accel.set_velocity(id, value)

func set_position(id: int, value: Vector2) -> void:
	super(id, value)
	if _accel != null:
		_accel.set_position(id, value)

# 基类没有 set_life / set_fx（只有行数组直写）→ 这里新增桥接方法：快照 + 原生一起写。
func set_life(id: int, value: float) -> void:
	_life_left[id] = value
	if _accel != null:
		_accel.set_life(id, value)

func set_fx(id: int, value: float) -> void:
	_fx_phase[id] = value
	if _accel != null:
		_accel.set_fx(id, value)

func set_timer(id: int, value: float) -> void:
	super(id, value)
	if _accel != null:
		_accel.set_timer(id, value)


## 判定：权威在原生（宽相网格）。
func query_circle(center: Vector2, search_radius: float) -> PackedInt32Array:
	if _accel != null:
		return _accel.query_circle(center, search_radius)
	return super(center, search_radius)

func hit_test(id: int, center: Vector2, radius: float) -> bool:
	if _accel != null:
		return _accel.hit_test(id, center, radius)
	return super(id, center, radius)

func is_grazed(id: int) -> bool:
	return _accel.is_grazed(id) if _accel != null else super(id)

func mark_grazed(id: int) -> void:
	if _accel != null:
		_accel.mark_grazed(id)
	else:
		super(id)


## move+params → 原生 program（编译 + 注册，按签名缓存）。
func _program_for(move: StringName, params: Dictionary) -> int:
	if _accel == null:
		return -1
	var sig: int = LifecycleCatalog.signature(move, params)
	if _sig_to_program.has(sig):
		return _sig_to_program[sig]
	var lc: BulletLifecycle = _catalog.get_lifecycle(move, params)
	var pid: int = -1
	if lc != null:
		var c: Dictionary = lc.compile()
		var expected: int = _program_data.size()
		pid = _accel.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
		if pid != expected:
			push_error("[KernelNativeSystem] program 对齐失败：native pid=%d, 期望 %d" % [pid, expected])
		_program_data.append(c)
		_program_anchors.append(_anchor_spec_for(move, params))
	_sig_to_program[sig] = pid
	return pid


## program 是否要每帧解析锚点 base（marisa=global 兄弟 / laser_follow=player 子节点）。
func _anchor_spec_for(move: StringName, params: Dictionary) -> Variant:
	match move:
		&"marisa_laser":
			return {&"id": int(params.get(&"anchor_id", 0)), &"offset": params.get(&"anchor_offset", Vector2.ZERO), &"use_global": true}
		&"laser_follow":
			return {&"id": int(params.get(&"anchor_id", 0)), &"offset": params.get(&"anchor_offset", Vector2.ZERO), &"use_global": false}
	return null


## 覆写：原生**有状态**积分 + 行为（原生 store 内部 swap-remove dead）→ 每帧 pull 快照。
func _physics_process(delta: float) -> void:
	_ensure_native()
	if _accel == null:
		super(delta)
		return
	_last_delta = delta
	_accel.set_cull(cull_rect)
	_accel.set_margin(cull_margin)
	_accel.set_default_life(default_lifetime)
	if _accel.get_active_count() == 0:
		_pull_snapshot()
		return
	native_frames += 1
	_accel.integrate(delta)
	if native_behaviors:
		_run_native_behaviors(delta)
	_pull_snapshot()


func _run_native_behaviors(delta: float) -> void:
	if _accel.get_active_count() == 0:
		return
	var player := Vector2.ZERO
	var enemies := PackedVector2Array()
	if behavior_ctx != null:
		player = behavior_ctx.get_player_position()
		for e in behavior_ctx.get_world().get_enemies():
			enemies.append(e.global_position)
	var boss = boss_getter.call() if boss_getter.is_valid() else null
	var has_boss: bool = is_instance_valid(boss)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	# 锚点每帧解析成 program 级 base（原生不认 instance id）。无锚点的 program 填 player 占位。
	var anchor_base := PackedVector2Array()
	anchor_base.resize(_program_data.size())
	for apid in _program_data.size():
		var spec: Variant = _program_anchors[apid] if apid < _program_anchors.size() else null
		anchor_base[apid] = player if spec == null else BulletLifecycle.anchor_base(spec[&"id"], spec[&"offset"], spec[&"use_global"], player)
	var res: Dictionary = _accel.behavior_tick(delta, player, boss_pos, has_boss, enemies, anchor_base)
	_drain_events(res, has_boss, boss_pos)


## 每帧把原生权威 SoA pull 成 GDScript **只读快照**（渲染 / 物理 / 调试零改读它）。
func _pull_snapshot() -> void:
	_active_count = _accel.get_active_count()
	_positions = _accel.get_positions()
	_velocities = _accel.get_velocities()
	_color = _accel.get_colors()
	_type_index = _accel.get_type_indices()
	_faction = _accel.get_factions_bytes()
	_life_left = _accel.get_life_lefts()
	_fx_phase = _accel.get_fx_phases()
	_timer = _accel.get_timers()


func _drain_events(res: Dictionary, has_boss: bool, boss_pos: Vector2) -> void:
	var kinds: PackedInt32Array = res.kind
	if kinds.is_empty():
		return
	var local: PackedInt32Array = res.local
	var xs: PackedFloat32Array = res.x
	var ys: PackedFloat32Array = res.y
	var dxs: PackedFloat32Array = res.dx
	var dys: PackedFloat32Array = res.dy
	var vals: PackedFloat32Array = res.val
	# 事件携带自己的 program（eprog）；**不能**用 per-bullet program 去反查 ——
	# 两者在本调用内不一致会静默错派（历史 bug，见 BEST_PRACTICES_LOG）。
	var eprog: PackedInt32Array = res.eprog
	for k in kinds.size():
		var prog: int = eprog[k]
		if prog < 0 or prog >= _program_data.size():
			continue
		var c: Dictionary = _program_data[prog]
		match kinds[k]:
			0:
				var factory: Callable = c["actions"][local[k]]
				var b = factory.call()
				if b != null and behavior_host != null:
					b.velocity = Vector2(0.0, vals[k])
					behavior_host.queue_spawn(b, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]))
			1:
				var key: StringName = c["sfx"][local[k]]
				var stream = AssetRegistry.sounds.get(String(key), null)
				if stream != null:
					AudioManager.play_sfx(stream, vals[k])
			2:
				(c["actions"][local[k]] as Callable).call(Vector2(xs[k], ys[k]), boss_pos, has_boss, behavior_host)
