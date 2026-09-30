extends GutTest
## 参数面板（`param_panel`）：**键名必须单行可读**。
##
## 回归（2026-09-30，作者体检时发现）：键列只有 90px 且用了 `AUTOWRAP_WORD_SMART`，
## 于是 `move_speed` 在敌人台「参数 ▼」里显示成两行 —— `move_spee` / `d`。
## 键名是要**照抄进代码**的东西（`param("move_speed", v)`），断词等于看不清。
##
## 夹具用 `test/fixtures/param_panel_probe.gd`（float/int/Vector2/Color 四类）：它存在的唯一目的就是这个面板。

const PARAM := preload("res://scripts/workbench/param_panel.gd")
const PROBE := preload("res://test/fixtures/param_panel_probe.gd")
## 右侧面板真实可用宽度（面板 440 - 卡片内边距/滚动条）；键列宽度要在这个宽度里有意义
const PANEL_W := 410.0


func _panel() -> Control:
	var host := Control.new()
	host.size = Vector2(PANEL_W, 600.0)
	add_child_autofree(host)
	var panel: Control = PARAM.new()
	host.add_child(panel)
	# ⚠️ 必须把面板**约束到真实面板宽度**：否则 VBox 按最小尺寸铺开、键名拿到全宽，
	# 「单行」断言就永远是绿的（安慰剂 —— 第一次写这条就踩到了）
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.rebuild(PROBE)
	return panel


## 键名列：拿到该行的键名 Label（各类型行的 ctrl 都挂在同一行里）
func _key_label(row: Dictionary) -> Label:
	return (row.ctrl as Control).get_parent().get_child(0) as Label


func test_param_keys_are_single_line_and_show_full_name():
	var panel := _panel()
	await get_tree().process_frame
	assert_gt(panel.get_rows().size(), 0, "夹具应枚举出参数行")
	for row in panel.get_rows():
		var lb := _key_label(row)
		assert_not_null(lb, "每行都有键名 Label")
		assert_eq(lb.text, row.name, "键名不截断（就是要照抄的名字）")
		assert_eq(lb.autowrap_mode, TextServer.AUTOWRAP_OFF,
			"键名不许自动换行（曾把 move_speed 断成 move_spee / d）")
		assert_eq(lb.get_line_count(), 1, "键名渲染成单行（%s）" % row.name)
		assert_eq(lb.tooltip_text, row.name, "真超长时靠悬停看全名")


## 键列要有足够宽度：至少宽于最长键名，否则仍会走省略号
func test_param_key_column_fits_fixture_names():
	var panel := _panel()
	await get_tree().process_frame
	var longest := ""
	for row in panel.get_rows():
		if row.name.length() > longest.length():
			longest = row.name
	var lb := _key_label(panel.get_rows()[0])
	assert_gte(lb.custom_minimum_size.x, PARAM.KEY_COLUMN_W, "键列有固定宽度")
	var font := lb.get_theme_font("font")
	var px := font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1,
		lb.get_theme_font_size("font_size")).x
	assert_gte(lb.custom_minimum_size.x, px,
		"键列宽（%.0f）应放得下最长键名「%s」（%.0f px）" % [lb.custom_minimum_size.x, longest, px])
