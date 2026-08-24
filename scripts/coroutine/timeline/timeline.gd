class_name Timeline
extends RefCounted
## 时间线 —— 声明式替代 match _phase 状态机
##
##   var tl := Timeline.new(ctx)
##   tl.at(0.0).call(_bgm)
##   tl.at(2.0).every(1.5).times(4).call(_wave)
##   tl.at(10.0).spawn_boss(boss, pos)
##   tl.loop()
##
##   func _on_step(_ctx): return tl.tick(_ctx.clock.delta)

var ctx: StageContext
var _events: Array[TimelineEvent] = []
var _elapsed: float = 0.0
var _paused: bool = false
var _loop_start: float = -1.0
var _cursor: float = 0.0   # wait() 的参考点，每次 phase/dialogue 结束后更新
var bookmark_collector: Callable  # 可选：事件触发时回调(关卡时刻)，工作台书签收集用

# builder state
var _time: float = -1.0
var _every: float = -1.0
var _times: int = -1
var _wait_n: float = -1.0


func _init(p_ctx: StageContext) -> void:
	ctx = p_ctx


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


## 时钟起点偏移（工作台续跑用）：_elapsed 从 offset 起步，事件时刻保持绝对
## 状态栏/时间轴显示关卡绝对时刻（而非相对起点），避免"像从头开始"的错觉
func start_at(offset: float) -> void:
	_elapsed = maxf(offset, 0.0)


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
		# 旧行为：_paused = true 冻结整个时间轴直到击破（Boss 战期间后续 tl 事件全部失效）
		# 现改为：仅 wait 事件等待 phase_cleared 激活，绝对时间事件（at/t）战斗期间照常触发
		boss.phase_cleared.connect(func(_captured: bool, _bonus: int):
			_cursor = _elapsed
			# 激活全部未触发的 wait 事件（多个 wait 各自按 _cursor + offset 触发，
			# 支持 Boss 击破后编排多段相对波次/演出）
			for ev in _events:
				if ev.wait_offset >= 0 and not ev.wait_armed and not ev.fired:
					ev.wait_armed = true
		, CONNECT_ONE_SHOT)
	)


## 步骤版对话（DSL 步骤，台词内联）—— 唯一入口
func dialogue_steps(steps: Array) -> Timeline:
	return do(func(): ctx.play_dialogue_steps(steps))

func spawn_wave(data: BulletData, count: int, spread: float, dir: Vector2, at_pos: Vector2) -> Timeline:
	return do(func(): ctx.bullets.shoot_spread(data, count, spread, dir, at_pos))

func spawn_enemy(script: Script, pos: Vector2) -> Timeline:
	return do(func(): EnemyData.new().with_script(script).pos(pos).spawn(ctx))

func spawn_boss(data: BossData, pos: Vector2) -> Timeline:
	return do(func(): StageManager.spawn_boss(data, pos, ctx))

func play_bgm(stream: AudioStream) -> Timeline:
	return do(func(): ctx.audio.play_bgm(stream))


# ═══ 内部 ═══

func _add(t: float, cb: Callable, ev: float = -1.0, n: int = -1) -> void:
	var event := TimelineEvent.new(t, cb, ev, n)
	event.wait_offset = _wait_n
	_wait_n = -1.0
	_events.append(event)


# ═══ 运行 ═══

func tick(delta: float) -> bool:
	if _paused:
		return true
	_elapsed += delta
	
	for ev in _events:
		if ev.fired and ev.repeat_every < 0:
			continue
		var t := ev.time
		if ev.wait_offset >= 0:
			if not ev.wait_armed:
				continue  # 还没被 phase 激活
			t = _cursor + ev.wait_offset
		if _elapsed >= t:
			if bookmark_collector.is_valid():
				bookmark_collector.call(t)  # 记录事件设计时刻（快进大 delta 下 _elapsed 会偏移）
			ev.execute()
			if ev.repeat_every >= 0:
				ev.time += ev.repeat_every
				ev.fired_count += 1
				if ev.repeat_times > 0 and ev.fired_count >= ev.repeat_times:
					ev.fired = true
					ev.repeat_every = -1.0
			else:
				ev.fired = true
	
	if _loop_start >= 0 and _elapsed >= _loop_start and _all_onetime_fired():
		_reset_onetime()
		_elapsed = _loop_start
	
	if _loop_start >= 0:
		return true
	for ev in _events:
		if not ev.fired:
			return true
	return false


func _all_onetime_fired() -> bool:
	for ev in _events:
		if not ev.fired:
			return false
	return true

func _reset_onetime() -> void:
	for ev in _events:
		ev.fired = false
		# 用 _loop_start 而非当前 _elapsed：大 delta 跨过循环点时不会把下一轮事件时间戳推远
		ev.time = _loop_start + ev._original_time
		ev.fired_count = 0
		ev.repeat_every = ev._original_repeat_every
		ev.repeat_times = ev._original_repeat_times


func pause() -> void: _paused = true
func resume() -> void: _paused = false

func reset() -> void:
	_elapsed = 0.0
	for ev in _events:
		ev.fired = false

func seek(time: float) -> void:
	_elapsed = time
	for ev in _events:
		ev.fired = ev.time <= time and ev.repeat_every <= 0

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
