extends GutTest
## 暂停页：5 个操作项 + 未录制时「保存录像」锁定。

const MENU = preload("res://scenes/ui/pause_menu.tscn")


func test_pause_menu_has_all_actions() -> void:
	var menu: Node = MENU.instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	var list := menu.get_node_or_null("Panel/MenuList")
	assert_not_null(list, "暂停页应有 Panel/MenuList")
	if list == null:
		return
	assert_eq(list.get_child_count(), 5, "暂停页应有 5 个操作项")
	assert_eq((list.get_node("Resume/Main") as Label).text, "解除游戏暂停")
	assert_eq((list.get_node("TitleMenu/Main") as Label).text, "返回标题菜单")
	assert_eq((list.get_node("SaveReplay/Main") as Label).text, "保存录像后结束游戏")
	assert_eq((list.get_node("Manual/Main") as Label).text, "操作说明")
	assert_eq((list.get_node("Restart/Main") as Label).text, "从头重新开始")


func test_save_replay_locked_when_not_recording() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	var menu: Node = MENU.instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	assert_true(menu._is_save_locked(), "非录制状态不能保存录像")


func test_confirm_defaults_to_no_and_can_cancel() -> void:
	var menu: Node = MENU.instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	menu._open_confirm(0)
	assert_true(menu._confirm_open, "确认面板应打开")
	assert_eq(menu._confirm_index, 1, "默认选中「算了」")
	assert_true(menu._confirm_root.visible, "确认面板应可见")
	await menu._close_confirm()
	assert_false(menu._confirm_open, "取消后确认面板应关闭")
