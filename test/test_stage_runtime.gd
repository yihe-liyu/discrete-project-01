extends GutTest
## StageRuntime 收尾语义：`finish_stage()` 必须走**完整收尾**（发 `stage_cleared`），
## 而不是 `stop_stage()` 那条「拆场景」的路 —— 后者**先把 `current_stage` 置空**，
## 于是脚本 stop 引发的 `_on_stage_finished()` 会在 `if not current_stage` 处直接 return、
## **不发 `stage_cleared`**（曾因此没有"这关结束了"的出口：Boss 打完只能干等）。
##
## 相关：`StageDirector.finish_stage()`（内容动词）→ 本方法。


func _runtime() -> StageRuntime:
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	return rt


## 空壳关卡脚本：`auto_stop = false` → 一直跑，正好用来验证"是 finish_stage 把它停下来的"
func _stage_data() -> StageData:
	var data := StageData.new()
	data.stage_id = 99
	data.create_script = CoroutineScript
	return data


func test_finish_stage_emits_stage_cleared():
	var rt := _runtime()
	watch_signals(rt)
	rt.load_stage(_stage_data())
	assert_not_null(rt.current_stage, "关卡应已装载")

	rt.finish_stage()

	assert_signal_emitted(rt, "stage_cleared", "finish_stage 应发 stage_cleared（完整收尾）")
	assert_signal_emitted(rt, "all_enemies_defeated", "收尾也发 all_enemies_defeated")
	assert_null(rt.current_stage_script(), "收尾后关卡脚本应已停掉回收")


## 对比基线：`stop_stage()`（拆场景用）**不会**发 stage_cleared —— 这条正是当初选 finish_stage 的理由
func test_stop_stage_does_not_emit_stage_cleared():
	var rt := _runtime()
	watch_signals(rt)
	rt.load_stage(_stage_data())
	rt.stop_stage()
	assert_signal_not_emitted(rt, "stage_cleared", "stop_stage 是拆场景路径，不该当作通关")


## 没在跑关卡时收尾 → 静默 no-op（不崩、不乱发信号）
func test_finish_stage_on_inactive_runtime_is_noop():
	var rt := _runtime()
	watch_signals(rt)
	rt.finish_stage()
	assert_signal_not_emitted(rt, "stage_cleared", "无活动关卡时收尾应静默")
