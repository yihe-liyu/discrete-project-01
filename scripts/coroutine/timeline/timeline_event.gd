## 时间线事件：时刻 / 回调 / 重复配置 / 相对 wait 状态；由 Timeline 驱动。
class_name TimelineEvent
extends RefCounted

## 绝对触发时刻（秒）。
var time: float
## 到点执行的回调。
var callback: Callable
## 是否已触发。
var is_fired: bool = false
## 重复间隔（< 0 = 不重复）。
var repeat_every: float = -1.0
## 重复次数（<= 0 = 无限）。
var repeat_times: int = -1
## 已触发次数。
var fired_count: int = 0
var _original_time: float = 0.0
var _original_repeat_every: float = -1.0
var _original_repeat_times: int = -1
## 相对 wait 偏移（>=0 = 相对事件）。
var wait_offset: float = -1.0  # >=0 = 相对事件，运行时 time = cursor + offset
## 阶段击破后是否已武装。
var is_wait_armed: bool = false   # phase 结束后设 true

func _init(p_time: float, p_cb: Callable, p_every: float = -1.0, p_times: int = -1) -> void:
	time = p_time
	_original_time = p_time
	callback = p_cb
	repeat_every = p_every
	repeat_times = p_times
	_original_repeat_every = p_every
	_original_repeat_times = p_times

## 执行回调（Timeline 到点时调）。
func execute() -> void:
	callback.call()
