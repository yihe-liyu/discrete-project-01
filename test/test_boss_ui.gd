extends GutTest
## BossUI 场景声明式建树（R21）：倒计时 Label 与阶段点模板都在 .tscn 里，代码不再 .new()。

const BOSS_UI_SCENE := preload("res://scenes/ui/boss_ui.tscn")


func test_scene_declares_timer_and_dot_template() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	assert_not_null(ui.get_node_or_null("Control/TimerLabel"), "倒计时 Label 声明在场景里")
	assert_not_null(ui.get_node_or_null("Control/DotTemplate"), "阶段点模板声明在场景里")


func test_dot_template_hidden_and_sized() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var dot := ui.get_node_or_null("Control/DotTemplate") as ColorRect
	assert_not_null(dot, "模板在场景里")
	assert_false(dot.visible, "模板默认隐藏（不参与 HBox 布局）")
	assert_eq(dot.custom_minimum_size, Vector2(16.0, 16.0), "模板尺寸声明在场景里")
