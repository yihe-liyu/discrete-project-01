## DifficultyService —— ctx.diff（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 难度服务 —— ctx.diff 下的"现在什么难度 / 按难度取值"动词。
## 内容只问"当前难度/按难度差分"，内部才读 SaveData.selected_difficulty（机制）。
## 注意：不叫 get() —— 会遮蔽 Object.get(property)，故用 pick()/pick_from()。

## 当前难度索引（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）
func picked() -> int:
	return SaveData.selected_difficulty

## 按难度从数组取对应值；边界 / Extra 越界由 [Difficulty.pick] 守卫。
func pick(arr: Array) -> Variant:
	return Difficulty.pick(arr, picked(), "ctx.diff.pick")

## 按难度从嵌套字典取对应值；缺行 / 非法行走默认值并响亮报错。
func pick_from(dict: Dictionary, key: String, default = null):
	var difficulty := picked()
	if not Difficulty.is_valid(difficulty):
		push_error("ctx.diff.pick_from: 非法难度 %d（应为 0..%d）" % [difficulty, Difficulty.COUNT - 1])
		difficulty = Difficulty.NORMAL
	var row = dict.get(difficulty)
	if row == null:
		return default
	if not row is Dictionary:
		push_error("ctx.diff.pick_from: 难度 %s 对应的不是 Dictionary" % Difficulty.display_name(difficulty))
		return default
	return row.get(key, default)

## 当前难度 ≥ n（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）
func at_least(n: int) -> bool:
	return SaveData.selected_difficulty >= n
