extends GutTest
## 回归：Camp 第一次打开「＋变体」时，VBox 尚未折行，按内容最小尺寸会把窗口从顶上拉高。

const WIZARD := preload("res://scripts/workbench/scaffold_wizard.gd")
const STAGE01 := "res://data/stages/stage01/stage_data/stage01.tres"


func test_first_open_uses_fixed_size() -> void:
	var wizard = WIZARD.new()
	add_child_autofree(wizard)
	wizard.open_for(load(STAGE01))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(wizard.size, Vector2i(620, 460), "第一次打开应为固定 620x460")
	var content := wizard.get_child(0)
	assert_eq(content.get_class(), "Control", "内容只用一个根 Control，避免 Window 二次拉满")
	var plan_scroll: ScrollContainer = null
	for child in content.get_children():
		if child is ScrollContainer:
			plan_scroll = child
			break
	assert_not_null(plan_scroll, "计划区应是固定高度的 ScrollContainer")
	if plan_scroll:
		assert_eq(plan_scroll.position, Vector2(8, 168), "计划区起点在表单下方")
		assert_eq(plan_scroll.size, Vector2(604, 210), "计划区不能压到按钮")
	wizard.hide()
