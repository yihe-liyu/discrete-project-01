extends GutTest
## 敌人组合台（M3a）测试：壳组装 / 真实生成 / 热重载重演

const SHELL := preload("res://scripts/workbench/enemy_shell.gd")
const RIG := preload("res://scripts/workbench/enemy_rig.gd")


func test_enemy_shell_build():
	var s = SHELL.new()
	s.visual_key = "blue_big_fairy"
	s.max_hp = 500
	s.hitbox_radius = 48.0
	s.item_power = 5
	s.item_point = 12
	var d: EnemyData = s.build()
	assert_eq(d.visual_scene, AssetRegistry.enemy_visuals["blue_big_fairy"], "外观对应")
	assert_eq(d.max_hp, 500, "HP")
	assert_eq(d.hitbox_radius, 48.0, "判定")
	assert_eq(d.item_power, 5, "P 掉落")
	assert_eq(d.item_point, 12, "点掉落")
	assert_null(d.behavior_script, "无魂=纯壳")
	# 带魂
	var e: EnemyData = s.build(load("res://data/stages/stage01/enemy/enemy01.gd"))
	assert_not_null(e.behavior_script, "带魂组装")
	assert_eq(SHELL.visual_keys().size(), AssetRegistry.enemy_visuals.size(), "外观清单来自 AssetRegistry")


func test_rig_spawn_and_hot_reload():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# 真实生成：默认壳 + enemy01 行为
	GameState.active_enemies.clear()
	rig._cur_script_path = "res://data/stages/stage01/enemy/enemy01.gd"
	rig._cur_script = load(rig._cur_script_path)
	rig._rebuild_watch()
	rig._spawn_pos = Vector2(GameConfig.FIELD_CENTER_X, 260.0)
	rig._spawn()
	assert_true(GameState.get_active_enemies().size() >= 1,
		"生成出敌人（%d）" % GameState.get_active_enemies().size())

	# 热重载：清场+重新生成
	rig._do_hot_reload()
	assert_true(GameState.get_active_enemies().size() >= 1,
		"重载后重新生成（%d）" % GameState.get_active_enemies().size())
	assert_true(rig._reload_status.text.contains("已重载"), "状态成功")

	# 失败路径：坏路径 → 保留旧脚本
	var old_script: Script = rig._cur_script
	rig._cur_script_path = "res://no_such_enemy.gd"
	rig._watch_paths.clear()
	rig._watch_paths.append(rig._cur_script_path)
	rig._watch_mtimes.clear()
	rig._do_hot_reload()
	assert_eq(rig._cur_script, old_script, "失败保留旧脚本")
	assert_true(rig._reload_status.text.contains("失败"), "状态失败")
	rig.queue_free()
