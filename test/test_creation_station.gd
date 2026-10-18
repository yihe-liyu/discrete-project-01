extends GutTest
## 创作台（三合一）测试：页签切换/实例保持/运行时清理。
## 走**公开接缝**（`slot_count` / `open_slot` / `current_slot` / `current_view` / `bench_instance` /
## `selected_index` / `set_burst` / `fire_once`）—— 不再摸 `_私有`。

const CS := preload("res://scenes/workbench/creation_station.tscn")
const CS_SCRIPT := preload("res://scripts/workbench/creation_station.gd")


## 合成一次真左键按下/抬起（走 GUI 拾取 —— 和用户鼠标同一条路，不是调 open_slot 旁路）
## 按真实鼠标的时序分帧：按下 → 下一帧抬起（同一帧内成对发有时收不到）
func _mouse(pos: Vector2, button_down: bool) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = button_down
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)


## 从控件往上找它所在的 CanvasLayer（没挂在任何画布层 → null）
func _canvas_layer_of(node: Node) -> CanvasLayer:
	var n: Node = node
	while n != null:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return null


## 按下 → 下一帧抬起（按真实鼠标时序；同一帧内成对发有时收不到）
func _click_tab(button: Button) -> void:
	var c := button.get_global_rect().get_center()
	_mouse(c, true)
	await get_tree().process_frame
	_mouse(c, false)
	await get_tree().process_frame
	await get_tree().process_frame


## 回归（2026-09-30，作者报「弹幕台和整关预览点不开」）：**被托管的视图会压住页签横栏、吃掉点击**——
## 组合台的场地（`top_level` 的 832x928 Control + `MOUSE_FILTER_STOP`）与整关预览的 `BgContainer`
## （嵌页归一到 y≈1、宽 762）都盖在横栏上，于是 x<832 一带的页签全点不动。
## 修法：横栏挂 `CanvasLayer(layer=2)`（GUI 拾取按**画布层从高到低**）。
##
## 这条**必须用真点击**验：直接调 `open_slot()` 会绕过拾取 —— 正是它当初漏掉这个 bug 的原因。
## 只点左边两个页签：GUT 运行器自己的界面占着视口右半（x>652 是它的输出面板）会截走点击，
## 而作者报的「整关预览 / 弹幕台」正好都在左半，且这两下恰好各撞一个挡路者。
func test_tab_clicks_reach_the_bar_over_the_hosted_view():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 1600 下页签从内容区 384 开始，GUT 自己的输出面板会截走右侧点击；
	# 本用例要验真实拾取，切到 1280 全宽页签再点。
	cs.get_window().size = Vector2i(1280, 960)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar_layer := _canvas_layer_of(cs.slot_button(0))
	assert_not_null(bar_layer, "页签横栏必须在 CanvasLayer 里（被托管视图会吃掉横栏上的点击）")
	if bar_layer != null:
		assert_gt(bar_layer.layer, 1, "横栏要在更高的画布层（被托管视图自带 CanvasLayer(1) / top_level 控件）")

	# ① 敌人台（场地挡路）→ 点「弹幕台」
	cs.open_slot(2)
	await get_tree().process_frame
	await _click_tab(cs.slot_button(1))
	assert_eq(cs.current_slot(), 1, "从敌人台点「弹幕台」应切过去（场地的 STOP 曾把这一带点击全吃掉）")

	# ② 弹幕台（场地挡路）→ 点「整关预览」
	await _click_tab(cs.slot_button(0))
	assert_eq(cs.current_slot(), 0, "从弹幕台点「整关预览」应切过去")

	# ③ 整关预览（BgContainer 压在横栏上）→ 点「弹幕台」
	await _click_tab(cs.slot_button(1))
	assert_eq(cs.current_slot(), 1, "从整关预览点「弹幕台」应切过去（BgContainer 曾挡这里）")


func test_tabs_switch_and_keep_bench_instances():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.slot_count(), 4, "4 个页签")
	# 默认=弹幕台
	assert_true(cs.current_view().get_script().resource_path.ends_with("bullet_bench.gd"), "默认弹幕台")
	var bullet_instance = cs.current_view()
	# 切敌人台
	cs.open_slot(2)
	await get_tree().process_frame
	assert_true(cs.current_view().get_script().resource_path.ends_with("enemy_bench.gd"), "切到敌人台")
	# 切回弹幕台 → 同一实例（状态保留）
	cs.open_slot(1)
	await get_tree().process_frame
	assert_eq(cs.current_view(), bullet_instance, "弹幕台实例保持（选择状态不丢）")
	# 切阶段台
	cs.open_slot(3)
	await get_tree().process_frame
	assert_true(cs.current_view().get_script().resource_path.ends_with("phase_bench.gd"), "切到阶段台")
	# 整关
	cs.open_slot(0)
	await get_tree().process_frame
	assert_true(cs.current_view().get_script().resource_path.ends_with("workbench.gd"), "整关=工作台")
	# 切回阶段台（整关保活，阶段台实例仍在）
	cs.open_slot(3)
	await get_tree().process_frame
	assert_true(cs.current_view().get_script().resource_path.ends_with("phase_bench.gd"), "整关释放后回阶段台")



## 目录双击 → 路由到对应台并装配。
## 注（F10）：b 线后 `data/**` 已无 `*_bullet.gd`（弹道全部描述符化）→ `bullet` 组为空，
## 故这里用**仍有内容**的 `enemy` / `phase` 组覆盖路由机制本身；子弹路由待工作台支持
## 浏览 BulletLifecycle 描述符后恢复覆盖（TODO F10「工作台：弹道描述符浏览」）。
func test_preset_route_switches_tab_and_assembles():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	var catalog = cs.bench_instance(0).catalog()

	# 敌人：路由**末条** → 应切敌人台且选中的正是那一条（list 索引 +1，0 号是「不选」）
	var enemies: Array = catalog.by_role("enemy")
	assert_gt(enemies.size(), 0, "enemy 组应有内容（若空，本例需换 role）")
	cs.route_preset(enemies[enemies.size() - 1])
	await get_tree().process_frame
	assert_eq(cs.current_slot(), 2, "enemy 路由到敌人台")
	assert_eq(cs.bench_instance(1).selected_index(), enemies.size(), "敌人台选中被路由的那一条")

	# 阶段：路由末条 → 应切阶段台且选中该条（selected = 索引）
	var phases: Array = catalog.by_role("phase")
	assert_gt(phases.size(), 0, "phase 组应有内容")
	cs.route_preset(phases[phases.size() - 1])
	await get_tree().process_frame
	assert_eq(cs.current_slot(), 3, "phase 路由到阶段台")
	assert_eq(cs.bench_instance(2).selected_index(), phases.size() - 1, "阶段台选中被路由的那一条")
	cs.queue_free()


func test_burst_stops_after_tab_switch():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 开连发并生成数颗弹
	var bullet_bench: BenchBase = cs.bench_instance(0)
	bullet_bench.set_burst(true)
	bullet_bench.fire_once()
	assert_true(BulletManager.current.active_count() >= 1, "连发已开")
	# 切敌人台 → 子弹台冻结
	cs.open_slot(2)
	await get_tree().process_frame
	assert_eq(cs.bench_instance(0).process_mode, Node.PROCESS_MODE_DISABLED, "切走后子弹台冻结")
	# 等若干帧：后台不应再产生新弹
	for i in 6:
		await get_tree().process_frame
	assert_eq(BulletManager.current.active_count(), 0, "切换后不再产生新弹")
	# 切回 → 恢复
	cs.open_slot(1)
	await get_tree().process_frame
	assert_eq(cs.bench_instance(0).process_mode, Node.PROCESS_MODE_INHERIT, "切回恢复运转")
	cs.queue_free()

func test_switch_clears_runtime():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 在弹幕台射一颗弹
	BulletManager.current.clear_all()
	cs.bench_instance(0).fire_once()
	assert_true(BulletManager.current.active_count() >= 1, "子弹已生成")
	# 切敌人台 → 应清弹
	cs.open_slot(2)
	await get_tree().process_frame
	assert_eq(BulletManager.current.active_count(), 0, "切换后清场")
	cs.queue_free()


## Phase 2：整关预览不再是“切走即 queue_free”，切回来时间/关卡/播放状态都保留。
func test_preview_keeps_state_across_tab_switch():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	cs.open_slot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	var wb = cs.workbench_instance()
	assert_not_null(wb, "整关预览应创建并常驻")
	assert_eq(wb.bullet_manager().process_mode, Node.PROCESS_MODE_PAUSABLE,
		"预览 BulletManager 必须 PAUSABLE，否则 tree.paused 时弹幕照跑")
	var stage_script = wb.stage_runtime().current_stage_script()
	assert_not_null(stage_script, "整关应已启动关卡协程")
	assert_true(stage_script.is_running, "关卡协程应在跑")
	# 等到第一波敌人（stage01 1.0s 起），验真实敌人协程，而不是只验关卡脚本
	await wait_seconds(1.2)
	var enemy_script: CoroutineScript = null
	for enemy in wb.stage_runtime().entity_registry.get_active_enemies():
		for child in enemy.get_children():
			if child is CoroutineScript:
				enemy_script = child
				break
		if enemy_script != null:
			break
	assert_not_null(enemy_script, "1.2s 后应已有敌人协程")
	var bg_script: CoroutineScript = null
	var bg = wb.stage_runtime().current_background
	if bg != null:
		for child in bg.get_children():
			if child is CoroutineScript:
				bg_script = child
				break
	assert_not_null(bg_script, "stage01 背景应挂 CoroutineScript")
	var t_before: float = wb.current_time()
	var nested_layer := CanvasLayer.new()
	wb.add_child(nested_layer)
	assert_false(wb.preview_suspended(), "打开时不应处于冻结态")
	# 切到弹幕台：冻结但保留实例；全局 paused 必须解开
	cs.open_slot(1)
	await get_tree().process_frame
	assert_eq(cs.workbench_instance(), wb, "切页不应释放整关预览")
	assert_false(wb.visible, "切走后预览隐藏")
	assert_eq(wb.process_mode, Node.PROCESS_MODE_DISABLED, "切走后预览冻结")
	assert_true(wb.preview_suspended(), "预览应报告冻结")
	assert_false((wb.get_node("UI") as CanvasLayer).visible, "预览的 CanvasLayer UI 也要隐藏")
	assert_false(nested_layer.visible, "嵌套 CanvasLayer（stage logo 同路径）也要隐藏")
	assert_false(get_tree().paused, "切走后不能把全局暂停留在场上")
	# 显式 PAUSABLE 子节点（World/背景）必须也被冻结：真等 0.3s 验时钟不前进
	var frozen_at: float = wb.current_time()
	var enemy_frozen: float = enemy_script.game_time()
	var bg_frozen: float = bg_script.game_time()
	await wait_seconds(0.3)
	assert_almost_eq(wb.current_time(), frozen_at, 0.02, "冻结后关卡时间不应继续走")
	assert_almost_eq(stage_script.game_time(), frozen_at, 0.02, "冻结后关卡协程时钟不应继续走")
	assert_almost_eq(enemy_script.game_time(), enemy_frozen, 0.02, "冻结后敌人协程时钟不应继续走")
	assert_almost_eq(bg_script.game_time(), bg_frozen, 0.02, "冻结后背景协程时钟不应继续走")
	assert_true(stage_script.is_running, "切走后关卡协程不能被 _exit_tree 停掉")
	# 反复切换：协程必须始终存活（旧实现 remove_child 会 stop 所有 CoroutineRunner）
	for i in 2:
		cs.open_slot(0)
		await get_tree().process_frame
		assert_true(stage_script.is_running, "第 %d 次切回关卡协程仍应存活" % (i + 1))
		cs.open_slot(1)
		await get_tree().process_frame
		assert_true(stage_script.is_running, "第 %d 次切走关卡协程仍应存活" % (i + 1))
	# 切回：同一实例 + 时间不归零
	cs.open_slot(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.current_view(), wb, "切回仍是同一实例")
	assert_true(wb.visible, "切回预览可见")
	assert_eq(wb.process_mode, Node.PROCESS_MODE_ALWAYS, "切回恢复 process")
	assert_false(wb.preview_suspended(), "切回解除冻结")
	assert_true((wb.get_node("UI") as CanvasLayer).visible, "切回恢复 CanvasLayer UI")
	assert_true(nested_layer.visible, "切回恢复嵌套 CanvasLayer")
	nested_layer.queue_free()
	assert_gte(wb.current_time(), t_before - 0.1, "关卡时间不应归零")
	# 协程时钟必须真的继续走（不只是 is_running 标志）
	var gt0: float = stage_script.game_time()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(stage_script.game_time(), gt0, "切回后关卡协程时钟应继续推进")
	if enemy_script != null:
		var enemy_t0: float = enemy_script.game_time()
		var bg_t0: float = bg_script.game_time()
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert_true(enemy_script.is_running, "切回后敌人协程应存活")
		assert_gt(enemy_script.game_time(), enemy_t0, "切回后敌人协程时钟应继续推进")
		assert_true(bg_script.is_running, "切回后背景协程应存活")
		assert_gt(bg_script.game_time(), bg_t0, "切回后背景协程时钟应继续推进")


## Phase 2：v1 旧配置能读 + 写回 v2；坏 bench 数据降级为空，不半截恢复。
func test_workspace_v1_migrates_and_corrupt_data_is_ignored():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("ws", "slot", 1)
	cfg.set_value("bench0", "data", {"probe": "v1"})
	assert_eq(cfg.save("user://creation_station.cfg"), OK)
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs.workspace_loaded_from_version(), 1, "无 version 的旧文件按 v1 读")
	assert_eq(cs.workspace_version(), 2, "当前 schema = 2")
	assert_eq(cs.workspace_restore(1).get("probe", ""), "v1", "旧 bench 数据原样可见")
	var after := ConfigFile.new()
	assert_eq(after.load("user://creation_station.cfg"), OK)
	assert_eq(int(after.get_value("ws", "version", 0)), 2, "切页/加载后应写回 v2")
	cs.queue_free()
	# 坏数据：bench0.data 不是 Dictionary → 空工作区
	cfg = ConfigFile.new()
	cfg.set_value("ws", "slot", 1)
	cfg.set_value("bench0", "data", "broken")
	assert_eq(cfg.save("user://creation_station.cfg"), OK)
	var cs2: Control = CS.instantiate()
	add_child_autofree(cs2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs2.workspace_restore(1), {}, "坏 bench 数据应降级为空")
	cs2.queue_free()
	DirAccess.remove_absolute("user://creation_station.cfg")


## B+A：1–4 直达 / Ctrl+Tab 循环 / Alt+← 返回。
func test_page_shortcuts_and_history():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_2
	assert_true(cs.handle_shortcut(ev), "按 2 应消费")
	assert_eq(cs.current_slot(), 1, "2 → 弹幕台")
	ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_4
	assert_true(cs.handle_shortcut(ev), "按 4 应消费")
	assert_eq(cs.current_slot(), 3, "4 → 阶段台")
	# Ctrl+Tab 循环到最后 → 回到整关预览
	ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_TAB
	ev.ctrl_pressed = true
	assert_true(cs.handle_shortcut(ev), "Ctrl+Tab 应消费")
	assert_eq(cs.current_slot(), 0, "循环到整关预览")
	# Alt+← 返回上一个台
	ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_LEFT
	ev.alt_pressed = true
	assert_true(cs.handle_shortcut(ev), "Alt+← 应消费")
	assert_eq(cs.current_slot(), 3, "返回阶段台")


## 全局目录：不再只活在整关预览的右面板里；四个页签下都能开。
func test_catalog_drawer_available_on_every_slot():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	for slot in [0, 1, 2, 3]:
		cs.open_slot(slot)
		await get_tree().process_frame
		if slot == 0:
			assert_false(cs.current_view().call("catalog_tab_visible"),
				"嵌入预览应隐藏内部目录页签（全局抽屉接管）")
		cs.set_catalog_open(true)
		assert_true(cs.catalog_open(), "槽 %d 目录应能打开" % slot)
		assert_not_null(cs.catalog_panel(), "槽 %d 目录面板应存在" % slot)
		if cs.catalog_panel() != null:
			assert_true(cs.catalog_panel().is_visible_in_tree(), "槽 %d 目录应可见" % slot)
			assert_gt(cs.catalog_panel().size.x, 300.0, "槽 %d 目录抽屉应有宽度" % slot)
		cs.set_catalog_open(false)
		if cs.get_window().content_scale_size.x >= 1600:
			assert_true(cs.catalog_open(), "槽 %d：1600 常驻目录不可关" % slot)
			assert_false(cs.catalog_button().visible, "槽 %d：1600 不显示关闭按钮" % slot)
		else:
			assert_false(cs.catalog_open(), "槽 %d 目录应能关闭" % slot)


## 从弹幕台打开全局目录，双击敌人条目 → 切敌人台并选中。
func test_catalog_drawer_routes_from_bench_tab():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	cs.open_slot(1)
	await get_tree().process_frame
	cs.set_catalog_open(true)
	var enemies: Array = cs.bench_instance(0).catalog().by_role("enemy")
	assert_gt(enemies.size(), 0, "enemy 组应有内容")
	if enemies.is_empty():
		return
	cs.catalog_panel().preset_requested.emit(enemies[0])
	await get_tree().process_frame
	assert_eq(cs.current_slot(), 2, "从弹幕台点敌人条目应切敌人台")
	if cs.get_window().content_scale_size.x >= 1600:
		assert_true(cs.catalog_open(), "1600 路由后目录仍常驻")
	else:
		assert_false(cs.catalog_open(), "路由后目录应关闭")
	assert_eq(cs.bench_instance(1).selected_index(), 1, "敌人台选中条目 0（下拉 +1）")


## F10b：全局目录出现“弹道描述符”组；双击 Move → 切弹幕台拼装页并加入该 op。
func test_catalog_descriptor_group_routes_to_composer():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel = cs.catalog_panel()
	assert_not_null(panel, "全局目录应存在")
	if panel == null:
		return
	assert_true(panel.show_descriptors, "创作台目录应开启描述符组")
	var entries: Array = panel.descriptor_entries()
	assert_gt(entries.size(), 0, "描述符组应有条目")
	if entries.is_empty():
		return
	cs.open_slot(1)
	await get_tree().process_frame
	cs.set_catalog_open(true)
	panel.preset_requested.emit(entries[0])
	await get_tree().process_frame
	assert_eq(cs.current_slot(), 1, "描述符路由到弹幕台")
	assert_true(cs.bench_instance(0).composer_mode(), "应切到拼装模式")
	var cp = cs.bench_instance(0).composer_panel()
	assert_not_null(cp, "拼装面板应存在")
	if cp != null:
		assert_true(cp.code().contains("lc.accel_world"), "代码应含被加入的 accel_world")
