extends GutTest
## Boss HUD 局部显隐：阶段进度点（History 行）默认隐藏、手动控制。
## 名字节点见 test_boss_name.gd；两者同一套机制（Boss 标志 + 信号 → BossUI 跟随）。


func test_phase_dots_default_hidden_and_toggle():
	var b := Boss.new()
	autofree(b)
	assert_false(b.is_phase_dots_shown(), "阶段进度点默认隐藏")
	var seen: Array[bool] = []
	b.phase_dots_visibility_changed.connect(func(v): seen.append(v))
	b.set_phase_dots_shown(true)
	assert_true(b.is_phase_dots_shown(), "可手动显示")
	assert_eq(seen, [true], "变化发一次信号")
	b.set_phase_dots_shown(true)
	assert_eq(seen.size(), 1, "同值不重复发信号")
	b.set_phase_dots_shown(false)
	assert_false(b.is_phase_dots_shown(), "可再收起")


func test_boss_ui_history_follows_visibility():
	var ui = load("res://scenes/ui/boss_ui.tscn").instantiate()
	add_child_autofree(ui)
	assert_false(ui._history.visible, "BossUI 进度点默认隐藏")
	ui._on_phase_dots_visibility_changed(true)
	assert_true(ui._history.visible, "回调应亮出进度点")
	ui._on_phase_dots_visibility_changed(false)
	assert_false(ui._history.visible, "回调应收起进度点")
