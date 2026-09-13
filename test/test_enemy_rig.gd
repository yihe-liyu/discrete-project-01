extends GutTest
## 敌人组合台测试：壳组装 / 真实生成 / 热重载重演

const SHELL := preload("res://scripts/workbench/enemy_shell.gd")
const RIG := preload("res://scripts/workbench/enemy_bench.gd")




func test_enemy_shell_build():
	var s = SHELL.new()
	s.visual_key = "blue_big_fairy"
	s.max_hp = 500
	s.hitbox_radius = 48.0
	s.item_power = 5
	s.item_point = 12
	s.item_life_full = 1
	s.item_bomb_full = 2
	var d: EnemyData = s.build()
	assert_eq(d.visual_scene, AssetRegistry.enemy_visuals["blue_big_fairy"], "外观对应")
	assert_eq(d.max_hp, 500, "HP")
	assert_eq(d.hitbox_radius, 48.0, "判定")
	assert_eq(d.item_power, 5, "P 掉落")
	assert_eq(d.item_point, 12, "点掉落")
	assert_eq(d.item_life_full, 1, "整残机掉落")
	assert_eq(d.item_bomb_full, 2, "整B掉落")
	assert_null(d.behavior_script, "无魂=纯壳")
	# 带魂
	var e: EnemyData = s.build(load("res://data/stages/stage01/enemy/enemy01.gd"))
	assert_not_null(e.behavior_script, "带魂组装")
	assert_eq(SHELL.visual_keys().size(), AssetRegistry.enemy_visuals.size(), "外观清单来自 AssetRegistry")



func test_param_listing_and_difficulty():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig._cur_script_path = "res://data/stages/stage01/enemy/enemy01.gd"
	rig._cur_script = load(rig._cur_script_path)
	rig._param_panel.rebuild(rig._cur_script)
	assert_true(rig._param_panel.get_rows().size() >= 3, "枚举出参数行（%d）" % rig._param_panel.get_rows().size())
	var names: Array[String] = []
	var target_y_spin := -1
	for i in rig._param_panel.get_rows().size():
		var row = rig._param_panel.get_rows()[i]
		names.append(row.name)
		if row.name == "target_y":
			target_y_spin = i
	assert_true(names.has("target_y"), "含 target_y")
	assert_true(names.has("rate"), "含 rate")
	if target_y_spin >= 0:
		assert_eq(float(rig._param_panel.get_rows()[target_y_spin].ctrl.value), 300.0, "默认值=脚本 var 值（target_y=300）")
	# 难度切换：diff_pick 实时读取 → 立即可变（注意还原，避免污染其他用例）
	var saved_diff := SaveData.selected_difficulty
	rig._on_diff_changed(2)
	assert_eq(SaveData.selected_difficulty, 2, "难度切 Hard(2)")
	rig._on_diff_changed(0)
	assert_eq(SaveData.selected_difficulty, 0, "难度切 Easy(0)")
	SaveData.selected_difficulty = saved_diff
	rig.queue_free()


func test_vector2_and_color_params():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig._cur_script_path = "res://data/stages/stage01/enemy/enemy03.gd"
	rig._cur_script = load(rig._cur_script_path)
	rig._param_panel.rebuild(rig._cur_script)
	# enemy03: target_pos(默认 0,0)/rate=int 1/bullet_color=RED/start_time=2.0
	var found_vec := false
	var found_color := false
	for row in rig._param_panel.get_rows():
		if row.name == "target_pos" and row.kind == "vec2":
			found_vec = true
			var wrap: HBoxContainer = row.ctrl
			assert_eq(float(wrap.get_child(0).value), 0.0, "x 默认 0（游戏里永远注入，裸跑=左上角陷阱）")
			wrap.get_child(0).value = 400.0
			wrap.get_child(1).value = 300.0
		if row.name == "bullet_color" and row.kind == "color":
			found_color = true
	assert_true(found_vec, "target_pos 是 Vector2 可调")
	# 零值(0,0)陷阱：标签应为橙色提醒
	var warn_found := false
	for c in rig._param_panel.body.get_children():
		if c is HBoxContainer and c.get_child_count() >= 2:
			var lb: Label = c.get_child(0)
			if lb.text == "target_pos" and lb.modulate.r > 0.9 and lb.modulate.g < 0.8:
				warn_found = true
	assert_true(warn_found, "零值 Vector2 参数带橙色提醒")
	assert_true(found_color, "bullet_color 是 Color 可调")
	var params = rig._param_panel.collect()
	assert_eq(params.get("target_pos", Vector2.ZERO), Vector2(400, 300), "收集到 Vector2 参数")
	assert_eq(params.get("bullet_color", Color.BLACK), Color.RED, "收集到 Color 参数")
	assert_eq(params.get("rate", 0), 1.0, "int 参数也在（float 值）")
	rig.queue_free()

func test_rig_spawn_and_hot_reload():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# 真实生成：默认壳 + enemy01 行为
	rig._stage_runtime.entity_registry.enemies.clear()
	rig._cur_script_path = "res://data/stages/stage01/enemy/enemy01.gd"
	rig._cur_script = load(rig._cur_script_path)
	rig._rebuild_watch()
	rig._spawn_pos = Vector2(GameConfig.FIELD_CENTER_X, 260.0)
	rig._spawn()
	assert_true(rig._stage_runtime.entity_registry.get_active_enemies().size() >= 1,
		"生成出敌人（%d）" % rig._stage_runtime.entity_registry.get_active_enemies().size())

	# 热重载：清场+重新生成
	rig._do_hot_reload()
	assert_true(rig._stage_runtime.entity_registry.get_active_enemies().size() >= 1,
		"重载后重新生成（%d）" % rig._stage_runtime.entity_registry.get_active_enemies().size())
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