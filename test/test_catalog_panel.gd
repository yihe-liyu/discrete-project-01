extends GutTest
## CatalogPanel 目录树渲染测试（M1.5：组头完整 / 重名消歧）

const PANEL := preload("res://scripts/workbench/catalog_panel.gd")



func test_drag_follows_mouse_and_clamps():
	var host := VBoxContainer.new()
	host.size = Vector2(300, 700)
	add_child_autofree(host)
	var panel = PANEL.new()
	host.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var start_div: float = panel._divider_y
	assert_true(start_div > 100.0, "初始分隔条位置（%s）" % str(start_div))
	# 按下（全局坐标 y=300）
	var btn := InputEventMouseButton.new()
	btn.button_index = MOUSE_BUTTON_LEFT
	btn.pressed = true
	btn.global_position = Vector2(150, 300)
	panel._on_info_sep_input(btn)
	# 拖动 +200px：分隔条应精确跟随（非累加、无反馈环）
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.global_position = Vector2(150, 500)
	panel._on_info_sep_input(motion)
	var max_div: float = panel._split_area.size.y - 120.0
	var exp1: float = clampf(start_div + 200.0, 100.0, max_div)
	assert_true(absf(panel._divider_y - exp1) < 1.0,
		"拖动跟随鼠标+钳制（期望 %s 实际 %s）" % [str(exp1), str(panel._divider_y)])
	# 再次 +5px（分隔条移动后仍稳定）
	motion.global_position = Vector2(150, 505)
	panel._on_info_sep_input(motion)
	var exp2: float = clampf(start_div + 205.0, 100.0, max_div)
	assert_true(absf(panel._divider_y - exp2) < 1.0,
		"多次拖动稳定（期望 %s 实际 %s）" % [str(exp2), str(panel._divider_y)])
	# 拖出面板 → 钳制在 [100, h-120]
	motion.global_position = Vector2(150, 99999)
	panel._on_info_sep_input(motion)
	assert_true(panel._divider_y <= panel._split_area.size.y - 120.0 + 0.5,
		"上限钳制（%s / %s）" % [str(panel._divider_y), str(panel._split_area.size.y)])
	motion.global_position = Vector2(150, 0)
	panel._on_info_sep_input(motion)
	assert_true(panel._divider_y >= 100.0 - 0.5, "下限钳制（%s）" % str(panel._divider_y))
	btn.pressed = false
	panel._on_info_sep_input(btn)
	panel.queue_free()

func test_panel_tree_has_role_headers_and_unique_names():
	# 模拟真实 %Pages：面板放进固定尺寸容器，靠 size_flags 撑满（不手动设 size）
	var host := VBoxContainer.new()
	host.size = Vector2(300, 700)
	add_child_autofree(host)
	var panel = PANEL.new()
	host.add_child(panel)
	await get_tree().process_frame  # _ready → refresh() + 首帧布局
	await get_tree().process_frame

	var root = panel._tree.get_root()
	assert_not_null(root, "树根存在")
	# 组头：stage/phase/boss_move/boss_shoot/bullet/enemy/bg（misc 空不显示）
	assert_eq(root.get_child_count(), 7, "应有 7 个角色组头")
	if root.get_child_count() != 7:
		return
	assert_eq(root.get_child(0).get_text(0), "关卡编排（1）", "首个组头=关卡编排")
	assert_eq(root.get_child(0).get_child_count(), 1, "关卡编排含 1 个条目（stage 脚本）")
	assert_eq(root.get_child(1).get_text(0), "阶段（7）", "第二组头=阶段7")
	var h2 = root.get_child(1)
	assert_eq(h2.get_child_count(), 7, "阶段含 7 个条目")
	# 重名消歧：试符【梦外之见】uid53/54 / 黄粱【不可测之梦】uid55/56
	var found_uid := false
	var mid_no_suffix := true
	for i in h2.get_child_count():
		var t: String = h2.get_child(i).get_text(0)
		if t.contains("试符") and t.contains("uid53"):
			found_uid = true
		if t.contains("卡摩瑞的道中非符1") and t.contains("uid"):
			mid_no_suffix = false
	assert_true(found_uid, "重名试符条目带 uid53 消歧")
	assert_true(mid_no_suffix, "非重名阶段不带 uid 后缀")
	# 分割布局真实高度（防 ScrollContainer 塌陷回归）
	assert_eq(panel.size_flags_vertical, Control.SIZE_EXPAND_FILL, "面板自身 EXPAND_FILL（防容器给 0 高）")
	assert_true(panel._split_area.size.y > 200.0, "split_area 有真实高度（%s）" % str(panel._split_area.size.y))
	assert_true(panel._tree.size.y > 100.0, "树有真实高度（%s）" % str(panel._tree.size.y))
	# 信息卡必须可见：底锚点偏移为负，且卡顶在分割区内
	assert_true(panel._info_panel.offset_top < 0.0, "信息卡偏移为负（底锚点）")
	assert_true(panel._info_panel.offset_top <= -100.0,
		"信息卡在分割区内（top=%s, 区高=%s）" % [str(panel._info_panel.offset_top), str(panel._split_area.size.y)])
	assert_true(panel._info_panel.size.y > 50.0,
		"信息卡可见高度（%s）" % str(panel._info_panel.size.y))
	panel.queue_free()