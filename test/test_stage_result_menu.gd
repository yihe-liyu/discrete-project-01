extends GutTest
## 关卡结算覆盖层：数据填充、All Clear 只剩 Return、两个动作的结果字典。

const MENU := preload("res://scenes/ui/stage_result_menu.tscn")

func _make(overrides: Dictionary = {}) -> StageResultMenu:
	var data := {
		"has_next": true,
		"stage_no": 2,
		"stage_name": "测试面",
		"score": 12345,
		"high_score": 67890,
		"graze": 321,
		"power": "3.20",
		"lives": 4,
		"bombs": 5,
	}
	data.merge(overrides, true)
	var menu: StageResultMenu = MENU.instantiate() as StageResultMenu
	add_child_autofree(menu)
	menu.configure(data)
	return menu

func test_configure_fills_title_stage_and_stats() -> void:
	var menu := _make()
	assert_eq((menu.get_node("Panel/TitleLabel") as Label).text, "STAGE CLEAR")
	assert_eq((menu.get_node("Panel/StageLabel") as Label).text, "Stage 2 · 测试面")
	var stats := (menu.get_node("Panel/StatsLabel") as Label).text
	assert_string_contains(stats, "Score        12345")
	assert_string_contains(stats, "High Score   67890")
	assert_string_contains(stats, "Graze        321")
	assert_string_contains(stats, "Power        3.20/4.00")
	assert_string_contains(stats, "Lives        4")
	assert_string_contains(stats, "Bombs        5")

func test_all_clear_removes_continue() -> void:
	var menu := _make({"has_next": false})
	assert_eq((menu.get_node("Panel/TitleLabel") as Label).text, "ALL CLEAR")
	assert_null(menu.get_node_or_null("Panel/Container/ContinueLabel"), "All Clear 不应留下 Continue")
	assert_not_null(menu.get_node_or_null("Panel/Container/ReturnTitleLabel"))

func test_continue_and_return_actions() -> void:
	var menu := _make()
	var results: Array = []
	menu.finished.connect(func(r: Dictionary): results.append(r))
	menu._on_item_selected(0)
	menu._on_item_selected(1)
	assert_eq(results.size(), 2)
	assert_eq(results[0].get("action"), "continue")
	assert_eq(results[1].get("action"), "return")

func test_all_clear_only_returns() -> void:
	var menu := _make({"has_next": false})
	var results: Array = []
	menu.finished.connect(func(r: Dictionary): results.append(r))
	menu._on_item_selected(0)
	assert_eq(results.size(), 1)
	assert_eq(results[0].get("action"), "return")
