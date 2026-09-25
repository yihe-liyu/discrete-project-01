extends GutTest
## CoroutineScript.start() 的 `_on_start()` 钩子：start 后、首次 _tick 前调用一次。


class HookProbe extends CoroutineScript:
	var started: bool = false
	var ticked: int = 0

	func _on_start() -> void:
		started = true

	func _tick(_ctx: StageContext) -> Variant:
		ticked += 1
		return false


func _probe() -> Array:
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	var probe := HookProbe.new()
	add_child_autofree(probe)
	return [runner, probe]


func test_on_start_hook_runs_before_first_tick() -> void:
	var p := _probe()
	var probe: HookProbe = p[1]
	assert_false(probe.started, "start 前不应触发 _on_start")
	assert_eq(probe.ticked, 0, "start 前不应 _tick")
	probe.start(StageContext.new(p[0]))
	assert_true(probe.started, "start() 应调用 _on_start()")
	assert_eq(probe.ticked, 0, "_on_start 早于首次 _tick")


func test_start_injects_ctx() -> void:
	var p := _probe()
	var probe: HookProbe = p[1]
	var ctx := StageContext.new(p[0])
	assert_null(probe.ctx, "start 前 ctx 为 null")
	probe.start(ctx)
	assert_eq(probe.ctx, ctx, "start 应注入 ctx")
