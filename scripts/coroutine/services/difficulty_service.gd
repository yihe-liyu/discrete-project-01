## DifficultyService —— ctx.diff（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 难度服务 —— ctx.diff 下的"现在什么难度 / 按难度取值"动词。
## 内容只问"当前难度/按难度差分"，内部才读 GameState.selected_difficulty（机制）。
## 注意：不叫 get() —— 会遮蔽 Object.get(property)，故用 pick()/pick_from()。

## 当前难度索引（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）
func picked() -> int:
	return GameState.selected_difficulty

## 按难度从数组取对应值（arr[difficulty]）
func pick(arr: Array) -> Variant:
	return arr[GameState.selected_difficulty]

## 按难度从嵌套字典取对应值（diff_get 的落地）
func pick_from(dict: Dictionary, key: String, default = null):
	return dict.get(GameState.selected_difficulty, {}).get(key, default)

## 当前难度 ≥ n（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）
func at_least(n: int) -> bool:
	return GameState.selected_difficulty >= n
