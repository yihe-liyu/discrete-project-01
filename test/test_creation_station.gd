extends GutTest
## 创作台（三合一）测试：页签切换/实例保持/运行时清理

const CS := preload("res://scenes/workbench/creation_station.tscn")
const CS_SCRIPT := preload("res://scripts/workbench/creation_station.gd")
const BUTTON_KIND := 0  # 占位（无类型化断言直接检查脚本路径）


func test_tabs_switch_and_keep_bench_instances():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs._slot_buttons.size(), 4, "4 个页签")
	# 默认=弹幕台
	assert_true(cs._view.get_script().resource_path.ends_with("bullet_bench.gd"), "默认弹幕台")
	var bullet_instance = cs._view
	# 切敌人台
	cs._on_slot(2)
	await get_tree().process_frame
	assert_true(cs._view.get_script().resource_path.ends_with("enemy_bench.gd"), "切到敌人台")
	# 切回弹幕台 → 同一实例（状态保留）
	cs._on_slot(1)
	await get_tree().process_frame
	assert_eq(cs._view, bullet_instance, "弹幕台实例保持（选择状态不丢）")
	# 切阶段台
	cs._on_slot(3)
	await get_tree().process_frame
	assert_true(cs._view.get_script().resource_path.ends_with("phase_bench.gd"), "切到阶段台")
	# 整关
	cs._on_slot(0)
	await get_tree().process_frame
	assert_true(cs._view.get_script().resource_path.ends_with("workbench.gd"), "整关=工作台")
	# 切回阶段台（整关已释放，阶段台实例仍在）
	cs._on_slot(3)
	await get_tree().process_frame
	assert_true(cs._view.get_script().resource_path.ends_with("phase_bench.gd"), "整关释放后回阶段台")



func test_preset_route_switches_tab_and_assembles():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 取目录里第一颗子弹条目 → 路由 → 应切弹幕台且装配+发射
	var entry = cs._bench_instances[0]._catalog.by_role("bullet")[0]
	BulletManager.clear_all()
	cs._route_preset(entry)
	await get_tree().process_frame
	assert_eq(cs._current_slot, 1, "路由到弹幕台")
	assert_true(cs._view._script_sel.selected > 0, "装配了脚本")
	assert_true(BulletManager.active_bullets.size() >= 1, "直达即发射（%d）" % BulletManager.active_bullets.size())
	cs.queue_free()


func test_burst_stops_after_tab_switch():
	DirAccess.remove_absolute("user://creation_station.cfg")
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 开连发并生成数颗弹
	cs._view._burst_chk.button_pressed = true
	cs._view._burst_left = 0.0
	cs._view._fire()
	assert_true(BulletManager.active_bullets.size() >= 1, "连发已开")
	# 切敌人台 → 子弹台冻结
	cs._on_slot(2)
	await get_tree().process_frame
	assert_eq(cs._bench_instances[0].process_mode, Node.PROCESS_MODE_DISABLED, "切走后子弹台冻结")
	# 等若干帧：后台不应再产生新弹
	for i in 6:
		await get_tree().process_frame
	assert_eq(BulletManager.active_bullets.size(), 0, "切换后不再产生新弹")
	# 切回 → 恢复
	cs._on_slot(1)
	await get_tree().process_frame
	assert_eq(cs._bench_instances[0].process_mode, Node.PROCESS_MODE_INHERIT, "切回恢复运转")
	cs.queue_free()

func test_switch_clears_runtime():
	DirAccess.remove_absolute("user://creation_station.cfg")  # 清工作区配置（测试隔离）
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 在弹幕台射一颗弹
	BulletManager.clear_all()
	cs._view._fire()
	assert_true(BulletManager.active_bullets.size() >= 1, "子弹已生成")
	# 切敌人台 → 应清弹
	cs._on_slot(2)
	await get_tree().process_frame
	assert_eq(BulletManager.active_bullets.size(), 0, "切换后清场")
	cs.queue_free()