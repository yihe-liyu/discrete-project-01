## 玩家输入的唯一读取口：每个物理 tick 开头锁存一次，玩法只读这份快照。
##
## [b]为什么需要锁存[/b][br]
## 同一物理 tick 里不同节点的 [code]process_physics_priority[/code] 不同
## （射击协程、内核、宿主碰撞……）。直接读 [code]Input[/code] 时，各节点可能
## 读到不同时刻的按键状态；回放/录制也会因此出现一帧差。
## [br]
## [b]边界[/b][br]
## - 只覆盖玩法动作（见 [constant ACTIONS]）；菜单仍走真实 [code]Input[/code]。[br]
## - 没有锁存时（菜单 / 测试 / 工具）回退到 [code]Input[/code]，行为不变。[br]
## - 离开 GameScene 时调用 [method clear_latch]，避免菜单读到上一局按键。
class_name PlayerInput
extends RefCounted

## 玩法动作顺序（位掩码按此索引 —— 录制格式兼容性，勿改顺序）。
const ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"shoot", "focus", "memory_release",
]

## 是否有本 tick 的输入快照。
static var _has_latch: bool = false
## 本 tick 锁存的按键位掩码（顺序同 [constant ACTIONS]）。
static var _latch_mask: int = 0
## 测试 / 回放注入：启用后 [method latch] 不再读真实 Input。
static var _override_active: bool = false
static var _override_mask: int = 0


## 在每个玩法物理 tick 开头调用：把输入锁成一份快照。
## 启用了 override（测试 / 回放）时锁注入值，不读真实 Input。
static func latch() -> void:
	_latch_mask = _override_mask if _override_active else _read_raw_mask()
	_has_latch = true


## 测试 / 回放：注入本 tick 的输入位掩码；之后每个 latch 都用它，直到 clear_override。
static func set_override_mask(mask: int) -> void:
	_override_active = true
	_override_mask = mask


## 关闭注入，恢复读真实 Input。
static func clear_override() -> void:
	_override_active = false
	_override_mask = 0
	_has_latch = false
	_latch_mask = 0


## 离开 GameScene / 测试清理：下一帧恢复直接读 Input。
static func clear_latch() -> void:
	_has_latch = false
	_latch_mask = 0


## 当前是否有锁存快照（诊断用）。
static func has_latch() -> bool:
	return _has_latch


## 本 tick 的玩法输入位掩码；无锁存时现读 Input（测试 / 菜单路径）。
static func input_mask() -> int:
	if _override_active:
		return _override_mask
	if _has_latch:
		return _latch_mask
	return _read_raw_mask()


## 本 tick 某动作是否按下；未知动作回退到真实 Input。
static func is_action_pressed(action: StringName) -> bool:
	var idx := ACTIONS.find(String(action))
	if idx < 0:
		return Input.is_action_pressed(action)
	if _override_active:
		return (_override_mask & (1 << idx)) != 0
	if not _has_latch:
		return Input.is_action_pressed(action)
	return (_latch_mask & (1 << idx)) != 0


## 本 tick 的 [-1, 1] 轴；无锁存时回退到 Input.get_axis。
static func get_axis(negative: StringName, positive: StringName) -> float:
	if not _has_latch and not _override_active:
		return Input.get_axis(negative, positive)
	var neg := 1.0 if is_action_pressed(negative) else 0.0
	var pos := 1.0 if is_action_pressed(positive) else 0.0
	return pos - neg


static func _read_raw_mask() -> int:
	var mask := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			mask |= 1 << i
	return mask
