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
	# 切回阶段台（整关已释放，阶段台实例仍在）
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
