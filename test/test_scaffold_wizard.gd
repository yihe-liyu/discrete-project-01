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
	wizard.hide()
