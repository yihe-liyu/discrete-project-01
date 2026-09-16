## BulletLifecycle —— per-bullet 生命周期的**固定 schema 描述符** + fluent builder（L1.5）。
##
## L1.5 相对 L1 的两处修正（见 docs/LIFECYCLE_MODEL.md §3/§11）：
##   ① **状态显式化**：每个有状态 unit 自带槽（slot），builder 按相位**自动分配**；相位切换清零
##      → unit 组合不再互相污染（L1 的隐式 Dictionary 是隐藏通道：两个 phase 都 rotate 会共用 turned）。
##   ② **unit 正交化**：aim → steer(toward())；anchor+drift 合成语义单元 anchor_drift；
##      emit 收 dir 表达式；top_edge → at_wall；near_player/near_boss → near(target)。
## 创作者只调高层方法，看不到槽。
class_name BulletLifecycle
extends RefCounted

# ---- Move ----
const M_ACCEL_WORLD := &"accel_world"
const M_ACCEL_HEADING := &"accel_heading"
const M_ROTATE := &"rotate"
const M_STEER := &"steer"
const M_SPEED_LERP := &"speed_lerp"
const M_SCALE_SPEED := &"scale_speed"
const M_SET_HEADING := &"set_heading"
const M_SET_SPEED := &"set_speed"
const M_ANCHOR_DRIFT := &"anchor_drift"

# ---- Condition ----
const C_NEVER := &"never"
const C_ELAPSED := &"elapsed"
const C_NEAR := &"near"
const C_AT_WALL := &"at_wall"
const C_STATE := &"state"

# ---- Action ----
const A_EMIT := &"emit"
const A_SFX := &"sfx"
const A_DESPAWN := &"despawn"
const A_SET_HEADING := &"set_heading"
const A_SET_SPEED := &"set_speed"
const A_CALL := &"call"

# ---- 目标 / 方向 ----
const T_PLAYER := &"player"
const T_NEAREST_ENEMY := &"nearest_enemy"
const T_BOSS := &"boss"
const D_HEADING := &"heading"
const D_TOWARD := &"toward"
const D_AWAY := &"away"
const D_FORWARD := &"forward"

# ---- 墙位掩码 / 比较 ----
const WALL_LEFT := 1
const WALL_RIGHT := 2
const WALL_TOP := 4
const WALL_BOTTOM := 8
const CMP_GE := 0
const CMP_LE := 1

## 有序相位：[{moves, until, on_end}]
var phases: Array = []
## 每弹状态槽数（所有相位取最大；builder 自动分配）。
var slots: int = 0
## 结构签名缓存（content_signature；0 = 未算）
var _content_sig: int = 0

var _moves: Array = []
var _until: Dictionary = {}
var _on_end: Array = []
var _slot_next: int = 0
var _last_turn_slot: int = -1
var _last_turn_limit: float = 0.0


func _init() -> void:
	_begin_phase()


func _begin_phase() -> void:
	_moves = []
	_until = {&"op": C_NEVER}
	_on_end = []
	_slot_next = 0
	_last_turn_slot = -1
	_last_turn_limit = 0.0
	phases.append({&"moves": _moves, &"until": _until, &"on_end": _on_end})


## 开始下一相位（线性，不跳转）。
func then() -> BulletLifecycle:
	_begin_phase()
	return self


func _alloc() -> int:
	var s := _slot_next
	_slot_next += 1
	slots = maxi(slots, _slot_next)
	return s


func _set_until(op: StringName, extra: Dictionary = {}) -> void:
	_until.clear()
	_until[&"op"] = op
	for k in extra:
		_until[k] = extra[k]


# ═══ 方向表达式（静态构造，供 steer/emit/set_heading 用）═══
static func heading(angle: float) -> Dictionary:
	return {&"kind": D_HEADING, &"target": &"", &"angle": angle}

static func toward(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": D_TOWARD, &"target": target, &"angle": angle}

static func away(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": D_AWAY, &"target": target, &"angle": angle}

## 沿弹**自身朝向**（出生朝向 / set_heading 改过的）再转 angle；与 heading(世界角) 正交。
static func forward(angle: float = 0.0) -> Dictionary:
	return {&"kind": D_FORWARD, &"target": &"", &"angle": angle}


# ═══ Move ═══
func accel_world(v: Vector2) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_WORLD, &"vec": v})
	return self

func accel_heading(a: float) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_HEADING, &"a": a})
	return self

## 角速度 w（弧度/秒）；limit > 0 时累计转角钳到 limit（与 CurveBehavior 1:1）。
func rotate(w: float, limit: float = 0.0) -> BulletLifecycle:
	var s := _alloc()
	_last_turn_slot = s
	_last_turn_limit = limit
	_moves.append({&"op": M_ROTATE, &"w": w, &"limit": limit, &"slot": s})
	return self

## speed_from/speed_to 给了就同时设速度（与参考 homing 的融合一步 1:1，避免两段组合的浮点漂移）。
func steer(target: StringName, max_turn_per_sec: float, ramp: float = 0.0, dist_weight: float = 0.0, speed_from: float = NAN, speed_to: float = NAN, steer_until: float = 0.0) -> BulletLifecycle:
	_moves.append({&"op": M_STEER, &"target": target, &"max_turn": max_turn_per_sec, &"ramp": ramp, &"dist_weight": dist_weight, &"speed_from": speed_from, &"speed_to": speed_to, &"steer_until": steer_until})
	return self

func speed_lerp(from_speed: float, to_speed: float, ramp: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_LERP, &"from": from_speed, &"to": to_speed, &"ramp": ramp})
	return self

func scale_speed(f: float) -> BulletLifecycle:
	_moves.append({&"op": M_SCALE_SPEED, &"f": f})
	return self

func set_heading(dir: Dictionary) -> BulletLifecycle:
	_moves.append({&"op": M_SET_HEADING, &"dir": dir})
	return self

func set_speed(speed: float) -> BulletLifecycle:
	_moves.append({&"op": M_SET_SPEED, &"speed": speed})
	return self

## 锚定 + 线性漂移（激光段）：pos = anchor + dir(angle) * 累计漂移。
func anchor_drift(anchor_id: int, offset: Vector2, angle: float, speed: float, use_global: bool = true, initial: float = 0.0, render_heading: bool = false) -> BulletLifecycle:
	var s := _alloc()
	_moves.append({&"op": M_ANCHOR_DRIFT, &"anchor_id": anchor_id, &"offset": offset, &"angle": angle, &"speed": speed, &"use_global": use_global, &"initial": initial, &"render_heading": render_heading, &"slot": s})
	return self


# ═══ Until ═══
func until_never() -> BulletLifecycle:
	_set_until(C_NEVER)
	return self

func until_elapsed(t: float) -> BulletLifecycle:
	_set_until(C_ELAPSED, {&"t": t})
	return self

## every > 0 = 每 every 秒才检查一次（avoid_player 的 jump）。
## every = 秒；every_ticks = 帧（与 non_mid 的 skip%3 门控 1:1）。
func until_near(target: StringName, r: float, every: float = 0.0, every_ticks: int = 0) -> BulletLifecycle:
	_set_until(C_NEAR, {&"target": target, &"r": r, &"every": every, &"every_ticks": every_ticks})
	return self

func until_at_wall(mask: int) -> BulletLifecycle:
	_set_until(C_AT_WALL, {&"mask": mask})
	return self

func until_state(slot: int, cmp: int, value: float) -> BulletLifecycle:
	_set_until(C_STATE, {&"slot": slot, &"cmp": cmp, &"value": value})
	return self

## 便捷：当前相位的 rotate 累计转角 >= 其 limit（curve 用法，不重复传 limit）。
func until_turned() -> BulletLifecycle:
	_set_until(C_STATE, {&"slot": _last_turn_slot, &"cmp": CMP_GE, &"value": _last_turn_limit})
	return self


# ═══ Action（当前相位的 on_end）═══
func sfx(key: StringName, db: float = 0.0) -> BulletLifecycle:
	_on_end.append({&"op": A_SFX, &"key": key, &"db": db})
	return self

## at_end = true 时用条件（at_wall）输出的落点，否则用当前弹位置。
## spawn = **BulletData**（推荐：可序列化、跨实例共用 program）或 **Callable（）-> BulletData**（旧写法 / oracle）。
func emit(spawn: Variant, dir: Dictionary, speed: float = 0.0, at_end: bool = false) -> BulletLifecycle:
	_on_end.append({&"op": A_EMIT, &"spawn": spawn, &"dir": dir, &"speed": speed, &"at_end": at_end})
	return self

func despawn() -> BulletLifecycle:
	_on_end.append({&"op": A_DESPAWN})
	return self

## 转向但保持速度大小（avoid / non_mid 的「逃离自机」）。
func on_end_heading(dir: Dictionary) -> BulletLifecycle:
	_on_end.append({&"op": A_SET_HEADING, &"dir": dir})
	return self

## 内容回调动作（一次性、低频）：call(pos, boss_pos, has_boss, host)。
## hook = **StringName**（推荐：注册表解析，可序列化、跨实例共用 program）或 **Callable**（旧写法 / oracle）。
func on_end_call(hook: Variant) -> BulletLifecycle:
	_on_end.append({&"op": A_CALL, &"call": hook})
	return self


# ═══ Canned preset（10 个 move 的**类型化薄包装**）═══
# 组合定义在 LifecycleCatalog.build()（唯一真相）；这里只把类型化参数转成 params 字典。

static func bounce(accel_rate: float, bounce_angle: float, spawn_speed: float, spawn: Variant,
		sfx_key: StringName = &"kira", sfx_db: float = -8.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"bounce", {
		&"accel": accel_rate, &"bounce_angle": bounce_angle, &"spawn_speed": spawn_speed,
		&"spawn": spawn, &"sfx": sfx_key, &"sfx_db": sfx_db,
	})


static func curve(w: float, limit: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"curve", {&"curve": w, &"curve_limit": limit})


static func world_accel(v: Vector2) -> BulletLifecycle:
	return LifecycleCatalog.build(&"world_accel", {&"world_accel": v})


static func accel(a: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"accel", {&"accel": a})


static func homing(angle_per_sec := deg_to_rad(720.0), accel_time := 2.0, min_speed := 500.0,
		max_speed := 2000.0, duration := 2.0, proximity_boost := 150.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"homing", {
		&"homing_angle_per_sec": angle_per_sec, &"accel_time": accel_time,
		&"min_speed": min_speed, &"max_speed": max_speed,
		&"homing_duration": duration, &"proximity_boost": proximity_boost,
	})


static func radial_accel(accel_rate: float, spawn: Variant, sfx_key: StringName = &"", sfx_db: float = 0.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"radial_accel", {
		&"accel_rate": accel_rate, &"spawn": spawn, &"sfx": sfx_key, &"sfx_db": sfx_db,
	})


static func avoid_player(proximity: float, jump: float, flee_time: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"avoid_player", {
		&"player_proximity": proximity, &"jump": jump, &"flee_time": flee_time,
	})


static func non_mid_flee(proximity: float, boss_radius: float, burst: Variant) -> BulletLifecycle:
	return LifecycleCatalog.build(&"non_mid_flee", {
		&"player_proximity": proximity, &"boss_radius": boss_radius, &"hook": burst,
	})


static func laser_follow(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"laser_follow", {
		&"anchor_id": anchor_id, &"anchor_offset": offset, &"angle": angle,
		&"drift_speed": drift_speed, &"initial_drift": initial_drift,
	})


static func marisa_laser(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"marisa_laser", {
		&"anchor_id": anchor_id, &"anchor_offset": offset, &"angle": angle,
		&"drift_speed": drift_speed, &"initial_drift": initial_drift,
	})


## 锚点解析（**唯一真相**；原生/参考解释器/测试都走它，避免两套语义漂移）：
##   anchor_id=0       → player + offset
##   use_global=true   → 锚点 global_position + offset（marisa 子机是 World 兄弟）
##   use_global=false  → player + 锚点局部 position（focus 子机是 player 子节点；
##                       **不读 global**，父级移动后 global 会滞后一帧 → 根部多偏 v·dt）
static func anchor_base(anchor_id: int, offset: Vector2, use_global: bool, player: Vector2) -> Vector2:
	if anchor_id != 0:
		var node: Object = instance_from_id(anchor_id)
		if node is Node2D:
			if use_global:
				return (node as Node2D).global_position + offset
			return player + (node as Node2D).position
	return player + offset


# ═══ L3：编译成原生可读的 packed program ═══
# op / target / dirk / cmp 的整数编码**必须与 C++ DanmakuStore.behavior_tick 一致**。
const ARGS := 8

const OP_M_ACCEL_WORLD := 1
const OP_M_ACCEL_HEADING := 2
const OP_M_ROTATE := 3
const OP_M_STEER := 4
const OP_M_SPEED_LERP := 5
const OP_M_SCALE_SPEED := 6
const OP_M_SET_HEADING := 7
const OP_M_SET_SPEED := 8
const OP_M_ANCHOR_DRIFT := 9
const OP_C_NEVER := 20
const OP_C_ELAPSED := 21
const OP_C_NEAR := 22
const OP_C_AT_WALL := 23
const OP_C_STATE := 24
const OP_A_EMIT := 40
const OP_A_SFX := 41
const OP_A_DESPAWN := 42
const OP_A_SET_HEADING := 43
const OP_A_SET_SPEED := 44
const OP_A_CALL := 45

const TG_PLAYER := 0
const TG_NEAREST := 1
const TG_BOSS := 2
const DK_HEADING := 0
const DK_TOWARD := 1
const DK_AWAY := 2
const DK_FORWARD := 3   ## 沿弹自身朝向（与速度解耦）

## 编译为扁平 packed program。actions / sfx 是**程序级**表：事件回传 (program, local_id)，
## 由宿主查这两张表（Callable 永不进原生）。
func compile() -> Dictionary:
	var ops := PackedInt32Array()
	var args := PackedFloat32Array()
	var move_start := PackedInt32Array()
	var move_count := PackedInt32Array()
	var until_idx := PackedInt32Array()
	var act_start := PackedInt32Array()
	var act_count := PackedInt32Array()
	var actions: Array = []
	var sfx_keys: Array[StringName] = []
	for phase in phases:
		var mv: Array = phase[&"moves"]
		move_start.append(ops.size())
		move_count.append(mv.size())
		for m in mv:
			_emit(ops, args, _op_move(m[&"op"]), _args_move(m))
		until_idx.append(ops.size())
		_emit(ops, args, _op_cond(phase[&"until"][&"op"]), _args_cond(phase[&"until"]))
		var acts: Array = phase[&"on_end"]
		act_start.append(ops.size())
		act_count.append(acts.size())
		for a in acts:
			_emit(ops, args, _op_act(a[&"op"]), _args_act(a, actions, sfx_keys))
	return {
		&"ops": ops, &"args": args,
		&"move_start": move_start, &"move_count": move_count,
		&"until_idx": until_idx,
		&"act_start": act_start, &"act_count": act_count,
		&"phase_count": phases.size(), &"slots": slots,
		&"actions": actions, &"sfx": sfx_keys,
	}


## 结构签名（内容哈希，**不含实例身份**）：相同结构的 lifecycle 共用一个原生 program。
## 首次调用后缓存。actions（Callable）按**对象身份**参与 —— 结构相同但工厂不同的必须分开
## （program 的动作表按 program 存，串了就会调错工厂）。
func content_signature() -> int:
	if _content_sig != 0:
		return _content_sig
	var c := compile()
	var h: int = hash(c[&"ops"])
	h = h * 31 + hash(c[&"args"])
	h = h * 31 + hash(c[&"move_start"])
	h = h * 31 + hash(c[&"move_count"])
	h = h * 31 + hash(c[&"until_idx"])
	h = h * 31 + hash(c[&"act_start"])
	h = h * 31 + hash(c[&"act_count"])
	h = h * 31 + int(c[&"phase_count"]) * 7 + int(c[&"slots"])
	h = h * 31 + hash(c[&"sfx"])
	for a in c[&"actions"]:
		if a is Callable:
			h = h * 31 + (a.get_object_id() if a.is_valid() else 0)
		elif a is BulletData:
			h = h * 31 + a.get_instance_id()
		elif a is StringName:
			h = h * 31 + hash(a)
	_content_sig = h if h != 0 else 1
	return _content_sig


func _emit(ops: PackedInt32Array, args: PackedFloat32Array, op: int, a: Array) -> void:
	ops.append(op)
	for i in ARGS:
		args.append(float(a[i]) if i < a.size() else 0.0)


func _op_move(op: StringName) -> int:
	match op:
		M_ACCEL_WORLD: return OP_M_ACCEL_WORLD
		M_ACCEL_HEADING: return OP_M_ACCEL_HEADING
		M_ROTATE: return OP_M_ROTATE
		M_STEER: return OP_M_STEER
		M_SPEED_LERP: return OP_M_SPEED_LERP
		M_SCALE_SPEED: return OP_M_SCALE_SPEED
		M_SET_HEADING: return OP_M_SET_HEADING
		M_SET_SPEED: return OP_M_SET_SPEED
		M_ANCHOR_DRIFT: return OP_M_ANCHOR_DRIFT
	return 0


func _op_cond(op: StringName) -> int:
	match op:
		C_NEVER: return OP_C_NEVER
		C_ELAPSED: return OP_C_ELAPSED
		C_NEAR: return OP_C_NEAR
		C_AT_WALL: return OP_C_AT_WALL
		C_STATE: return OP_C_STATE
	return 0


func _op_act(op: StringName) -> int:
	match op:
		A_EMIT: return OP_A_EMIT
		A_SFX: return OP_A_SFX
		A_DESPAWN: return OP_A_DESPAWN
		A_SET_HEADING: return OP_A_SET_HEADING
		A_SET_SPEED: return OP_A_SET_SPEED
		A_CALL: return OP_A_CALL
	return 0


func _target_code(t: StringName) -> int:
	match t:
		T_PLAYER: return TG_PLAYER
		T_NEAREST_ENEMY: return TG_NEAREST
		T_BOSS: return TG_BOSS
	return -1


func _dir_args(d: Dictionary) -> Array:
	var dk := DK_HEADING
	if d[&"kind"] == D_TOWARD:
		dk = DK_TOWARD
	elif d[&"kind"] == D_AWAY:
		dk = DK_AWAY
	elif d[&"kind"] == D_FORWARD:
		dk = DK_FORWARD
	return [dk, _target_code(d[&"target"]), float(d[&"angle"])]


func _args_move(m: Dictionary) -> Array:
	match m[&"op"]:
		M_ACCEL_WORLD: return [Vector2(m[&"vec"]).x, Vector2(m[&"vec"]).y]
		M_ACCEL_HEADING: return [float(m[&"a"])]
		M_ROTATE: return [float(m[&"w"]), float(m[&"limit"]), float(m[&"slot"])]
		M_STEER: return [_target_code(m[&"target"]), float(m[&"max_turn"]), float(m[&"ramp"]), float(m[&"dist_weight"]), float(m[&"speed_from"]), float(m[&"speed_to"]), float(m[&"steer_until"])]
		M_SPEED_LERP: return [float(m[&"from"]), float(m[&"to"]), float(m[&"ramp"])]
		M_SCALE_SPEED: return [float(m[&"f"])]
		M_SET_HEADING: return _dir_args(m[&"dir"])
		M_SET_SPEED: return [float(m[&"speed"])]
		M_ANCHOR_DRIFT:
			var flags := 0.0
			if bool(m[&"use_global"]): flags += 1.0
			if bool(m[&"render_heading"]): flags += 2.0
			var off := Vector2(m[&"offset"])
			return [float(m[&"anchor_id"]), off.x, off.y, float(m[&"angle"]), float(m[&"speed"]), flags, float(m[&"initial"]), float(m[&"slot"])]
	return []


func _args_cond(c: Dictionary) -> Array:
	match c[&"op"]:
		C_ELAPSED: return [float(c[&"t"])]
		C_NEAR: return [_target_code(c[&"target"]), float(c[&"r"]), float(c[&"every"]), float(c[&"every_ticks"])]
		C_AT_WALL: return [float(c[&"mask"])]
		C_STATE: return [float(c[&"slot"]), float(c[&"cmp"]), float(c[&"value"])]
	return []


func _args_act(a: Dictionary, actions: Array, sfx_keys: Array[StringName]) -> Array:
	match a[&"op"]:
		A_EMIT:
			var aid := actions.size()
			actions.append(a[&"spawn"])
			return [float(aid)] + _dir_args(a[&"dir"]) + [float(a[&"speed"]), 1.0 if bool(a[&"at_end"]) else 0.0]
		A_SFX:
			var sid := sfx_keys.size()
			sfx_keys.append(a[&"key"])
			return [float(sid), float(a[&"db"])]
		A_SET_HEADING: return _dir_args(a[&"dir"])
		A_SET_SPEED: return [float(a[&"speed"])]
		A_CALL:
			var cid := actions.size()
			actions.append(a[&"call"])
			return [float(cid)]
	return []
