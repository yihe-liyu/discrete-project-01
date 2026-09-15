extends GutTest
## Timeline 时间线测试 —— 事件触发顺序 / 重复 / wait 语义 / loop
## 注意：GDScript lambda 无法修改外部局部变量（count += 1 无效），
## 必须用数组 append 或成员变量。

var _coroutine_runner: CoroutineRunner
var _stage_context: StageContext
var _fired: Array = []


func before_each():
	_coroutine_runner = CoroutineRunner.new()
	add_child_autofree(_coroutine_runner)
	_stage_context = StageContext.new(_coroutine_runner)
	_fired = []


func _make_timeline() -> Timeline:
	return Timeline.new(_stage_context)


## 基础：事件在设定时间点触发，按顺序
func test_events_fire_at_scheduled_time():
	var timeline := _make_timeline()
	var is_fired: Array = []
	timeline.at(1.0).do(func(): is_fired.append("a"))
	timeline.at(2.0).do(func(): is_fired.append("b"))

	timeline.tick(0.5)   # t=0.5
	assert_eq(is_fired, [], "t=0.5 不应触发任何事件")
	timeline.tick(0.6)   # t=1.1
	assert_eq(is_fired, ["a"], "t=1.1 应触发 a")
	timeline.tick(1.0)   # t=2.1
	assert_eq(is_fired, ["a", "b"], "t=2.1 应触发 b")


## 重复事件：every + times 恰好触发指定次数
func test_repeat_event_fires_exact_count():
	var timeline := _make_timeline()
	timeline.at(0.0).every(1.0).times(3).do(func(): _fired.append("x"))

	for i in 10:
		timeline.tick(1.0)  # t=1,2,...,10
	assert_eq(_fired.size(), 3, "every+times(3) 应恰好触发 3 次")


## 重复事件后不再触发
func test_repeat_event_stops_after_times():
	var timeline := _make_timeline()
	timeline.at(0.0).every(1.0).times(2).do(func(): _fired.append("x"))

	for i in 10:
		timeline.tick(1.0)
	assert_eq(_fired.size(), 2, "times(2) 之后不应再触发")


## tick 返回 false 当所有一次性事件已触发
func test_tick_returns_false_when_done():
	var timeline := _make_timeline()
	timeline.at(1.0).do(func(): pass)
	assert_true(timeline.tick(0.5), "未完成时 tick 应返回 true")
	timeline.tick(0.6)  # t=1.1, 事件触发
	assert_false(timeline.tick(0.0), "全部事件触发后 tick 应返回 false")


## loop 模式：事件播完重置并重复
func test_loop_resets_events():
	var timeline := _make_timeline()
	timeline.at(1.0).do(func(): _fired.append("x"))
	timeline.loop()

	timeline.tick(1.0)  # 触发 1
	timeline.tick(0.1)
	assert_eq(_fired.size(), 1, "第一轮应触发 1 次")
	timeline.tick(1.0)  # loop 重置后再次触发
	assert_eq(_fired.size(), 2, "loop 模式应重复触发")


## wait 事件：phase 激活前不触发
func test_wait_event_requires_phase_activation():
	var timeline := _make_timeline()
	timeline.wait(1.0).do(func(): _fired.append("x"))

	timeline.tick(5.0)  # 时间超过 wait，但没有 phase 激活
	assert_eq(_fired.size(), 0, "未激活的 wait 事件不应触发")


## reset 后重新播放
func test_reset_restarts():
	var timeline := _make_timeline()
	timeline.at(1.0).do(func(): _fired.append("x"))

	timeline.tick(1.0)
	assert_eq(_fired.size(), 1)
	timeline.reset()
	timeline.tick(1.0)
	assert_eq(_fired.size(), 2, "reset 后应可重新触发")


## loop 重置时间戳精度：大 delta 跨过循环点时，下一轮事件按 _loop_start 重排，
## 而不是按跨点后的 _elapsed 重排（旧实现会让下一轮整体推迟 overshoot 量）
func test_loop_reset_uses_loop_start_not_overshoot():
	var timeline := _make_timeline()
	var is_fired: Array = []
	timeline.at(1.0).do(func(): is_fired.append("a"))
	timeline.at(2.0).do(func(): is_fired.append("b"))
	timeline.loop()

	timeline.tick(1.5)   # t=1.5 → a
	assert_eq(is_fired, ["a"], "t=1.5 应触发 a")
	timeline.tick(1.5)   # t=3.0 → b，并重置到 loop_start=2.0（跨点 1.0s）
	assert_eq(is_fired, ["a", "b"], "t=3.0 应触发 b 并进入下一轮")
	timeline.tick(1.0)   # t=3.0 → 新一轮 a 应恰好在 loop_start+1.0 触发
	assert_eq(is_fired, ["a", "b", "a"], "跨点后下一轮事件应精确定时（不随 overshoot 漂移）")


## loop 应恢复重复事件配置：times(2) 每轮都触发 2 次，而不是重置后变成单次
func test_loop_restores_repeat_config():
	var timeline := _make_timeline()
	timeline.at(0.0).every(1.0).times(2).do(func(): _fired.append("x"))
	timeline.loop()

	timeline.tick(0.5)   # t=0.5 → x1
	timeline.tick(1.5)   # t=2.0 → x2，重复完成，_loop_start=1.0，重置
	assert_eq(_fired.size(), 2, "第一轮应触发 2 次")
	timeline.tick(1.0)   # t=3.0 → 新一轮 x1
	timeline.tick(1.0)   # t=4.0 → 新一轮 x2
	assert_eq(_fired.size(), 4, "loop 重置后应恢复重复配置，每轮都触发 2 次")
