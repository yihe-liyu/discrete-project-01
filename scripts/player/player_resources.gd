## 单局资源状态：火力 / 分数 / 擦弹 / 残机 / 雷 / 碎片 / 记忆。
## 从 SaveData 抽出——单一 owner，所有资源只经显式入口修改（R18）。
## RefCounted：单局内存状态，不进存档。
class_name PlayerResources
extends RefCounted

signal changed()

## 记忆值每秒自然恢复量
const MEMORY_REGEN: float = 0.05
const MEMORY_GRAZE: float = 0.25
const MEMORY_HIT_BY_BULLET: float = -0.01
const MEMORY_MISS: float = 25.0

var current_score: int = 0
var graze_count: int = 0
var max_point: int = 10000
var memory_value: float = 50.0

## 火力值内部表示：0 = 1.00, 300 = 4.00，每 1 单位 = 0.01
var power_raw: int = 0

## 残机 / 雷（0~8）+ 碎片（0~4）
var lives: int = 2
var life_fragments: int = 0
var bomb_count: int = 3
var bomb_fragments: int = 0


func get_power_display() -> String:
	return "%.2f" % get_power_float()


func get_power_float() -> float:
	return 1.00 + power_raw * 0.01


func add_power(amount: int) -> void:
	power_raw = clampi(power_raw + amount, 0, 300)
	changed.emit()


func on_miss_power_penalty() -> void:
	power_raw = clampi(power_raw - 50, 0, 300)
	changed.emit()


## 捡点：max_point 恒 +10；分数默认入账当前 max_point，可传 score 覆盖（深位捡点递减）。
## 返回**实际入账**的分数（弹浮字用）。
func add_max_point(score: int = -1) -> int:
	var pts := max_point
	max_point += 10
	var credited := pts if score < 0 else score
	current_score += credited
	changed.emit()
	return credited


func add_score(amount: int) -> void:
	current_score += amount
	changed.emit()


func add_memory(amount: float) -> void:
	memory_value = clampf(memory_value + amount, 0.0, 100.0)


func reduce_memory(amount: float) -> void:
	memory_value = clampf(memory_value - amount, 0.0, 100.0)


## 捡到残机碎片：集满 5 个合成一个完整残机
func collect_life_fragment() -> void:
	life_fragments += 1
	if life_fragments >= 5:
		life_fragments = 0
		_add_life()
	changed.emit()


func _add_life() -> void:
	if lives < 8:
		lives += 1


## 被弹扣除残机，返回本次是否存活（减之前有命即可）
func lose_life() -> bool:
	var had_life := lives > 0
	if had_life:
		lives -= 1
		changed.emit()
	return had_life


func collect_life_full() -> void:
	for _i in range(5):
		collect_life_fragment()


## 捡到 Bomb 碎片：集满 5 个合成一个完整 Bomb
func collect_bomb_fragment() -> void:
	bomb_fragments += 1
	if bomb_fragments >= 5:
		bomb_fragments = 0
		_add_bomb()
	changed.emit()


func _add_bomb() -> void:
	if bomb_count < 8:
		bomb_count += 1


func collect_bomb_full() -> void:
	for _i in range(5):
		collect_bomb_fragment()


## 使用一个 Bomb：有存货返回 true 并扣除，否则 false
func use_bomb() -> bool:
	if bomb_count <= 0:
		return false
	bomb_count -= 1
	changed.emit()
	return true


## 每帧记忆自然恢复（不发信号：UI 不需要每帧刷）
func regen(delta: float) -> void:
	memory_value = clampf(memory_value + MEMORY_REGEN * delta, 0.0, 100.0)


func reset_all() -> void:
	current_score = 0
	max_point = 10000
	graze_count = 0
	power_raw = 0
	lives = 2
	life_fragments = 0
	bomb_count = 3
	bomb_fragments = 0
	memory_value = 50.0
	changed.emit()


func reset_practice() -> void:
	current_score = 0
	max_point = 10000
	graze_count = 0
	power_raw = 300
	lives = 0
	life_fragments = 0
	bomb_count = 0
	bomb_fragments = 0
	memory_value = 50.0
	changed.emit()
