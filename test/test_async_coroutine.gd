extends GutTest
## AsyncCoroutineScript：await ctx.clock.delay / next_tick 必须跟着 runner 时钟走。

class DelayProbe extends AsyncCoroutineScript:
	var events: Array[String] = []

	func run_async(p_ctx: StageContext) -> void:
		events.append("start")
		var ok: bool = await p_ctx.clock.delay(0.5)
		events.append("after" if ok else "stopped")


class TickProbe extends AsyncCoroutineScript:
	var ticks: int = 0

	func run_async(p_ctx: StageContext) -> void:
		for _i in 3:
			var ok: bool = await p_ctx.clock.next_tick()
			if not ok:
				return
			ticks += 1


func _make(script: AsyncCoroutineScript) -> StageContext:
	add_child_autofree(script)
	return StageContext.new(script)


func test_delay_uses_runner_clock_and_emits_finished():
	var probe := DelayProbe.new()
	var ctx := _make(probe)
	watch_signals(probe)

	probe.start(ctx)
	assert_true(probe is CoroutineScript, "async 仍是 CoroutineScript 子类")
	assert_eq(probe.events, ["start"] as Array[String], "start 后应停在第一个 await")
	assert_true(probe.is_running, "等待期间 runner 应存活")

	probe.tick_manual(0.25)
	assert_eq(probe.events, ["start"] as Array[String], "0.25s 还不够")
	probe.tick_manual(0.25)
	assert_eq(probe.events, ["start", "after"] as Array[String], "0.5s 后应恢复")
	assert_false(probe.is_running, "run_async 返回后应停")
	assert_signal_emitted(probe, "finished")


func test_pause_freezes_delay_clock():
	var probe := DelayProbe.new()
	var ctx := _make(probe)
	probe.start(ctx)
	probe.pause()
	probe.tick_manual(10.0)
	assert_eq(probe.events, ["start"] as Array[String], "暂停时 tick_manual 不推时钟")
	assert_true(probe.is_running, "暂停不是结束")
	probe.resume()
	probe.tick_manual(0.5)
	assert_eq(probe.events, ["start", "after"] as Array[String], "恢复后继续")
	assert_false(probe.is_running)


func test_stop_wakes_delay_and_reports_stopped():
	var probe := DelayProbe.new()
	var ctx := _make(probe)
	probe.start(ctx)
	probe.stop()
	assert_eq(probe.events, ["start", "stopped"] as Array[String], "stop 应唤醒 await 并返回 false")
	assert_false(probe.is_running)


func test_physics_process_drives_async_clock():
	var probe := DelayProbe.new()
	add_child_autofree(probe)
	var ctx := StageContext.new(probe)
	probe.start(ctx)
	await wait_seconds(0.6)
	assert_eq(probe.events, ["start", "after"] as Array[String], "真实 _physics_process 应推进 delay")
	assert_false(probe.is_running)


func test_next_tick_advances_one_tick_at_a_time():
	var probe := TickProbe.new()
	var ctx := _make(probe)
	probe.start(ctx)
	assert_eq(probe.ticks, 0, "start 后应停在第一次 await")
	probe.tick_manual(1.0 / 60.0)
	assert_eq(probe.ticks, 1)
	probe.tick_manual(1.0 / 60.0)
	assert_eq(probe.ticks, 2)
	probe.tick_manual(1.0 / 60.0)
	assert_eq(probe.ticks, 3)
	assert_false(probe.is_running, "3 个 tick 后 run_async 应返回")
