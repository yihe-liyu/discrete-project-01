extends GutTest
## 敌人组合台测试：壳组装 / 真实生成 / 热重载重演。
## 走**公开接缝**（`load_script` / `param_panel` / `select_difficulty` / `spawn_at` /
## `force_hot_reload` / `reload_status_text` / `stage_runtime` …）—— 不再摸 `_私有`。

const SHELL := preload("res://scripts/workbench/enemy_shell.gd")
const RIG := preload("res://scripts/workbench/enemy_bench.gd")
## 夹具敌人脚本（4 类可调参数 + 零值陷阱）：机制测试不绑内容 —— 见 docs/TEST_INDEX.md「内容绑定契约」。
## 用「路径常量 + preload」而不是 `PROBE_SCRIPT.resource_path`（后者在 preload 常量上编译期不可见）。
const PROBE_PATH := "res://test/fixtures/param_panel_probe.gd"
const PROBE_SCRIPT := preload(PROBE_PATH)




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
	var e: EnemyData = s.build(PROBE_SCRIPT)
	assert_not_null(e.behavior_script, "带魂组装")
	assert_eq(SHELL.visual_keys().size(), AssetRegistry.enemy_visuals.size(), "外观清单来自 AssetRegistry")



func test_param_listing_and_difficulty():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.load_script(PROBE_PATH)
	var panel := rig.param_panel()
	assert_true(panel.get_rows().size() >= 3, "枚举出参数行（%d）" % panel.get_rows().size())
	var names: Array[String] = []
	var target_y_spin := -1
	for i in panel.get_rows().size():
		var row = panel.get_rows()[i]
		names.append(row.name)
		if row.name == "target_y":
			target_y_spin = i
	assert_true(names.has("target_y"), "含 target_y")
	assert_true(names.has("rate"), "含 rate")
	if target_y_spin >= 0:
		assert_eq(float(panel.get_rows()[target_y_spin].ctrl.value), 300.0, "默认值=脚本 var 值（target_y=300）")
	# 难度切换：diff_pick 实时读取 → 立即可变（注意还原，避免污染其他用例）
	var saved_diff := SaveData.selected_difficulty
	rig.select_difficulty(2)
	assert_eq(SaveData.selected_difficulty, 2, "难度切 Hard(2)")
	rig.select_difficulty(0)
	assert_eq(SaveData.selected_difficulty, 0, "难度切 Easy(0)")
	SaveData.selected_difficulty = saved_diff
	rig.queue_free()


func test_vector2_and_color_params():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.load_script(PROBE_PATH)
	# 夹具脚本：target_pos(默认 0,0) / rate=int 1 / bullet_color=RED / start_time=2.0
	var found_vec := false
	var found_color := false
	for row in rig.param_panel().get_rows():
		if row.name == "target_pos" and row.kind == "vec2":
			found_vec = true
			var row_hbox: HBoxContainer = row.ctrl
			assert_eq(float(row_hbox.get_child(0).value), 0.0, "x 默认 0（游戏里永远注入，裸跑=左上角陷阱）")
			row_hbox.get_child(0).value = 400.0
			row_hbox.get_child(1).value = 300.0
		if row.name == "bullet_color" and row.kind == "color":
			found_color = true
	assert_true(found_vec, "target_pos 是 Vector2 可调")
	# 零值(0,0)陷阱：标签应为橙色提醒
	var warn_found := false
	for c in rig.param_panel().body.get_children():
		if c is HBoxContainer and c.get_child_count() >= 2:
			var lb: Label = c.get_child(0)
			if lb.text == "target_pos" and lb.modulate.r > 0.9 and lb.modulate.g < 0.8:
				warn_found = true
	assert_true(warn_found, "零值 Vector2 参数带橙色提醒")
	assert_true(found_color, "bullet_color 是 Color 可调")
	var params = rig.param_panel().collect()
	assert_eq(params.get("target_pos", Vector2.ZERO), Vector2(400, 300), "收集到 Vector2 参数")
	assert_eq(params.get("bullet_color", Color.BLACK), Color.RED, "收集到 Color 参数")
	assert_eq(params.get("rate", 0), 1.0, "int 参数也在（float 值）")
	rig.queue_free()

func test_rig_spawn_and_hot_reload():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# 真实生成：默认壳 + 夹具行为脚本
	var registry := rig.stage_runtime().entity_registry
	registry.enemies.clear()
	rig.load_script(PROBE_PATH)
	rig.spawn_at(Vector2(GameConfig.FIELD_CENTER_X, 260.0))
	assert_true(registry.get_active_enemies().size() >= 1,
		"生成出敌人（%d）" % registry.get_active_enemies().size())

	# 热重载：清场+重新生成
	rig.force_hot_reload()
	assert_true(registry.get_active_enemies().size() >= 1,
		"重载后重新生成（%d）" % registry.get_active_enemies().size())
	assert_true(rig.reload_status_text().contains("已重载"), "状态成功")

	# 失败路径：坏路径 → 保留旧脚本
	var old_script: Script = rig.current_script()
	rig.load_script("res://no_such_enemy.gd")
	rig.force_hot_reload()
	assert_eq(rig.current_script(), old_script, "失败保留旧脚本")
	assert_true(rig.reload_status_text().contains("失败"), "状态失败")
	rig.queue_free()