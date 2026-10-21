## 方向表达式：只描述“方向从哪来”，由 [BulletLifecycle] 编译成内核整数编码。
##
## [b]模型[/b][br]
## 每种 kind 在构造时确定求值依赖 [member eval_phase]：
## [codeblock]
## WORLD    heading / world_heading   绝对世界角
## TARGET   toward / away / chance    目标位置
## EMITTER  forward / random          发射者当前朝向
## WALL     reflect                   发射点所在场边
## [/codeblock]
## 原生只收到 kind / target / angle / p 的整数编码；[member eval_phase] 留在宿主侧，用于校验与报错。
## [br]
## [b]用法[/b][br]
## [codeblock]
## lc.set_heading(BulletLifecycle.toward(BulletLifecycle.T_PLAYER))
## lc.emit(spawn, BulletLifecycle.world_heading(PI), 120.0, BulletLifecycle.AT_PHASE_END)
## [/codeblock]
## 内容一般经 [BulletLifecycle] 的同名静态方法构造，不直接 new 本类。
## [br]
## [b]边界[/b][br]
## - [method heading] 只用于 [method BulletLifecycle.set_heading]；发射或结束时改朝向必须用 [method world_heading]，
##   否则 [method BulletLifecycle.emit] / [method BulletLifecycle.on_end_heading] 报错。[br]
## - toward / away 目标不可用时退化为向下；[method chance_toward] 命中时忽略 [member angle]。[br]
## - [method random_dir] / [method chance_toward] 每次求值消耗一次内核 RNG，消耗顺序即语义。[br]
## 完整参考：[code]docs/DANMAKU_API.md[/code] §3。
class_name DirSpec
extends RefCounted

## 求值依赖：决定该方向表达式需要读取哪些外部量。
enum EvalPhase {
	## 绝对世界角；不读目标、发射者朝向或场边。
	WORLD,
	## 需要目标位置（toward / away / chance）。
	TARGET,
	## 需要发射者当前朝向（forward / random）。
	EMITTER,
	## 需要发射点所在场边（reflect）。
	WALL,
}

## 方向 kind：绝对世界角（0 = 上，顺时针为正）。
const HEADING := &"heading"
## 方向 kind：朝目标位置。
const TOWARD := &"toward"
## 方向 kind：背向目标位置。
const AWAY := &"away"
## 方向 kind：沿发射者当前朝向。
const FORWARD := &"forward"
## 方向 kind：以发射者当前朝向为中心、±spread 均匀随机。
const RANDOM := &"random"
## 方向 kind：按概率朝目标，未命中时沿当前朝向转 spread。
const CHANCE := &"chance"
## 方向 kind：把当前速度按发射点所在场边翻分量，再转 angle。
const REFLECT := &"reflect"

## 方向 kind；取本类 HEADING / TOWARD / AWAY / FORWARD / RANDOM / CHANCE / REFLECT 之一。
var kind: StringName = HEADING
## 目标 key，仅 TOWARD / AWAY / CHANCE 使用；可取 BulletLifecycle.T_PLAYER / T_BOSS / T_NEAREST_ENEMY。
var target: StringName = &""
## 角度（弧度），含义随 kind 变：HEADING = 绝对世界角；TOWARD / AWAY / FORWARD / REFLECT = 额外偏移；
## RANDOM = 单侧张角；CHANCE = 未命中时的偏移。
var angle: float = 0.0
## CHANCE 命中目标的概率（0..1）；其余 kind 不用。
var chance_p: float = 0.0
## 求值依赖；构造时由 kind 决定，只用于宿主侧校验/报错，不发给原生。
var eval_phase: int = EvalPhase.WORLD
## 是否允许作为 emit / on_end_heading 的方向：world_heading() 与旧字典入口为 true；裸 heading 用来拦截误用。
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


## 绝对世界角：以向上为 0、顺时针为正（弧度）。
## 只用于 set_heading；emit / on_end_heading 请用 world_heading()。
static func heading(p_angle: float) -> RefCounted:
	return _make(HEADING, &"", p_angle, 0.0, EvalPhase.WORLD, false)


## 显式世界角：允许进入 emit / on_end_heading；与 heading 同为绝对角，只差 allow_world 许可。
static func world_heading(p_angle: float) -> RefCounted:
	return _make(HEADING, &"", p_angle, 0.0, EvalPhase.WORLD, true)


## 朝目标：方向 = 目标位置 − 发射点，再转角度参数；目标不可用时退化为向下。
static func toward(p_target: StringName, p_angle: float = 0.0) -> RefCounted:
	return _make(TOWARD, p_target, p_angle, 0.0, EvalPhase.TARGET)


## 背向目标：方向 = 发射点 − 目标位置，再转角度参数；目标不可用时退化为向下。
static func away(p_target: StringName, p_angle: float = 0.0) -> RefCounted:
	return _make(AWAY, p_target, p_angle, 0.0, EvalPhase.TARGET)


## 沿发射者当前朝向，再转角度参数。
static func forward(p_angle: float = 0.0) -> RefCounted:
	return _make(FORWARD, &"", p_angle, 0.0, EvalPhase.EMITTER)


## 以发射者当前朝向为中心、±spread 均匀随机；spread 是单侧张角（总张角 = 2×spread）。
## 每次求值消耗一次内核 RNG。
static func random_dir(p_spread: float) -> RefCounted:
	return _make(RANDOM, &"", p_spread, 0.0, EvalPhase.EMITTER)


## 以 p 概率精确朝目标（此时忽略 spread），否则沿当前朝向转 spread。
## 只作 emit_variant 的 dir；每次求值消耗一次内核 RNG。
static func chance_toward(p_target: StringName, p_chance: float, p_spread: float = 0.0) -> RefCounted:
	return _make(CHANCE, p_target, p_spread, p_chance, EvalPhase.TARGET)


## 把当前速度按发射点所在场边翻分量，再转角度参数；未贴边时退化为当前朝向。
## 配 until_at_wall + AT_PHASE_END 使用。
static func reflect(p_angle: float = 0.0) -> RefCounted:
	return _make(REFLECT, &"", p_angle, 0.0, EvalPhase.WALL)


## 归一化方向输入：DirSpec 实例原样返回；旧 Dictionary 读 kind / target / angle（或 spread）/ p，
## 并默认允许世界角；其它类型回落到 heading(0)。未知 kind 不在这里改写，交给编译期报错。
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


## 转成旧式 Dictionary（kind / target / angle / p）；只用于兼容与调试，会丢 eval_phase / allow_world。
static func to_dict(spec) -> Dictionary:
	return {&"kind": spec.kind, &"target": spec.target, &"angle": spec.angle, &"p": spec.chance_p}


static func _phase_of(k: StringName) -> int:
	match k:
		TOWARD, AWAY, CHANCE: return EvalPhase.TARGET
		FORWARD, RANDOM: return EvalPhase.EMITTER
		REFLECT: return EvalPhase.WALL
		_: return EvalPhase.WORLD
