extends GutTest
## Boss 运行时显示名（get_boss_name / set_boss_name）：默认取 boss_data.boss_name，可运行时覆盖。
## 供 BossUI 读显示名 —— 揭示真名 / 符卡练习显示卡名。

func _make_boss(p_name: String) -> Boss:
	var b := Boss.new()
	var d := BossData.new()
	d.boss_name = p_name
	b._boss_data = d
	autofree(b)
	return b


func test_get_boss_name_defaults_to_data():
	var b := _make_boss("卡摩瑞")
	assert_eq(b.get_boss_name(), "卡摩瑞", "默认取 boss_data.boss_name")


func test_set_boss_name_overrides():
	var b := _make_boss("卡摩瑞")
	b.set_boss_name("？？？")
	assert_eq(b.get_boss_name(), "？？？", "覆盖生效（隐藏状态）")
	b.set_boss_name("卡摩瑞")
	assert_eq(b.get_boss_name(), "卡摩瑞", "再次覆盖（揭示真名）")


func test_get_boss_name_empty_when_no_data():
	var b := Boss.new()
	autofree(b)
	assert_eq(b.get_boss_name(), "", "无 boss_data 时返回空")


func test_set_boss_name_then_clear_to_data():
	var b := _make_boss("卡摩瑞")
	b.set_boss_name("某卡")
	assert_eq(b.get_boss_name(), "某卡", "覆盖有效")
	b.set_boss_name("")   # 清空覆盖
	assert_eq(b.get_boss_name(), "卡摩瑞", "清空后回退 boss_data.boss_name")


func test_set_boss_name_emits_signal():
	var b := _make_boss("卡摩瑞")
	var got: Array[String] = []
	b.display_name_changed.connect(func(n): got.append(n))
	b.set_boss_name("？？？")
	assert_eq(got.size(), 1, "改名触发一次信号")
	assert_eq(got[0], "？？？", "信号带新显示名")


func test_clear_name_emits_fallback():
	var b := _make_boss("卡摩瑞")
	b.set_boss_name("某卡")
	var got: Array[String] = []
	b.display_name_changed.connect(func(n): got.append(n))
	b.set_boss_name("")   # 清空覆盖 → 回退 boss_data.boss_name
	assert_eq(got.size(), 1, "清空触发一次信号")
	assert_eq(got[0], "卡摩瑞", "信号带回退名（boss_data.boss_name）")


func test_name_visibility_defaults_hidden_and_toggles():
	var b := _make_boss("卡摩瑞")
	assert_false(b.is_name_shown(), "名字节点默认隐藏")
	var seen: Array[bool] = []
	b.name_visibility_changed.connect(func(v): seen.append(v))
	b.set_name_shown(true)
	assert_true(b.is_name_shown(), "可手动显示")
	assert_eq(seen, [true], "可见性变化发一次信号")
	b.set_name_shown(true)
	assert_eq(seen.size(), 1, "同值不重复发信号")
	b.set_name_shown(false)
	assert_false(b.is_name_shown(), "可再收起")


func test_boss_ui_name_label_follows_visibility():
	var ui = load("res://scenes/ui/boss_ui.tscn").instantiate()
	add_child_autofree(ui)
	assert_false(ui._boss_name.visible, "BossUI 名字节点默认隐藏")
	ui._on_name_visibility_changed(true)
	assert_true(ui._boss_name.visible, "回调应亮出名字节点")
	ui._on_name_visibility_changed(false)
	assert_false(ui._boss_name.visible, "回调应收起名字节点")
