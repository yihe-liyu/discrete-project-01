## 难度维度：0=Easy / 1=Normal / 2=Hard / 3=Lunatic / 4=Extra。
##
## 内容里的 [code]diff_pick([...])[/code] 按它取值；数组下标、显示名、边界检查都走这里，
## 不再在各脚本里散写 0..4 或 [code]SaveData.selected_difficulty[/code] 的裸下标。
## [br]
## Extra 是第 5 个难度：普通面常用的 4 项数组在 Extra 下会越界，[method pick] 会响亮报错并回落最后一项。
class_name Difficulty
extends RefCounted

const EASY := 0
const NORMAL := 1
const HARD := 2
const LUNATIC := 3
const EXTRA := 4
const COUNT := 5


## 难度是否在 0..4。
static func is_valid(value: int) -> bool:
	return value >= 0 and value < COUNT


## 展示名；非法值返回 [code]?[/code]。
static func display_name(value: int) -> String:
	return SpellRecord.DIFF_NAMES[value] if is_valid(value) else "?"


## 按难度取数组项；空数组 / 越界 / 非法难度都 push_error，并返回安全回落值。
## 普通 4 项数组只覆盖 Easy~Lunatic；EX 内容需要 5 项（或在 Extra 下走别的分支）。
static func pick(values: Array, difficulty: int, context: String = "diff_pick") -> Variant:
	ParamTrace.record(values, difficulty, context)
	if values.is_empty():
		push_error("%s: 难度数组为空" % context)
		return null
	var index := difficulty
	if not is_valid(index):
		push_error("%s: 非法难度 %d（应为 0..%d）" % [context, index, COUNT - 1])
		index = NORMAL
	if index >= values.size():
		push_error("%s: 难度 %s 需要第 %d 项，但数组只有 %d 项" % [
			context, display_name(index), index + 1, values.size()])
		return values[values.size() - 1]
	return values[index]
