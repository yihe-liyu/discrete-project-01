## 时间线排程器：只回答“何时触发”，不认识任何游戏机制。
##
## [b]模型[/b][br]
## [codeblock]
## at(2.0).do(cb)                      绝对时刻 2s
## at(0.0).every(1.5).times(4).do(cb)  0s 起，每 1.5s，共 4 次
## wait(3.0).do(cb)                    最近一次阶段击破后 3s
## [/codeblock]
## 动作一律 [method do]（[code]Callable[/code] 无参数）；ctx / 导演等环境由内容在闭包里捕获。
## 唯一保留的类型耦合是阶段：[method wait] 的相对时间必须锚定一次阶段击破。
## [br]
## [b]用法[/b][br]
## [codeblock]
## var tl := start_timeline()
## tl.at(10.0).do(func(): ctx.bullets.shoot_spread(...))
## tl.loop()
##
## func _on_step(_ctx):
##     return tl.tick(get_dt())
## [/codeblock]
## 通常由 [CoroutineScript] 的 [code]start_timeline()[/code] 创建并驱动；
## tick 的返回值供 [code]CoroutineScript.auto_stop[/code] 判断是否收尾。
## [br]
## [b]边界[/b][br]
## - 未配 [method loop] 时，所有一次性事件触发完 tick 就返回 false；无限重复事件不会返回 false。[br]
## - [method wait] 只认阶段击破；没有 [method start_phase] / [method sequence_phases] 就永远不触发。[br]
## - 阶段战不冻结时间线：绝对时间事件照常推进，wait 只等击破。[br]
## - [method loop] 遇到无限重复事件不会回到起点（永远有未完成事件）。[br]
## 完整参考：[code]docs/DANMAKU_API.md[/code] §5.4。
class_name Timeline
extends RefCounted

var _events: Array[TimelineEvent] = []
## 阶段序列（sequence_phases）：{getter, phases, gap, index, next_at}
var _sequences: Array[Dictionary] = []
var _elapsed: float = 0.0
var _loop_start: float = -1.0
var _cursor: float = 0.0   # wait() 的参考点，phase_cleared 后更新

# builder state
var _time: float = -1.0
var _every: float = -1.0
var _times: int = -1
var _wait_n: float = -1.0


# ═══ 构建器 ═══

## 设下一个 [method do] 的绝对时刻（秒），并清空 every / times / wait 状态。
func at(t: float) -> Timeline:
	_time = t
	_every = -1.0
	_times = -1
	_wait_n = -1.0
	return self

## 让下一个 [method do] 每 [code]interval[/code] 秒重复；不配 [method times] 就无限重复。
func every(interval: float) -> Timeline:
	_every = interval
	return self

## 限制下一个 [method do] 的重复次数；n <= 0 表示无限。
func times(n: int) -> Timeline:
	_times = n
	return self

## 把回调排到当前构建时刻；回调无参数，ctx / 导演等环境在闭包里捕获。
## 未先调用 [method at] / [method wait] 时时刻为 -1，首个 tick 立即触发。
func do(cb: Callable) -> Timeline:
	_add(_time, cb, _every, _times)
	return self


## 相对时刻：等最近一次 Boss 阶段击破（phase_cleared）后 n 秒触发。
## 在 [method start_phase] / [method sequence_phases] 武装前 tick 会跳过；没有阶段事件就永远不触发。
func wait(n: float) -> Timeline:
	_time = -1.0  # 标记为相对事件，tick 时用 _cursor + n
	_every = -1.0
	_times = -1
	_wait_n = n
	return self


## 按当前构建时刻排一个事件：取 Boss 并 [code]start_phase(data)[/code]；该阶段击破后把 wait 基准设为
## 击破时刻并武装所有 wait。boss_getter 返回空则跳过，wait 不会武装。
## 与 [code]BossData.normal_phase()[/code]（静态声明阶段表）区分：这里是运行驱动“此刻进入该阶段”。
func start_phase(boss_getter: Callable, data: PhaseData) -> Timeline:
	return do(func():
		var boss = boss_getter.call()
		if boss == null:
			return
		boss.start_phase(data)
		# 击破后：记 _cursor + 武装 wait（Boss 战期间绝对时间事件照常触发）
		boss.phase_cleared.connect(func(_captured: bool, _bonus: int):
			_cursor = _elapsed
			_arm_waits()
		, CONNECT_ONE_SHOT)
	)


## 按当前构建时刻排一个事件：按序连打 [code]phases[/code]；每张击破后 gap 秒进下一张。
## 最后一张击破后才武装 wait —— 所以紧随其后的 [code]wait(n).do(...)[/code] 是「全部打完后 n 秒」。
## 空表视作「已打完」，立即武装 wait（避免后续 wait 永不触发）。
func sequence_phases(boss_getter: Callable, phases: Array[PhaseData], gap: float = 0.0) -> Timeline:
	return do(func(): _start_sequence(boss_getter, phases, gap))


## 不排时间点，下一次 tick 起手；事件驱动开战用（如对话 boss_fight）。
func start_sequence_now(boss_getter: Callable, phases: Array[PhaseData], gap: float = 0.0) -> void:
	_start_sequence(boss_getter, phases, gap)


func _start_sequence(boss_getter: Callable, phases: Array[PhaseData], gap: float) -> void:
	if phases.is_empty():
		_cursor = _elapsed
		_arm_waits()
		return
	_sequences.append({getter = boss_getter, phases = phases, gap = gap, index = 0, next_at = _elapsed})


## 起序列里的下一张；非最后一张击破后设 next_at（tick 到点再进），最后一张击破后武装 wait。
func _advance_sequence(seq: Dictionary) -> void:
	if seq.index >= seq.phases.size():
		return
	var data: PhaseData = seq.phases[seq.index]
	var is_last: bool = seq.index == seq.phases.size() - 1
	seq.index += 1
	seq.next_at = INF   # 等本张击破后再定下一张时刻
	var boss = seq.getter.call()
	if boss == null:
		return
	boss.start_phase(data)
	boss.phase_cleared.connect(func(_captured: bool, _bonus: int):
		if is_last:
			_cursor = _elapsed
			_arm_waits()
		else:
			seq.next_at = _elapsed + seq.gap
	, CONNECT_ONE_SHOT)


## 激活全部未触发的 wait 事件（各自按 _cursor + offset 触发）。
func _arm_waits() -> void:
	for ev in _events:
		if ev.wait_offset >= 0 and not ev.is_wait_armed and not ev.is_fired:
			ev.is_wait_armed = true


# ═══ 内部 ═══

func _add(t: float, cb: Callable, ev: float = -1.0, n: int = -1) -> void:
	var event := TimelineEvent.new(t, cb, ev, n)
	event.wait_offset = _wait_n
	_wait_n = -1.0
	_events.append(event)


# ═══ 运行 ═══

## 推进 delta 秒：触发到期事件、推进阶段序列、处理 loop。
## 返回是否仍需继续：loop 模式恒 true；否则还有未触发事件即 true。
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

	# 阶段序列：上一张击破后到点进下一张
	var seq_i := 0
	while seq_i < _sequences.size():
		var seq: Dictionary = _sequences[seq_i]
		if seq.index < seq.phases.size() and _elapsed >= seq.next_at:
			_advance_sequence(seq)
		if seq.index >= seq.phases.size():
			_sequences.remove_at(seq_i)   # 最后一张已起手 → 出列
		else:
			seq_i += 1

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


## 时间归零、清空阶段序列、所有事件标回未触发。
## 只重置时间与触发标记；wait 基准/武装状态和重复事件配置都不变。完整重播用 [method loop]。
func reset() -> void:
	_elapsed = 0.0
	_sequences.clear()
	for ev in _events:
		ev.is_fired = false

## 整段循环：所有事件都触发完（重复事件达到 times）后回到 loop_start，按原始时间戳重排，
## 并恢复每轮 every / times。loop_start = 所有事件“最后一次触发”的最大时刻
## （重复事件按 every × (times - 1) 算）；空时间线忽略。
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
