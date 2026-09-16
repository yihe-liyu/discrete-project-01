extends GutTest
## BossHud —— Boss 的运行时显示状态：名字文字 / 名字显隐 / 阶段进度点显隐。
## 从 Boss 抽出来后独立测：名字默认取 data.boss_name、可运行时覆盖；
## 名字与进度点都**默认隐藏**，显隐变化发信号，BossUI 订阅跟随。

func _make_hud(p_name: String) -> BossHud:
	var d := BossData.new()
	d.boss_name = p_name
	return BossHud.new(d)


func test_get_name_defaults_to_data():
	var hud := _make_hud("卡摩瑞")
	assert_eq(hud.get_name(), "卡摩瑞", "默认取 data.boss_name")


func test_set_name_overrides():
	var hud := _make_hud("卡摩瑞")
	hud.set_name("？？？")
	assert_eq(hud.get_name(), "？？？", "覆盖生效（隐藏状态）")
	hud.set_name("卡摩瑞")
	assert_eq(hud.get_name(), "卡摩瑞", "再次覆盖（揭示真名）")


func test_get_name_empty_when_no_data():
	var hud := BossHud.new()
	assert_eq(hud.get_name(), "", "无 data 时返回空")


func test_set_name_then_clear_to_data():
	var hud := _make_hud("卡摩瑞")
	hud.set_name("某卡")
	assert_eq(hud.get_name(), "某卡", "覆盖有效")
	hud.set_name("")   # 清空覆盖
	assert_eq(hud.get_name(), "卡摩瑞", "清空后回退 data.boss_name")


func test_set_name_emits_signal():
	var hud := _make_hud("卡摩瑞")
	var got: Array[String] = []
	hud.display_name_changed.connect(func(n): got.append(n))
	hud.set_name("？？？")
	assert_eq(got.size(), 1, "改名触发一次信号")
	assert_eq(got[0], "？？？", "信号带新显示名")


func test_clear_name_emits_fallback():
	var hud := _make_hud("卡摩瑞")
	hud.set_name("某卡")
	var got: Array[String] = []
	hud.display_name_changed.connect(func(n): got.append(n))
	hud.set_name("")   # 清空覆盖 → 回退 data.boss_name
	assert_eq(got.size(), 1, "清空触发一次信号")
	assert_eq(got[0], "卡摩瑞", "信号带回退名（data.boss_name）")


func test_name_visibility_defaults_hidden_and_toggles():
	var hud := _make_hud("卡摩瑞")
	assert_false(hud.is_name_shown(), "名字节点默认隐藏")
	var seen: Array[bool] = []
	hud.name_visibility_changed.connect(func(v): seen.append(v))
	hud.set_name_shown(true)
	assert_true(hud.is_name_shown(), "可手动显示")
	assert_eq(seen, [true], "可见性变化发一次信号")
	hud.set_name_shown(true)
	assert_eq(seen.size(), 1, "同值不重复发信号")
	hud.set_name_shown(false)
	assert_false(hud.is_name_shown(), "可再收起")


func test_phase_dots_default_hidden_and_toggle():
	var hud := BossHud.new()
	assert_false(hud.is_phase_dots_shown(), "阶段进度点默认隐藏")
	var seen: Array[bool] = []
	hud.phase_dots_visibility_changed.connect(func(v): seen.append(v))
	hud.set_phase_dots_shown(true)
	assert_true(hud.is_phase_dots_shown(), "可手动显示")
	assert_eq(seen, [true], "变化发一次信号")
	hud.set_phase_dots_shown(true)
	assert_eq(seen.size(), 1, "同值不重复发信号")
	hud.set_phase_dots_shown(false)
	assert_false(hud.is_phase_dots_shown(), "可再收起")


func test_boss_ui_name_label_follows_visibility():
	var ui = load("res://scenes/ui/boss_ui.tscn").instantiate()
	add_child_autofree(ui)
	assert_false(ui._boss_name.visible, "BossUI 名字节点默认隐藏")
	ui._on_name_visibility_changed(true)
	assert_true(ui._boss_name.visible, "回调应亮出名字节点")
	ui._on_name_visibility_changed(false)
	assert_false(ui._boss_name.visible, "回调应收起名字节点")


func test_boss_ui_history_follows_visibility():
	var ui = load("res://scenes/ui/boss_ui.tscn").instantiate()
	add_child_autofree(ui)
	assert_false(ui._history.visible, "BossUI 进度点默认隐藏")
	ui._on_phase_dots_visibility_changed(true)
	assert_true(ui._history.visible, "回调应亮出进度点")
	ui._on_phase_dots_visibility_changed(false)
	assert_false(ui._history.visible, "回调应收起进度点")
