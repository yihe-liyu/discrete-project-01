extends GutTest
## R14 守卫：运行期代码不得用 ResourceSaver.save 写 res://（导出包只读必失败）。
## 只允许写 user://（符卡簿 / 音乐解锁等运行期档；res:// 不再有出厂种子档）。

const SCAN_DIRS: Array[String] = ["res://scripts", "res://data"]


## 全仓扫 ResourceSaver.save 行：不得含 res://（tools/ 是编辑器工具，不在扫描范围）。
func test_no_runtime_res_saver_writes_to_res() -> void:
	var offenders: Array[String] = []
	for d in SCAN_DIRS:
		_scan(d, offenders)
	assert_eq(offenders, [] as Array[String], "ResourceSaver.save 不得写 res://：%s" % [offenders])


func test_persistence_paths_are_user() -> void:
	assert_true(SpellBookManager.SPELL_BOOK_USER_PATH.begins_with("user://"), "符卡簿运行期档应在 user://")
	assert_true(AssetRegistry.MUSIC_REGISTRY_USER_PATH.begins_with("user://"), "音乐解锁档应在 user://")


func _scan(dir_path: String, offenders: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry != "kernel":   # vendor 快照豁免
				_scan(full, offenders)
		elif entry.ends_with(".gd"):
			_scan_file(full, offenders)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, offenders: Array[String]) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var line_no := 0
	while not f.eof_reached():
		line_no += 1
		var line := f.get_line()
		if line.contains("ResourceSaver.save") and line.contains("res://"):
			offenders.append("%s:%d" % [path, line_no])
	f.close()
