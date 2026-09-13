extends GutTest
## 弹幕试验台热更新集成测试：重载成功自动重演 / 失败保留旧版

const RIG := preload("res://scripts/workbench/bullet_bench.gd")



func test_hot_reload_debounce_fires_after_stability():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig._cur_script_path = "res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd"
	rig._watch_paths.clear()
	rig._watch_paths.append(rig._cur_script_path)
	rig._watch_mtimes.clear()
	rig._watch_mtimes[rig._cur_script_path] = FileAccess.get_modified_time(rig._cur_script_path) - 30
	rig._hot_enabled = true
	BulletManager.current.clear_all()
	rig._process_hot_reload(0.5)
	assert_true(rig._reload_status.text.contains("检测到修改"), "首检测提示")
	rig._process_hot_reload(0.5)
	rig._process_hot_reload(0.5)
	assert_true(rig._reload_status.text.contains("已重载"),
		"防抖后触发重载（状态：%s）" % rig._reload_status.text)
	assert_true(BulletManager.current.active_count() >= 1, "重演发弹")
	rig.queue_free()


func test_param_panel_on_orbit_probe():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig._cur_script_path = "res://data/stages/stage03B/phase/spell03/orbit_probe.gd"
	rig._cur_script = load(rig._cur_script_path)
	rig._param_panel.rebuild(rig._cur_script)
	var rows = rig._param_panel.get_rows()
	assert_true(rows.size() >= 4, "枚举出参数行（%d）" % rows.size())
	var decel_found := false
	for row in rows:
		if row.name == "decel" and row.kind == "num":
			decel_found = true
			assert_eq(float(row.ctrl.value), 150.0, "decel 默认 150（来自脚本 var）")
			row.ctrl.value = 300.0
		if row.name == "hold_aim_probe" and row.kind == "bool":
			assert_eq(row.ctrl.button_pressed, false, "bool 默认 false")
	assert_true(decel_found, "decel 为可调数字")
	var params = rig._param_panel.collect()
	assert_eq(params.get("decel", 0.0), 300.0, "收集到修改后的 decel")
	rig.queue_free()

func test_hot_reload_replays_and_keeps_old_on_failure():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# ① 成功路径：选一个真实弹丸脚本 → 重载 → 自动发弹重演
	rig._cur_script_path = "res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd"
	rig._rebuild_watch()
	assert_true(rig._watch_paths.size() >= 1, "监听集非空（%d）" % rig._watch_paths.size())
	BulletManager.current.clear_all()
	rig._do_hot_reload()
	assert_not_null(rig._cur_script, "重载后拿到新脚本")
	if rig._cur_script:
		assert_eq(rig._cur_script.resource_path, rig._cur_script_path, "主脚本已替换为新编译版本")
	assert_true(BulletManager.current.active_count() >= 1,
		"重载后自动清场+重演（场上 %d 颗）" % BulletManager.current.active_count())
	assert_true(rig._reload_status.text.contains("已重载"), "状态显示成功")

	# ② 失败路径：坏路径 → 保留旧脚本 + 红色失败状态
	var old_script: Script = rig._cur_script
	rig._cur_script_path = "res://no_such_script.gd"
	rig._watch_paths.clear()
	rig._watch_paths.append(rig._cur_script_path)
	rig._watch_mtimes.clear()
	rig._do_hot_reload()
	assert_eq(rig._cur_script, old_script, "失败时保留旧脚本")
	assert_true(rig._reload_status.text.contains("失败"), "状态显示失败")
	rig.queue_free()