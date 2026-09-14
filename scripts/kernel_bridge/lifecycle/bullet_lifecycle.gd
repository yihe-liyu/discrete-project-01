## BulletLifecycle —— per-bullet 生命周期的**固定 schema 描述符** + 创作者 fluent builder。
##
## 见 docs/LIFECYCLE_MODEL.md。L1 = GDScript 参考实现；L3 换原生执行器，**schema 不变**。
## 创作者只调高层方法（accel_along_vel / until_wall / emit ...），永不写数值 opcode。
class_name BulletLifecycle
extends RefCounted

# ---- Move 原语 ----
const M_ACCEL_WORLD := &"accel_world"
const M_ACCEL_ALONG_VEL := &"accel_along_vel"
const M_ROTATE := &"rotate"
const M_AIM := &"aim"
const M_ANCHOR := &"anchor"
const M_SPEED_RAMP := &"speed_ramp"
const M_SET_VEL := &"set_vel"
const M_SCALE := &"scale"

# ---- Until 条件 ----
const C_NEVER := &"never"
const C_TIMEOUT := &"timeout"
const C_TOP_EDGE := &"top_edge"
const C_WALL_HIT := &"wall_hit"
const C_NEAR_PLAYER := &"near_player"
const C_NEAR_BOSS := &"near_boss"
const C_TURNED := &"turned"

# ---- Action ----
const A_EMIT := &"emit"
const A_SFX := &"sfx"
const A_DESPAWN := &"despawn"
const A_SET_VEL := &"set_vel"

# ---- 墙位掩码 ----
const WALL_LEFT := 1
const WALL_RIGHT := 2
const WALL_TOP := 4
const WALL_BOTTOM := 8

## 有序相位：[{moves: Array, until: Dictionary, on_end: Array}]
var phases: Array = []

var _moves: Array = []
var _until: Dictionary = {}
var _on_end: Array = []


func _init() -> void:
	_begin_phase()


func _begin_phase() -> void:
	_moves = []
	_until = {&"kind": C_NEVER}
	_on_end = []
	phases.append({&"moves": _moves, &"until": _until, &"on_end": _on_end})


## 开始下一相位（线性，不跳转）。
func then() -> BulletLifecycle:
	_begin_phase()
	return self


# ═══ Move ═══
func accel_world(v: Vector2) -> BulletLifecycle:
	_moves.append({&"kind": M_ACCEL_WORLD, &"vec": v})
	return self

func accel_along_vel(a: float) -> BulletLifecycle:
	_moves.append({&"kind": M_ACCEL_ALONG_VEL, &"a": a})
	return self

## 角速度 w（弧度/秒）；limit > 0 时累计转角钳到 limit（与 CurveBehavior 1:1）。
func rotate(w: float, limit: float = 0.0) -> BulletLifecycle:
	_moves.append({&"kind": M_ROTATE, &"w": w, &"limit": limit})
	return self

func aim(max_turn_per_sec: float, dist_weight: float = 0.0) -> BulletLifecycle:
	_moves.append({&"kind": M_AIM, &"max_turn": max_turn_per_sec, &"dist_weight": dist_weight})
	return self

func speed_ramp(min_speed: float, top_speed: float, time: float) -> BulletLifecycle:
	_moves.append({&"kind": M_SPEED_RAMP, &"min": min_speed, &"top": top_speed, &"time": time})
	return self

func anchor(anchor_id: int, offset: Vector2, drift_speed: float, angle: float, use_global: bool = true) -> BulletLifecycle:
	_moves.append({&"kind": M_ANCHOR, &"anchor_id": anchor_id, &"offset": offset, &"drift": drift_speed, &"angle": angle, &"use_global": use_global})
	return self

func set_vel(dir: Vector2, speed: float) -> BulletLifecycle:
	_moves.append({&"kind": M_SET_VEL, &"dir": dir, &"speed": speed})
	return self

func scale(f: float) -> BulletLifecycle:
	_moves.append({&"kind": M_SCALE, &"f": f})
	return self


# ═══ Until ═══
## 原地改（不重新赋值）——phases[0].until 持有同一个 Dictionary 引用，重赋值会让条件丢失。
func _set_until(kind: StringName, extra: Dictionary = {}) -> void:
	_until.clear()
	_until[&"kind"] = kind
	for k in extra:
		_until[k] = extra[k]

func until_never() -> BulletLifecycle:
	_set_until(C_NEVER)
	return self

func until_timeout(t: float) -> BulletLifecycle:
	_set_until(C_TIMEOUT, {&"t": t})
	return self

func until_top_edge() -> BulletLifecycle:
	_set_until(C_TOP_EDGE)
	return self

func until_wall(mask: int) -> BulletLifecycle:
	_set_until(C_WALL_HIT, {&"mask": mask})
	return self

func until_near_player(r: float) -> BulletLifecycle:
	_set_until(C_NEAR_PLAYER, {&"r": r})
	return self

func until_near_boss(r: float) -> BulletLifecycle:
	_set_until(C_NEAR_BOSS, {&"r": r})
	return self

func until_turned(limit: float) -> BulletLifecycle:
	_set_until(C_TURNED, {&"limit": limit})
	return self

# ═══ Action ═══
## 相位结束时发射替换弹：factory 返回 BulletData；aim_boss 时朝 Boss（无则 DOWN），再旋转 angle。
func on_end_emit(factory: Callable, aim_boss: bool = false, angle: float = 0.0, speed: float = 0.0) -> BulletLifecycle:
	_on_end.append({&"kind": A_EMIT, &"factory": factory, &"aim_boss": aim_boss, &"angle": angle, &"speed": speed})
	return self

func on_end_sfx(key: StringName, db: float = 0.0) -> BulletLifecycle:
	_on_end.append({&"kind": A_SFX, &"key": key, &"db": db})
	return self

func on_end_despawn() -> BulletLifecycle:
	_on_end.append({&"kind": A_DESPAWN})
	return self

func on_end_set_vel(dir: Vector2, speed: float) -> BulletLifecycle:
	_on_end.append({&"kind": A_SET_VEL, &"dir": dir, &"speed": speed})
	return self


# ═══ Canned preset（现有 10 行为 → 预置生命周期）═══

## 非符1 反弹弹：沿飞行方向加速 → 碰左/右/上框 → 朝 Boss 转 bounce_angle 换弹 → 回收。
static func bounce(accel: float, bounce_angle: float, spawn_speed: float, factory: Callable,
		sfx_key: StringName = &"kira", sfx_db: float = -8.0) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_along_vel(accel)
	lc.until_wall(WALL_LEFT | WALL_RIGHT | WALL_TOP)
	if sfx_key != &"":
		lc.on_end_sfx(sfx_key, sfx_db)
	lc.on_end_emit(factory, true, bounce_angle, spawn_speed)
	lc.on_end_despawn()
	return lc


## 弯曲弹：转满 limit 弧度后直线。
static func curve(w: float, limit: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.rotate(w, limit)
	lc.until_turned(limit)
	lc.then()
	return lc


## 世界方向匀加速（承接旧 BulletData.accel / gravity_bullet）。
static func world_accel(v: Vector2) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_world(v)
	return lc


## 沿飞行方向匀加速。
static func accel(a: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_along_vel(a)
	return lc
