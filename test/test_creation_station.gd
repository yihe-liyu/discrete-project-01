extends GutTest
## 创作台（三合一）测试：页签切换/实例保持/运行时清理。
## 走**公开接缝**（`slot_count` / `open_slot` / `current_slot` / `current_view` / `bench_instance` /
## `selected_index` / `set_burst` / `fire_once`）—— 不再摸 `_私有`。

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