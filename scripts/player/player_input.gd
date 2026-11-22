## 玩家输入的唯一读取口：正常游戏读本帧锁存，回放时读 ReplaySession 的输入掩码。
##
## [b]为什么不再直接读 Input[/b][br]
## 物理帧里各节点有不同 [code]process_physics_priority[/code]（MarisaShoot -100、
## 内核 -10/-4……）。直接读 [code]Input[/code] 时，同一个物理 tick 里不同节点
## 可能读到不同时刻的按键状态，回放就会因为节点顺序出现一帧差。
## GameScene 在每个物理 tick 开头调用 [method latch]，本 tick 内所有玩法读取
## 都看同一份快照。[br]
##
## [b]边界[/b][br]
## - 只覆盖玩法动作（见 [constant ACTIONS]）；菜单仍走真实 [code]Input[/code]。[br]
## - 回放时仍以 ReplaySession 当前帧掩码为准，锁存不参与。[br]
## - 离开 GameScene 时调用 [method clear_latch]，避免菜单读到上一局按键。[br]
class_name PlayerInput
extends RefCounted

## 玩法动作顺序（与 ReplayRecorder.ACTIONS 一致，位掩码格式兼容）。
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "shoot", "focus", "memory_release"]

## 是否有本 tick 的输入快照。
static var _has_latch: bool = false
## 本 tick 锁存的按键位掩码（顺序同 [constant ACTIONS]）。
static var _latch_mask: int = 0


## 在每个玩法物理 tick 开头调用：把真实 Input 锁成一份快照。
static func latch() -> void:
	_latch_mask = _read_raw_mask()
	_has_latch = true


## 离开 GameScene / 测试清理：下一帧恢复直接读 Input。
static func clear_latch() -> void:
	_has_latch = false
	_latch_mask = 0


## 当前是否有锁存快照（诊断用）。
static func has_latch() -> bool:
	return _has_latch


## 本 tick 的玩法输入位掩码；无锁存时现读 Input（测试 / 菜单路径）。
static func input_mask() -> int:
	if _has_latch:
		return _latch_mask
	return _read_raw_mask()


static func is_action_pressed(action: StringName) -> bool:
	if ReplaySession.is_playing():
		return ReplaySession.action_pressed(action)
	var idx := ACTIONS.find(action)
	if idx >= 0:
		return (_latch_mask & (1 << idx)) != 0 if _has_latch \
			else Input.is_action_pressed(action)
	return Input.is_action_pressed(action)


static func get_axis(negative: StringName, positive: StringName) -> float:
	if ReplaySession.is_playing():
		return ReplaySession.axis(negative, positive)
	if not _has_latch:
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
