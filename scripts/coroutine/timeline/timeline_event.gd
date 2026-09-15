class_name TimelineEvent
extends RefCounted

var time: float
var callback: Callable
var is_fired: bool = false
var repeat_every: float = -1.0
var repeat_times: int = -1
var fired_count: int = 0
var _original_time: float = 0.0
var _original_repeat_every: float = -1.0
var _original_repeat_times: int = -1
var wait_offset: float = -1.0  # >=0 = 相对事件，运行时 time = cursor + offset
var is_wait_armed: bool = false   # phase 结束后设 true

func _init(p_time: float, p_cb: Callable, p_every: float = -1.0, p_times: int = -1) -> void:
	time = p_time
	_original_time = p_time
	callback = p_cb
	repeat_every = p_every
	repeat_times = p_times
	_original_repeat_every = p_every
	_original_repeat_times = p_times

func execute() -> void:
	callback.call()
