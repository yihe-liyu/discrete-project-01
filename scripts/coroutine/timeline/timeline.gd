class_name Timeline
extends RefCounted
## 时间线 —— 纯排程器：只回答"何时触发"，不认识任何游戏机制。
## 动作一律 do(callable)，环境由内容在闭包里自带（ctx / 导演）；
## 唯一保留的类型耦合是 start_phase —— 相对时间 wait() 必须锚定一个阻塞事件。
##
##   var timeline := Timeline.new()
##   timeline.at(0.0).do(func(): _dir.bgm("stage1"))
##   timeline.at(2.0).every(1.5).times(4).do(_wave)
##   timeline.at(10.0).do(func(): ctx.bullets.shoot_spread(...))
##   timeline.loop()
##
##   func _on_step(_ctx): return timeline.tick(get_dt())

var _events: Array[TimelineEvent] = []
var _elapsed: float = 0.0
var _loop_start: float = -1.0
var _cursor: float = 0.0   # wait() 的参考点，phase_cleared 后更新

# builder state
var _time: float = -1.0
var _every: float = -1.0
var _times: int = -1
var _wait_n: float = -1.0


# ═══ 构建器 ═══

func at(t: float) -> Timeline:
	_time = t
	_every = -1.0
	_times = -1
	_wait_n = -1.0
	return self

func every(interval: float) -> Timeline:
	_every = interval
	return self

func times(n: int) -> Timeline:
	_times = n
	return self

func do(cb: Callable) -> Timeline:
	_add(_time, cb, _every, _times)
	return self


## 等上一个 blocking 事件结束后 N 秒执行（运行时计算）
func wait(n: float) -> Timeline:
	_time = -1.0  # 标记为相对事件，tick 时用 _cursor + n
	_every = -1.0
	_times = -1
	_wait_n = n
	return self


## 启动 Boss 阶段（战斗不冻结时间轴：绝对时间事件照常推进，仅 wait() 等待阶段击破）
## 注意：与 BossData.phase()（静态声明 Boss 有哪些阶段）区分——这里是运行驱动"此刻进入该阶段"
func start_phase(boss_getter: Callable, data: PhaseData) -> Timeline:
	return do(func():
		var boss := boss_getter.call() as Boss
		boss.start_phase(data)
		# 旧行为：_is_paused = true 冻结整个时间轴直到击破（Boss 战期间后续 tl 事件全部失效）
		# 现改为：仅 wait 事件等待 phase_cleared 激活，绝对时间事件（at/t）战斗期间照常触发
		boss.phase_cleared.connect(func(_captured: bool, _bonus: int):
			_cursor = _elapsed
			# 激活全部未触发的 wait 事件（多个 wait 各自按 _cursor + offset 触发，
			# 支持 Boss 击破后编排多段相对波次/演出）
			for ev in _events:
				if ev.wait_offset >= 0 and not ev.is_wait_armed and not ev.is_fired:
					ev.is_wait_armed = true
		, CONNECT_ONE_SHOT)
	)


# ═══ 内部 ═══

func _add(t: float, cb: Callable, ev: float = -1.0, n: int = -1) -> void:
	var event := TimelineEvent.new(t, cb, ev, n)
	event.wait_offset = _wait_n
	_wait_n = -1.0
	_events.append(event)


# ═══ 运行 ═══

func tick(delta: float) -> bool:
	_elapsed += delta

	for ev in _events:
		if ev.is_fired and ev.repeat_every < 0:
			continue
		var event_time := ev.time
		if ev.wait_offset >= 0:
			if not ev.is_wait_armed:
				continue  # 还没被 phase 激活
			event_time = _cursor + ev.wait_offset
		if _elapsed >= event_time:
			ev.execute()
			if ev.repeat_every >= 0:
				ev.time += ev.repeat_every
				ev.fired_count += 1
				if ev.repeat_times > 0 and ev.fired_count >= ev.repeat_times:
					ev.is_fired = true
					ev.repeat_every = -1.0
			else:
				ev.is_fired = true

	if _loop_start >= 0 and _elapsed >= _loop_start and _all_onetime_fired():
		_reset_onetime()
		_elapsed = _loop_start

	if _loop_start >= 0:
		return true
	for ev in _events:
		if not ev.is_fired:
			return true
	return false


func _all_onetime_fired() -> bool:
	for ev in _events:
		if not ev.is_fired:
			return false
	return true

func _reset_onetime() -> void:
	for ev in _events:
		ev.is_fired = false
		# 用 _loop_start 而非当前 _elapsed：大 delta 跨过循环点时不会把下一轮事件时间戳推远
		ev.time = _loop_start + ev._original_time
		ev.fired_count = 0
		ev.repeat_every = ev._original_repeat_every
		ev.repeat_times = ev._original_repeat_times


func reset() -> void:
	_elapsed = 0.0
	for ev in _events:
		ev.is_fired = false

func loop() -> void:
	if _events.is_empty(): return
	_loop_start = _compute_loop_start()


## 计算循环终点：取所有事件"最后一次触发"的最大时刻。
## 重复事件按 repeat_every × (times-1) 计算，避免 loop_start 落在首次触发时刻导致循环周期错误。
func _compute_loop_start() -> float:
	var end_time := -INF
	for ev in _events:
		var last := ev._original_time
		if ev._original_repeat_every > 0.0 and ev._original_repeat_times > 0:
			last = ev._original_time + ev._original_repeat_every * float(ev._original_repeat_times - 1)
		end_time = maxf(end_time, last)
	return end_time
