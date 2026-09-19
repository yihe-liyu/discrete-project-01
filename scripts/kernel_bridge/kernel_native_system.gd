## KernelNativeSystem —— 原生权威弹幕存储（L3.5-4e/4f）。
##
## 归属：**桥接层**。原生 `DanmakuStore` 是**唯一存储**（spawn / despawn / integrate / behavior / collision）。
## 本类维护 GDScript 侧的表（BulletType / render_fade / spawn_fx）与**每帧只读快照**，
## 供渲染 / 物理 / 调试读取；**不再依赖 GDScript BulletSystem**（4f 拆掉 scaffold）。
##
## **契约**：消费方在遍历中 `despawn` **必须倒序** —— 快照在帧内不即时更新；倒序时被 swap 进来的
## 尾行索引更大、已处理过，故安全（现状已如此）。
class_name KernelNativeSystem
extends Node
const LIFECYCLE_HOOKS_SCRIPT = preload("res://scripts/kernel_bridge/lifecycle/lifecycle_hooks.gd")

@export_group("Pool")
@export var initial_capacity: int = 1024
## 默认最长存活秒数；<=0 = 由行为/超时决定。
@export var default_lifetime: float = 20.0

@export_group("World bounds (cull)")
## 世界坐标失效区：超出即回收；空 = 不剔除。
@export var cull_rect: Rect2
## 剔除余量。
@export var cull_margin: float = 32.0

var _accel: Object = null
## 内核 RNG 种子（宿主 RNG 派生；原生 store 建好/重播种时应用）
var _seed: int = 0
## 诊断计数器：真正走了原生路径的帧数。
var native_frames: int = 0

# ── 原生行为执行（由 KernelBulletHost 装配）──
var enable_native_behaviors: bool = false
var behavior_ctx: BehaviorContext
var behavior_host          # KernelBehaviorHost
var boss_getter: Callable

# ── 每帧只读快照（pull 自原生权威 SoA）──
var _active_count: int = 0
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _color := PackedColorArray()
var _type_index := PackedInt32Array()      # 行 → _type_registry 下标
var _faction := PackedByteArray()
var _life_left := PackedFloat32Array()
var _fx_phase := PackedFloat32Array()
var _fx_type_index := PackedInt32Array()   # 行 → _fx_registry 下标（-1 = 无特效）
var _timer := PackedFloat32Array()
var _render_rot := PackedFloat32Array()   # V19：逐弹渲染朝向覆盖（NAN = 用 velocity 推）

# ── 宿主侧表 ──
var _type_registry: Array[BulletType] = []
var _render_fade: Dictionary = {}          # Kind → 整批淡出 0..1
var _spawn_fx: Dictionary = {}             # Faction → 出生特效 EffectType
var _fx_registry: Array[EffectType] = []   # 特效表（发弹/消弹共用；行按下标引用）

## 确定性 RNG（宿主 seed；N3 后行为已原生，仅保留宿主接口）。
var _random := RandomNumberGenerator.new()

# ── 原生 program（move+params → packed）──
var _catalog := LifecycleCatalog.new()
var _program_data: Array = []
var _program_anchors: Array = []
var _sig_to_program: Dictionary = {}


func _init() -> void:
	_ensure_native()


func _ensure_native() -> void:
	if _accel == null and ClassDB.class_exists("DanmakuStore"):
		_accel = ClassDB.instantiate("DanmakuStore")
		_accel.setup(initial_capacity, cull_rect)
		_accel.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
		_accel.set_margin(cull_margin)
		_accel.set_default_life(default_lifetime)
		_accel.set_seed(_seed)


func is_native_ready() -> bool:
	_ensure_native()
	return _accel != null


# ═══ 容量 ═══

func _ensure_capacity(capacity: int) -> void:
	if _positions.size() >= capacity:
		return
	var n: int = maxi(maxi(capacity, _positions.size() * 2), 16)
	_positions.resize(n)
	_velocities.resize(n)
	_color.resize(n)
	_type_index.resize(n)
	_faction.resize(n)
	_life_left.resize(n)
	_fx_phase.resize(n)
	_fx_type_index.resize(n)
	_timer.resize(n)
	_render_rot.resize(n)
	if _accel != null:
		_accel.reserve(n)


# ═══ 发射 / 回收 ═══

## 弹型懒注册（find or append），返回下标。
func _type_registry_index_of(bullet_type: BulletType) -> int:
	var idx := _type_registry.find(bullet_type)
	if idx == -1:
		idx = _type_registry.size()
		_type_registry.append(bullet_type)
	return idx


## 某阵营的出生特效（改一处全变）。注册进特效表，渲染端按行下标取贴图/参数。
func set_spawn_fx(faction: BulletType.Faction, effect: EffectType) -> void:
	_spawn_fx[faction] = effect
	if effect != null:
		_fx_registry_index_of(effect)


## 特效懒注册（find or append），返回下标；渲染端经 get_fx_registry() 取下标的贴图。
func _fx_registry_index_of(effect: EffectType) -> int:
	var idx := _fx_registry.find(effect)
	if idx == -1:
		idx = _fx_registry.size()
		_fx_registry.append(effect)
	return idx


func _set_row_fx(id: int, effect: EffectType) -> void:
	if effect != null and effect.duration > 0.0:
		_fx_phase[id] = effect.duration
		_fx_type_index[id] = _fx_registry_index_of(effect)
	else:
		_fx_phase[id] = 0.0
		_fx_type_index[id] = -1


## 发射（写快照行 + 原生权威行）。
func spawn(bullet_data: BulletType, position: Vector2, velocity: Vector2, color: Color = Color.WHITE, move: StringName = &"", behavior_params: Variant = null) -> int:
	var ti := _type_registry_index_of(bullet_data)
	var id := _active_count
	_ensure_capacity(id + 1)
	_active_count += 1
	_positions[id] = position
	_velocities[id] = velocity
	_color[id] = color
	_type_index[id] = ti
	_faction[id] = bullet_data.faction
	_life_left[id] = default_lifetime
	_timer[id] = 0.0
	_render_rot[id] = NAN
	var effect: EffectType = null
	if bullet_data.is_spawn_fog:
		effect = bullet_data.spawn_fx if bullet_data.spawn_fx != null else _spawn_fx.get(bullet_data.faction)
	_set_row_fx(id, effect)
	if _accel != null:
		var nid: int = _accel.spawn(position, velocity, ti, int(bullet_data.faction), color)
		if nid < 0:
			push_error("[KernelNativeSystem] 原生 store 溢出（capacity=%d）" % _accel.get_capacity())
			return id
		_accel.set_hitbox(nid, bullet_data.hitbox_radius, bullet_data.hitbox_offset, bullet_data.hitbox_size, bullet_data.follow_dir, bullet_data.dir_offset)
		_accel.set_life(nid, _life_left[id])
		_accel.set_fx(nid, _fx_phase[id])
		_accel.set_fx_type(nid, _fx_type_index[id])
		_accel.set_timer(nid, _timer[id])
		# program 在发射时就绑定（与 enable_native_behaviors 是否执行无关）；未映射 move → -1。
		var params: Dictionary = behavior_params if behavior_params is Dictionary else {}
		var prog: int = _program_for(move, params)
		_accel.set_program(nid, prog)
	return id


## 播一条纯特效行（消弹/爆发）：无弹型、无碰撞，寿命 = effect.duration（原生 integrate 到期回收）。
## 返回行 id；effect 为空或时长为 0 → -1（静默）。
func spawn_fx(effect: EffectType, position: Vector2, color: Color = Color.WHITE, faction: BulletType.Faction = BulletType.Faction.ENEMY) -> int:
	if effect == null or effect.duration <= 0.0:
		return -1
	var fi := _fx_registry_index_of(effect)
	var id := _active_count
	_ensure_capacity(id + 1)
	_active_count += 1
	_positions[id] = position
	_velocities[id] = Vector2.ZERO
	_color[id] = color
	_type_index[id] = -1
	_faction[id] = faction
	_life_left[id] = effect.duration
	_fx_phase[id] = effect.duration
	_fx_type_index[id] = fi
	_timer[id] = 0.0
	_render_rot[id] = NAN
	if _accel != null:
		_accel.spawn_fx(fi, position, color, int(faction), effect.duration)
	return id


## 回收：快照 swap-with-last（供帧内一致性）+ 原生权威 swap。
func despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	var tail := _active_count - 1
	if id != tail:
		_positions[id] = _positions[tail]
		_velocities[id] = _velocities[tail]
		_color[id] = _color[tail]
		_type_index[id] = _type_index[tail]
		_faction[id] = _faction[tail]
		_life_left[id] = _life_left[tail]
		_fx_phase[id] = _fx_phase[tail]
		_fx_type_index[id] = _fx_type_index[tail]
		_timer[id] = _timer[tail]
		_render_rot[id] = _render_rot[tail]
	_active_count -= 1
	if _accel != null:
		_accel.despawn(id)


func clear() -> void:
	_active_count = 0
	if _accel != null:
		_accel.clear()


# ═══ 写访问器（工具 / 回退 / 测试）═══

func set_velocity(id: int, value: Vector2) -> void:
	_velocities[id] = value
	if _accel != null:
		_accel.set_velocity(id, value)


## 直接设定世界位置（锚定型行为用；普通行为请用 set_velocity）。
func set_position(id: int, value: Vector2) -> void:
	_positions[id] = value
	if _accel != null:
		_accel.set_position(id, value)


func set_life(id: int, value: float) -> void:
	_life_left[id] = value
	if _accel != null:
		_accel.set_life(id, value)


func set_fx(id: int, value: float) -> void:
	_fx_phase[id] = value
	if _accel != null:
		_accel.set_fx(id, value)


func set_timer(id: int, value: float) -> void:
	_timer[id] = value
	if _accel != null:
		_accel.set_timer(id, value)


# ═══ 判定（权威在原生；宽相网格）═══

func query_circle(center: Vector2, search_radius: float) -> PackedInt32Array:
	if _accel != null:
		return _accel.query_circle(center, search_radius)
	return PackedInt32Array()


func hit_test(id: int, center: Vector2, radius: float) -> bool:
	return _accel.hit_test(id, center, radius) if _accel != null else false


func is_grazed(id: int) -> bool:
	return _accel.is_grazed(id) if _accel != null else false


func mark_grazed(id: int) -> void:
	if _accel != null:
		_accel.mark_grazed(id)


# ═══ 读访问器（快照）═══

func get_active_count() -> int:
	return _active_count

func get_positions() -> PackedVector2Array:
	return _positions

func get_velocities() -> PackedVector2Array:
	return _velocities

func get_colors() -> PackedColorArray:
	return _color

func get_type_indices() -> PackedInt32Array:
	return _type_index

func get_factions() -> PackedByteArray:
	return _faction

## 该行弹型；越界/纯特效行 → null。
func get_type(id: int) -> BulletType:
	var ti: int = _type_index[id]
	return _type_registry[ti] if ti >= 0 and ti < _type_registry.size() else null

func get_position(id: int) -> Vector2:
	return _positions[id]

func get_velocity(id: int) -> Vector2:
	return _velocities[id]

func get_color(id: int) -> Color:
	return _color[id]

func get_life_left(id: int) -> float:
	return _life_left[id]

func get_fx_phase(id: int) -> float:
	return _fx_phase[id]

func get_timer(id: int) -> float:
	return _timer[id]

## V19：逐弹渲染朝向覆盖（NAN = 未设，渲染端按 velocity 推）。
func get_render_rots() -> PackedFloat32Array:
	return _render_rot

func get_type_registry() -> Array[BulletType]:
	return _type_registry


## 每帧快照：相位中的弹/纯特效行（渲染桥读它算缩放/淡出）。
func get_fx_phases() -> PackedFloat32Array:
	return _fx_phase


func get_fx_type_indices() -> PackedInt32Array:
	return _fx_type_index


func get_fx_registry() -> Array[EffectType]:
	return _fx_registry


## 按弹型类别（Kind）设/取整批渲染淡出（0..1）。
func set_render_fade(kind: int, value: float) -> void:
	_render_fade[kind] = clampf(value, 0.0, 1.0)

func get_render_fade(kind: int) -> float:
	return _render_fade.get(kind, 1.0)


# ═══ 确定性 RNG（宿主 seed）═══

func set_seed(seed_value: int) -> void:
	_seed = seed_value
	_random.seed = seed_value
	if _accel != null:
		_accel.set_seed(seed_value)   # 转发原生 store（行为随机走内核单通道）

func randf() -> float:
	return _random.randf()

func randf_range(from: float, to: float) -> float:
	return _random.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _random.randi_range(from, to)


# ═══ 行为 program ═══

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
		if pid < 0:
			# V20：槽数超上限被原生拒绝 —— 不 append，保持 _program_data 与原生 pid 对齐。
			push_error("[KernelNativeSystem] program 注册被拒（槽数超过 SLOT_STRIDE）")
		else:
			if pid != expected:
				push_error("[KernelNativeSystem] program 对齐失败：native pid=%d, 期望 %d" % [pid, expected])
			_program_data.append(c)
			_program_anchors.append(_anchor_spec_for(move, params))
	_sig_to_program[sig] = pid
	return pid


func _anchor_spec_for(move: StringName, params: Dictionary) -> Variant:
	if move == LifecycleCatalog.MOVE_LIFECYCLE:
		return params.get(&"anchor")
	match move:
		&"marisa_laser":
			return {&"id": int(params.get(&"anchor_id", 0)), &"offset": params.get(&"anchor_offset", Vector2.ZERO), &"use_global": true}
		&"laser_follow":
			return {&"id": int(params.get(&"anchor_id", 0)), &"offset": params.get(&"anchor_offset", Vector2.ZERO), &"use_global": false}
	return null


# ═══ 每帧 ═══

func _physics_process(delta: float) -> void:
	_ensure_native()
	if _accel == null:
		return
	_accel.set_cull(cull_rect)
	_accel.set_margin(cull_margin)
	_accel.set_default_life(default_lifetime)
	if _accel.get_active_count() == 0:
		_pull_snapshot()
		return
	native_frames += 1
	_accel.integrate(delta)
	if enable_native_behaviors:
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


## 把原生权威 SoA pull 成 GDScript 只读快照。
func _pull_snapshot() -> void:
	_active_count = _accel.get_active_count()
	_positions = _accel.get_positions()
	_velocities = _accel.get_velocities()
	_color = _accel.get_colors()
	_type_index = _accel.get_type_indices()
	_faction = _accel.get_factions_bytes()
	_life_left = _accel.get_life_lefts()
	_fx_phase = _accel.get_fx_phases()
	_fx_type_index = _accel.get_fx_type_indices()
	_timer = _accel.get_timers()
	_render_rot = _accel.get_render_rots()


## 变体发射：`src` 是模板数组时按分支号取模板（越界钳到末项）；非数组原样返回。
static func pick_variant(src: Variant, branch: int) -> Variant:
	if src is Array:
		var arr: Array = src
		if arr.is_empty():
			return null
		return arr[clampi(branch, 0, arr.size() - 1)]
	return src


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
	var variants: PackedInt32Array = res.get("variant", PackedInt32Array())
	# 事件携带自己的 program（eprog）；**不能**用 per-bullet program 去反查（历史 bug）。
	var eprog: PackedInt32Array = res.eprog
	for k in kinds.size():
		var prog: int = eprog[k]
		if prog < 0 or prog >= _program_data.size():
			continue
		var c: Dictionary = _program_data[prog]
		match kinds[k]:
			0:
				var branch: int = variants[k] if k < variants.size() else 0
				var spawn_src: Variant = pick_variant(c["actions"][local[k]], branch)
				var b = spawn_src.call() if spawn_src is Callable else spawn_src
				if b != null and behavior_host != null:
					b.velocity = Vector2(0.0, vals[k])
					behavior_host.queue_spawn(b, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]))
			1:
				var key: StringName = c["sfx"][local[k]]
				var stream = AssetRegistry.sounds.get(String(key), null)
				if stream != null:
					AudioManager.play_sfx(stream, vals[k])
			2:
				var hook: Variant = c["actions"][local[k]]
				var fn: Callable = hook if hook is Callable else LIFECYCLE_HOOKS_SCRIPT.resolve(hook)
				if fn.is_valid():
					fn.call(Vector2(xs[k], ys[k]), boss_pos, has_boss, behavior_host)
