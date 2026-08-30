extends GutTest
## 创作台（三合一）测试：页签切换/实例保持/运行时清理

const CS := preload("res://scenes/workbench/creation_station.tscn")
const CS_SCRIPT := preload("res://scripts/workbench/creation_station.gd")
const BUTTON_KIND := 0  # 占位（无类型化断言直接检查脚本路径）


func test_tabs_switch_and_keep_rig_instances():
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(cs._tab_btns.size(), 4, "4 个页签")
	# 默认=弹幕台
	assert_true(cs._page.get_script().resource_path.ends_with("bullet_rig.gd"), "默认弹幕台")
	var bullet_instance = cs._page
	# 切敌人台
	cs._on_tab(2)
	await get_tree().process_frame
	assert_true(cs._page.get_script().resource_path.ends_with("enemy_rig.gd"), "切到敌人台")
	# 切回弹幕台 → 同一实例（状态保留）
	cs._on_tab(1)
	await get_tree().process_frame
	assert_eq(cs._page, bullet_instance, "弹幕台实例保持（选择状态不丢）")
	# 切阶段台
	cs._on_tab(3)
	await get_tree().process_frame
	assert_true(cs._page.get_script().resource_path.ends_with("phase_rig.gd"), "切到阶段台")
	# 整关
	cs._on_tab(0)
	await get_tree().process_frame
	assert_true(cs._page.get_script().resource_path.ends_with("workbench.gd"), "整关=工作台")
	# 切回阶段台（整关已释放，阶段台实例仍在）
	cs._on_tab(3)
	await get_tree().process_frame
	assert_true(cs._page.get_script().resource_path.ends_with("phase_rig.gd"), "整关释放后回阶段台")


func test_switch_clears_runtime():
	var cs: Control = CS.instantiate()
	add_child_autofree(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	# 在弹幕台射一颗弹
	BulletManager.clear_all()
	cs._page._fire()
	assert_true(BulletManager.active_bullets.size() >= 1, "子弹已生成")
	# 切敌人台 → 应清弹
	cs._on_tab(2)
	await get_tree().process_frame
	assert_eq(BulletManager.active_bullets.size(), 0, "切换后清场")
	cs.queue_free()
