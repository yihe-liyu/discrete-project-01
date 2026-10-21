## 单局资源状态：火力 / 分数 / 擦弹 / 残机 / 雷 / 碎片 / 记忆。
## 单一 owner：所有资源只经显式入口修改；RefCounted，不进存档。
##
## [b]模型[/b][br]
## 每局一份，由 StageRuntime / Player / HUD 共享。[signal changed] 供需要即时刷新的 UI 用；
## GameUI 当前逐帧轮询（包括记忆值）。
## [br]
## [b]边界[/b][br]
## - 记忆 0..100：>= 50 时擦弹有概率消弹、并可释放记忆（C）；< 50 有伤害加成。[br]
## - 残机 / 雷上限 8；碎片满 5 合 1，满上限时碎片仍被消耗。[br]
## - Miss 雷惩罚先扣 2 再抬到下限 3，低雷时可能净增。[br]
## - 记忆变化不发 changed（UI 轮询）。
class_name PlayerResources
extends RefCounted

## 资源变化广播（分数 / 残机 / 雷 / 火力 / 碎片；记忆变化与 regen 不发）。
signal changed()

## 记忆每秒自然恢复量。
const MEMORY_REGEN: float = 0.05
## 擦弹一次的记忆增量。
const MEMORY_GRAZE: float = 0.25
## 自机弹命中敌人一次的记忆增量（负值）。
const MEMORY_HIT_BY_BULLET: float = -0.01
## Miss 一次的记忆增量。
const MEMORY_MISS: float = 25.0

## 残机槽位上限（UI 也按这个数排格子；碎片合成受它约束）。
const MAX_LIVES: int = 8
## 雷槽位上限（UI 也按这个数排格子；碎片合成 / add_bombs 受它约束）。
const MAX_BOMBS: int = 8

## Miss 雷惩罚的扣除量。
const MISS_BOMB_PENALTY: int = 2
## Miss 雷惩罚的下限：先扣再抬到该值（本来低于 3 时中弹反而净增）。
const MISS_BOMB_FLOOR: int = 3

## 单局总分。
var current_score: int = 0
## 擦弹次数。
var graze_count: int = 0
## 最大得点：每捡一个点 +10；点道具的入账基准。
var max_point: int = 10000
## 记忆值 0..100：>= 50 擦弹有概率消弹、可释放记忆（C）；< 50 有伤害加成。
var memory_value: float = 50.0

## 火力值内部表示：0 = 1.00，300 = 4.00，每 1 单位 = 0.01。
const MAX_POWER_RAW: int = 300
## 火力原始值 0..300（显示 = 1.00 + raw × 0.01）。
var power_raw: int = 0

## 残机数（0..8）。
var lives: int = 2
## 命碎片（0..4；满 5 合 1 命）。
var life_fragments: int = 0
## 雷数（0..8）。
var bomb_count: int = 3
## 雷碎片（0..4；满 5 合 1 雷）。
var bomb_fragments: int = 0


## 火力显示字符串（两位小数，1.00..4.00）。
func get_power_display() -> String:
	return "%.2f" % get_power_float()


## 火力浮点值 = 1.00 + power_raw × 0.01。
func get_power_float() -> float:
	return 1.00 + power_raw * 0.01


## 火力直接拉满（关卡练习第 2 面起的起始约定；调试也方便）。
## 必须发 changed：HUD 靠它刷新；本方法常在 reset_all() 之后单独调。
func set_max_power() -> void:
	power_raw = MAX_POWER_RAW
	changed.emit()


## 增减火力，clamp 0..300；amount 可负。
func add_power(amount: int) -> void:
	power_raw = clampi(power_raw + amount, 0, MAX_POWER_RAW)
	changed.emit()


## Miss 扣 50 火力（clamp 0..300）。
func on_miss_power_penalty() -> void:
	power_raw = clampi(power_raw - 50, 0, MAX_POWER_RAW)
	changed.emit()


## Miss 的雷惩罚：先扣 MISS_BOMB_PENALTY，再抬到下限 MISS_BOMB_FLOOR。
## 所以雷本来少于 3 时中弹可能净增；雷碎片是另一条线，本方法不动它。
func on_miss_bomb_penalty() -> void:
	bomb_count = maxi(bomb_count - MISS_BOMB_PENALTY, MISS_BOMB_FLOOR)
	changed.emit()


## 捡点：max_point 恒 +10；分数默认入账“旧 max_point”，可传 score 覆盖（深位捡点递减）。
## 返回实际入账的分数（弹浮字用）。
func add_max_point(score: int = -1) -> int:
	var pts := max_point
	max_point += 10
	var credited := pts if score < 0 else score
	current_score += credited
	changed.emit()
	return credited


## 加总分（amount 可负）。
func add_score(amount: int) -> void:
	current_score += amount
	changed.emit()


## 加记忆，clamp 0..100；不发 changed（UI 轮询）。
func add_memory(amount: float) -> void:
	memory_value = clampf(memory_value + amount, 0.0, 100.0)


## 减记忆，clamp 0..100；不发 changed（UI 轮询）。
func reduce_memory(amount: float) -> void:
	memory_value = clampf(memory_value - amount, 0.0, 100.0)


## 捡到残机碎片：集满 5 个合成一个完整残机。
## 返回本次是否真的合出完整残机（Item.collect 据此播“拿到整命”的音）；
## 已到上限（8 命）时碎片照旧消耗，但没有多命 ⇒ false。
func collect_life_fragment() -> bool:
	life_fragments += 1
	var got_full := false
	if life_fragments >= 5:
		life_fragments = 0
		got_full = _add_life()
	changed.emit()
	return got_full


## 加一条命；返回是否真的加上（MAX_LIVES 为上限）。
func _add_life() -> bool:
	if lives >= MAX_LIVES:
		return false
	lives += 1
	return true


## 被弹扣除残机；返回扣前是否有命（有命才扣、才发信号）。
func lose_life() -> bool:
	var had_life := lives > 0
	if had_life:
		lives -= 1
		changed.emit()
	return had_life


## 直接吃到一个完整残机（整命道具，= 连收 5 片碎片）。
## 返回是否真的多了一条命（已满命则 false）。
func collect_life_full() -> bool:
	var got_full := false
	for _i in range(5):
		if collect_life_fragment():
			got_full = true
	return got_full


## 捡到雷碎片：集满 5 个合成一个完整雷；满雷时碎片仍被消耗。
func collect_bomb_fragment() -> void:
	bomb_fragments += 1
	if bomb_fragments >= 5:
		bomb_fragments = 0
		_add_bomb()
	changed.emit()


## 加一个雷，clamp 到 MAX_BOMBS。
func _add_bomb() -> void:
	bomb_count = mini(bomb_count + 1, MAX_BOMBS)


## 直接加 count 个完整雷（不经过碎片）；miss 的补偿走这里。
## 返回实际加上几个（到 MAX_BOMBS 就加不上）；不动碎片。
func add_bombs(count: int) -> int:
	var before := bomb_count
	bomb_count = clampi(bomb_count + maxi(count, 0), 0, MAX_BOMBS)
	changed.emit()
	return bomb_count - before


## 直接吃到一个完整雷（整雷道具，= 连收 5 片碎片）；满雷时碎片仍被消耗。
func collect_bomb_full() -> void:
	for _i in range(5):
		collect_bomb_fragment()


## 使用一个 Bomb：有存货返回 true 并扣除，否则 false。
func use_bomb() -> bool:
	return use_bombs(1) == 1


## 一次用掉至多 count 个 Bomb（不足则把手上的用完），返回实际消耗数。
## 被弹炸弹（deathbomb）一次扣 2 —— 只剩 1 个时就只扣 1；count <= 0 → 0。
func use_bombs(count: int) -> int:
	var used := mini(maxi(count, 0), bomb_count)
	if used <= 0:
		return 0
	bomb_count -= used
	changed.emit()
	return used


## 每帧记忆自然恢复（+MEMORY_REGEN × delta，clamp 0..100）；不发信号，UI 轮询。
func regen(delta: float) -> void:
	memory_value = clampf(memory_value + MEMORY_REGEN * delta, 0.0, 100.0)


## 单局重置：分数 0 / 最大得点 10000 / 擦弹 0 / 火力 1.00 / 2 命 / 3 雷 / 碎片 0 / 记忆 50。
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


## 符卡练习重置：分数 0 / 最大得点 10000 / 擦弹 0 / 火力 4.00 / 0 命 / 0 雷 / 碎片 0 / 记忆 50。
func reset_practice() -> void:
	current_score = 0
	max_point = 10000
	graze_count = 0
	power_raw = MAX_POWER_RAW
	lives = 0
	life_fragments = 0
	bomb_count = 0
	bomb_fragments = 0
	memory_value = 50.0
	changed.emit()
