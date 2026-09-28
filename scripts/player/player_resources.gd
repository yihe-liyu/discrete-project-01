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

## 残机 / 雷的**槽位上限**（UI 也按这个数排格子；碎片合成、`add_bombs` 都受它约束）
const MAX_LIVES: int = 8
const MAX_BOMBS: int = 8

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


## 捡到残机碎片：集满 5 个合成一个完整残机。
## 返回**本次是否真的合出了一个完整残机** —— 调用方（`Item.collect`）据此播"拿到整命"的回报音；
## 已到上限（8 命）时碎片照旧被消耗，但**没有多命** ⇒ false（不播，别撒谎）。
func collect_life_fragment() -> bool:
	life_fragments += 1
	var got_full := false
	if life_fragments >= 5:
		life_fragments = 0
		got_full = _add_life()
	changed.emit()
	return got_full


## 加一条命。返回**是否真的加上**（`MAX_LIVES` 为上限，满了返回 false）
func _add_life() -> bool:
	if lives >= MAX_LIVES:
		return false
	lives += 1
	return true


## 被弹扣除残机，返回本次是否存活（减之前有命即可）
func lose_life() -> bool:
	var had_life := lives > 0
	if had_life:
		lives -= 1
		changed.emit()
	return had_life


## 直接吃到一个完整残机（整命道具，= 连收 5 片碎片）。
## 返回**是否真的多了一条命** —— 碎片先凑满的那一次就返回 true，已满命则 false。
func collect_life_full() -> bool:
	var got_full := false
	for _i in range(5):
		if collect_life_fragment():
			got_full = true
	return got_full


## 捡到 Bomb 碎片：集满 5 个合成一个完整 Bomb
func collect_bomb_fragment() -> void:
	bomb_fragments += 1
	if bomb_fragments >= 5:
		bomb_fragments = 0
		_add_bomb()
	changed.emit()


func _add_bomb() -> void:
	bomb_count = mini(bomb_count + 1, MAX_BOMBS)


## 直接加 `count` 个**完整雷**（不经过碎片）—— miss 的补偿走这里。
## 返回**实际加上几个**（到 `MAX_BOMBS` 就加不上）。**不动碎片**：碎片那条线（收满 5 片合成 1 个）照旧。
func add_bombs(count: int) -> int:
	var before := bomb_count
	bomb_count = clampi(bomb_count + maxi(count, 0), 0, MAX_BOMBS)
	changed.emit()
	return bomb_count - before


func collect_bomb_full() -> void:
	for _i in range(5):
		collect_bomb_fragment()


## 使用一个 Bomb：有存货返回 true 并扣除，否则 false
func use_bomb() -> bool:
	return use_bombs(1) == 1


## 一次用掉至多 `count` 个 Bomb（**不足则把手上的用完**），返回实际消耗数。
## 被弹炸弹（deathbomb）用它一次扣 2 —— 只剩 1 个时就只扣 1。
func use_bombs(count: int) -> int:
	var used := mini(maxi(count, 0), bomb_count)
	if used <= 0:
		return 0
	bomb_count -= used
	changed.emit()
	return used


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
