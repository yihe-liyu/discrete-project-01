## 固定 tick 调度器：只决定“这一帧跑几个 1/60 tick”，不改变每个 tick 的 DT。
##
## [b]边界[/b][br]
## - 每个 tick 始终是 [constant SimClock.DT]；speed 只改变每真实秒消费多少 tick。[br]
## - 不替代 [SimClock]：本类只返回步数；step 由调用方（headless driver / 回放）执行。[br]
## - 设 [member max_steps_per_advance] 防止一帧欠账太多导致螺旋。
class_name TimeScheduler
extends RefCounted

## 每真实秒最多补多少 tick（防 spiral of death）。
var max_steps_per_advance: int = 8
## 时间流速倍率；1 = 正常，0.5 = 慢放，2 = 快进。
var speed: float = 1.0

var _accumulator: float = 0.0


func _init(p_speed: float = 1.0) -> void:
	set_speed(p_speed)


## 设置倍率；0 表示暂停，负数按 0 处理。
func set_speed(p_speed: float) -> void:
	speed = maxf(0.0, p_speed)


## 消费一段真实时间，返回本帧应执行的 tick 数。
func advance(real_delta: float) -> int:
	if real_delta <= 0.0 or speed <= 0.0:
		return 0
	_accumulator += real_delta * speed
	var steps := 0
	while _accumulator >= SimClock.DT and steps < max_steps_per_advance:
		_accumulator -= SimClock.DT
		steps += 1
	# 超出单帧预算的欠账丢弃：宁可慢，不要一帧补到卡死。
	if steps >= max_steps_per_advance and _accumulator >= SimClock.DT:
		_accumulator = fmod(_accumulator, SimClock.DT)
	return steps


## 两 tick 之间的插值 alpha（0..1），供表现层插值。
func alpha() -> float:
	return clampf(_accumulator / SimClock.DT, 0.0, 1.0)


func reset() -> void:
	_accumulator = 0.0
