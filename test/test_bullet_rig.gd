extends GutTest
## 弹幕试验台热更新（M2b）集成测试：重载成功自动重演 / 失败保留旧版

const RIG := preload("res://scripts/workbench/bullet_rig.gd")


func test_hot_reload_replays_and_keeps_old_on_failure():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame

	# ① 成功路径：选一个真实弹丸脚本 → 重载 → 自动发弹重演
	rig._cur_script_path = "res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd"
	rig._rebuild_watch()
	assert_true(rig._watch_paths.size() >= 1, "监听集非空（%d）" % rig._watch_paths.size())
	BulletManager.clear_all()
	rig._do_hot_reload()
	assert_not_null(rig._cur_script, "重载后拿到新脚本")
	if rig._cur_script:
		assert_eq(rig._cur_script.resource_path, rig._cur_script_path, "主脚本已替换为新编译版本")
	assert_true(BulletManager.active_bullets.size() >= 1,
		"重载后自动清场+重演（场上 %d 颗）" % BulletManager.active_bullets.size())
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