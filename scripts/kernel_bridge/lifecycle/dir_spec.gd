class_name DirSpec
extends RefCounted
## 方向表达式（DSL1）：不再是裸 Dictionary，构造时确定 **eval_phase**。
##
## eval_phase 说明“求值依赖什么”：
##   WORLD   = 世界角，常量；不读发射者朝向 / 速度 / 位置
##   TARGET  = 需要目标位置（toward / away / chance）
##   EMITTER = 需要发射者自身朝向（forward / random）
##   WALL    = 需要发射点场边（reflect）
##
## 原生只收到 kind/target/angle/p 的整数编码（零改动）；eval_phase 是宿主侧类型/校验信息。

enum EvalPhase { WORLD, TARGET, EMITTER, WALL }

const HEADING := &"heading"
const TOWARD := &"toward"
const AWAY := &"away"
const FORWARD := &"forward"
const RANDOM := &"random"
const CHANCE := &"chance"
const REFLECT := &"reflect"

var kind: StringName = HEADING
var target: StringName = &""
var angle: float = 0.0
var chance_p: float = 0.0
var eval_phase: int = EvalPhase.WORLD
## 兼容：显式 world_heading 才允许进入 emit / on_end_heading；裸 heading 不允许。
var allow_world: bool = false

const _SELF_PATH := "res://scripts/kernel_bridge/lifecycle/dir_spec.gd"
static var _self_script: Script


static func _script() -> Script:
	if _self_script == null:
		_self_script = load(_SELF_PATH) as Script
	return _self_script


static func _make(p_kind: StringName, p_target: StringName, p_angle: float,
		p_p: float, p_phase: int, p_allow_world: bool = false) -> RefCounted:
	return _script().new(p_kind, p_target, p_angle, p_p, p_phase, p_allow_world)


func _init(p_kind: StringName = HEADING, p_target: StringName = &"", p_angle: float = 0.0,
		p_p: float = 0.0, p_phase: int = EvalPhase.WORLD, p_allow_world: bool = false) -> void:
	kind = p_kind
	target = p_target
	angle = p_angle
	chance_p = p_p
	eval_phase = p_phase
	allow_world = p_allow_world


static func heading(p_angle: float) -> RefCounted:
	return _make(HEADING, &"", p_angle, 0.0, EvalPhase.WORLD, false)


## 显式世界角：用于 emit / on_end_heading（不随发射者变的固定方向）。
static func world_heading(p_angle: float) -> RefCounted:
	return _make(HEADING, &"", p_angle, 0.0, EvalPhase.WORLD, true)


static func toward(p_target: StringName, p_angle: float = 0.0) -> RefCounted:
	return _make(TOWARD, p_target, p_angle, 0.0, EvalPhase.TARGET)


static func away(p_target: StringName, p_angle: float = 0.0) -> RefCounted:
	return _make(AWAY, p_target, p_angle, 0.0, EvalPhase.TARGET)


static func forward(p_angle: float = 0.0) -> RefCounted:
	return _make(FORWARD, &"", p_angle, 0.0, EvalPhase.EMITTER)


static func random_dir(p_spread: float) -> RefCounted:
	return _make(RANDOM, &"", p_spread, 0.0, EvalPhase.EMITTER)


static func chance_toward(p_target: StringName, p_chance: float, p_spread: float = 0.0) -> RefCounted:
	return _make(CHANCE, p_target, p_spread, p_chance, EvalPhase.TARGET)


static func reflect(p_angle: float = 0.0) -> RefCounted:
	return _make(REFLECT, &"", p_angle, 0.0, EvalPhase.WALL)


## 兼容旧工作台/旧测试里的 Dictionary；旧字典默认允许世界角（工作台会再生成 world_heading 代码）。
static func from_variant(v: Variant) -> RefCounted:
	if v is RefCounted and v.get_script() == _script():
		return v
	if v is Dictionary:
		var kind_v: StringName = StringName(v.get(&"kind", HEADING))
		var angle_v := float(v.get(&"angle", v.get(&"spread", 0.0)))
		var spec := _make(kind_v, StringName(v.get(&"target", &"")),
			angle_v, float(v.get(&"p", 0.0)), _phase_of(kind_v), true)
		spec.eval_phase = _phase_of(kind_v)
		spec.allow_world = true
		return spec
	return heading(0.0)


static func to_dict(spec) -> Dictionary:
	return {&"kind": spec.kind, &"target": spec.target, &"angle": spec.angle, &"p": spec.chance_p}


static func _phase_of(k: StringName) -> int:
	match k:
		TOWARD, AWAY, CHANCE: return EvalPhase.TARGET
		FORWARD, RANDOM: return EvalPhase.EMITTER
		REFLECT: return EvalPhase.WALL
		_: return EvalPhase.WORLD
