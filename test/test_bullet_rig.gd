extends GutTest
## 弹幕试验台热更新集成测试：重载成功自动重演 / 失败保留旧版。
## 走**公开接缝**（`load_script` / `set_watch_paths` / `age_watch_mtime` / `poll_hot_reload` /
## `force_hot_reload` / `reload_status_text` / `current_script` / `param_panel`）—— 不再摸 `_私有`。

const RIG := preload("res://scripts/workbench/bullet_bench.gd")
const FIXTURE := "res://test/fixtures/bullet_preview.gd"


func test_hot_reload_debounce_fires_after_stability():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.load_script(FIXTURE)
	var paths: Array[String] = [FIXTURE]
	rig.set_watch_paths(paths)
	rig.age_watch_mtime(FIXTURE, 30.0)     # 等价于"这个脚本刚被改过"
	rig.set_hot_enabled(true)
	BulletManager.current.clear_all()
	rig.poll_hot_reload(0.5)
	assert_true(rig.reload_status_text().contains("检测到修改"), "首检测提示")
	rig.poll_hot_reload(0.5)
	rig.poll_hot_reload(0.5)
	assert_true(rig.reload_status_text().contains("已重载"),
		"防抖后触发重载（状态：%s）" % rig.reload_status_text())
	assert_true(BulletManager.current.active_count() >= 1, "重演发弹")
	rig.queue_free()


func test_param_panel_lists_script_vars():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.load_script(FIXTURE)               # 装载即重建参数面板（与用户选脚本同一条实现）
	var panel := rig.param_panel()
	var rows = panel.get_rows()
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
	var params = panel.collect()
	assert_eq(params.get("decel", 0.0), 300.0, "收集到修改后的 decel")
	rig.queue_free()

func test_hot_reload_replays_and_keeps_old_on_failure():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# ① 成功路径：选一个真实弹丸脚本 → 重载 → 自动发弹重演
	rig.load_script(FIXTURE)
	assert_true(rig.watch_paths().size() >= 1, "监听集非空（%d）" % rig.watch_paths().size())
	BulletManager.current.clear_all()
	rig.force_hot_reload()
	assert_not_null(rig.current_script(), "重载后拿到新脚本")
	if rig.current_script():
		assert_eq(rig.current_script().resource_path, rig.current_script_path(), "主脚本已替换为新编译版本")
	assert_true(BulletManager.current.active_count() >= 1,
		"重载后自动清场+重演（场上 %d 颗）" % BulletManager.current.active_count())
	assert_true(rig.reload_status_text().contains("已重载"), "状态显示成功")

	# ② 失败路径：坏路径 → 保留旧脚本 + 红色失败状态
	var old_script: Script = rig.current_script()
	rig.load_script("res://no_such_script.gd")
	rig.force_hot_reload()
	assert_eq(rig.current_script(), old_script, "失败时保留旧脚本")
	assert_true(rig.reload_status_text().contains("失败"), "状态显示失败")
	rig.queue_free()


## F10b：拼装页能加 Move/Until/Action、生成代码、预览发射。
func test_composer_mode_builds_code_and_previews():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	rig.set_composer_mode(true)
	assert_true(rig.composer_mode(), "应切到拼装模式")
	var cp = rig.composer_panel()
	assert_not_null(cp, "拼装面板应存在")
	if cp == null:
		return
	cp.set_difficulty(0)
	cp.add_op(&"move", &"accel_heading")
	cp.add_op(&"until", &"never")
	cp.add_op(&"action", &"sfx")
	var code: String = cp.code()
	assert_true(code.contains("lc.accel_heading"), "代码含 Move")
	assert_true(code.contains("lc.until_never"), "代码含 Until")
	assert_true(code.contains("lc.sfx"), "代码含 Action")
	assert_true(code.contains("data.trajectory(lc)"), "代码以 trajectory 收尾")
	cp.add_op(&"action", &"emit")   # 带 BulletData spawn，验证快照可序列化
	cp.add_op(&"action", &"emit_variant")
	assert_true(cp.code().contains("_spawn_a"), "emit_variant 默认模板 A")
	assert_true(cp.code().contains("_spawn_b"), "emit_variant 默认模板 B")
	BulletManager.current.clear_all()
	rig.fire_once()
	assert_true(BulletManager.current.active_count() >= 1, "拼装页预览应发射")
	var snap: Dictionary = rig.snapshot()
	var cfg := ConfigFile.new()
	cfg.set_value("x", "data", snap)
	var cfg_path := "user://composer_snapshot_test.cfg"
	assert_eq(cfg.save(cfg_path), OK, "拼装工作区快照应能写入 ConfigFile（不能塞 BulletData 实例）")
	DirAccess.remove_absolute(cfg_path)
	var dump: Dictionary = cp.dump()
	cp.load_from(dump)
	assert_true(cp.code().contains("_spawn_a"), "模板快照恢复后 emit_variant 仍用 A")
	assert_true(cp.code().contains("_spawn_b"), "模板快照恢复后 emit_variant 仍用 B")
	rig.queue_free()
