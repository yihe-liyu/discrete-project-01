extends GutTest
## 选项菜单「清空数据」动作项：无 def（曾 Invalid access 'def'）；二次确认 +
## 无档清空（曾 erase 不存在段 ERR_FAIL）。两个曾漏到运行的 UI bug 的回归。

const OPTION_MENU := preload("res://scenes/ui/option_menu.tscn")


func _action_index(menu) -> int:
	for i in menu.ITEMS.size():
		if menu.ITEMS[i]["type"] == "action":
			return i
	return -1


func test_clear_data_item_and_double_confirm() -> void:
	var menu = OPTION_MENU.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var idx := _action_index(menu)
	assert_true(idx >= 0, "应有 action（清空数据）项")
	if idx < 0:
		return
	# 动作项没有 def：刷新值不应报错
	menu._refresh_values()
	menu._nav_index = idx
	assert_eq(menu._confirm_index, -1, "初始不在确认态")
	# 第一次 Z：进入确认态，不执行
	menu._activate_action()
	assert_eq(menu._confirm_index, idx, "第一次应进入确认态")
	# 第二次 Z：执行清空并退出确认态（无档时也不应报错）
	menu._activate_action()
	assert_eq(menu._confirm_index, -1, "第二次应执行并退出确认态")
	assert_true(menu._cleared, "应标记已清空")


func test_cancel_confirm_does_not_clear() -> void:
	var menu = OPTION_MENU.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var idx := _action_index(menu)
	if idx < 0:
		return
	menu._nav_index = idx
	menu._activate_action()
	assert_eq(menu._confirm_index, idx, "进入确认态")
	menu._cancel_confirm()
	assert_eq(menu._confirm_index, -1, "取消后退出确认态")
	assert_false(menu._cleared, "取消不应标记已清空")
