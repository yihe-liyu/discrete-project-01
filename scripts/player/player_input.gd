## 玩家输入的唯一读取口：正常游戏读 Input，回放时读 ReplaySession 的输入掩码。
##
## 只覆盖玩法动作（move_* / shoot / focus）；菜单仍走真实 Input。
class_name PlayerInput
extends RefCounted

static func is_action_pressed(action: StringName) -> bool:
	if ReplaySession.is_playing():
		return ReplaySession.action_pressed(action)
	return Input.is_action_pressed(action)


static func get_axis(negative: StringName, positive: StringName) -> float:
	if ReplaySession.is_playing():
		return ReplaySession.axis(negative, positive)
	return Input.get_axis(negative, positive)
