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

# ---- 目标 / 方向 ----
const T_PLAYER := &"player"
const T_NEAREST_ENEMY := &"nearest_enemy"
const T_BOSS := &"boss"
const D_HEADING := &"heading"
const D_TOWARD := &"toward"
const D_AWAY := &"away"

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

func steer(target: StringName, max_turn_per_sec: float, ramp: float = 0.0, dist_weight: float = 0.0) -> BulletLifecycle:
	_moves.append({&"op": M_STEER, &"target": target, &"max_turn": max_turn_per_sec, &"ramp": ramp, &"dist_weight": dist_weight})
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
func anchor_drift(anchor_id: int, offset: Vector2, angle: float, speed: float, use_global: bool = true) -> BulletLifecycle:
	var s := _alloc()
	_moves.append({&"op": M_ANCHOR_DRIFT, &"anchor_id": anchor_id, &"offset": offset, &"angle": angle, &"speed": speed, &"use_global": use_global, &"slot": s})
	return self


# ═══ Until ═══
func until_never() -> BulletLifecycle:
	_set_until(C_NEVER)
	return self

func until_elapsed(t: float) -> BulletLifecycle:
	_set_until(C_ELAPSED, {&"t": t})
	return self

## every > 0 = 每 every 秒才检查一次（avoid_player 的 jump）。
func until_near(target: StringName, r: float, every: float = 0.0) -> BulletLifecycle:
	_set_until(C_NEAR, {&"target": target, &"r": r, &"every": every})
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
func emit(factory: Callable, dir: Dictionary, speed: float = 0.0, at_end: bool = false) -> BulletLifecycle:
	_on_end.append({&"op": A_EMIT, &"factory": factory, &"dir": dir, &"speed": speed, &"at_end": at_end})
	return self

func despawn() -> BulletLifecycle:
	_on_end.append({&"op": A_DESPAWN})
	return self

## 转向但保持速度大小（avoid / non_mid 的「逃离自机」）。
func on_end_heading(dir: Dictionary) -> BulletLifecycle:
	_on_end.append({&"op": A_SET_HEADING, &"dir": dir})
	return self


# ═══ Canned preset（现有行为 → 命名组合；创作者也可自己拼）═══
static func bounce(accel: float, bounce_angle: float, spawn_speed: float, factory: Callable,
		sfx_key: StringName = &"kira", sfx_db: float = -8.0) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_heading(accel)
	lc.until_at_wall(WALL_LEFT | WALL_RIGHT | WALL_TOP)
	if sfx_key != &"":
		lc.sfx(sfx_key, sfx_db)
	lc.emit(factory, toward(T_BOSS, bounce_angle), spawn_speed, true)
	lc.despawn()
	return lc

static func curve(w: float, limit: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.rotate(w, limit)
	lc.until_turned()
	lc.then()
	return lc

static func world_accel(v: Vector2) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_world(v)
	return lc

static func accel(a: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_heading(a)
	return lc
