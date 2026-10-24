extends GutTest
## Phase 向导冒烟：能按当前 Stage 打开、有 Boss 可选、计划可创建。

const WIZARD := preload("res://scripts/workbench/phase_scaffold_wizard.gd")
const STAGE01 := "res://data/stages/stage01/stage_data/stage01.tres"


func test_opens_with_stage_bosses() -> void:
	var wizard = WIZARD.new()
	add_child_autofree(wizard)
	wizard.open_for(load(STAGE01))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(wizard.size, Vector2i(640, 560), "阶段向导固定尺寸")
	assert_true(wizard.get_ok_button().disabled, "空名称 / UID 尚未填时先禁用创建")
	wizard.hide()
