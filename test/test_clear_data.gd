extends GutTest
## 「清空数据」+ 存档可靠性：符卡记录 / 高分归零、设置保留；
## SaveManager 的版本号 / 原子写 / 备份回退 / 读档校验。

const TEST_SAVE_PATH := "user://test_save_manager.cfg"


func before_each() -> void:
	_remove_save_files(TEST_SAVE_PATH)


func after_each() -> void:
	_remove_save_files(TEST_SAVE_PATH)


func test_spell_book_clear_wipes_records_and_user_file() -> void:
	var mgr := SpellBookManager.new()
	mgr.spell_book = SpellRecordBook.new()
	mgr.spell_book.get_or_create(1, 0, 0, 0, 1, 123, 1, 1)
	mgr.save()
	assert_true(FileAccess.file_exists(SpellBookManager.SPELL_BOOK_USER_PATH), "应写出 user:// 档")
	mgr.clear_player_data()
	assert_true(mgr.spell_book.records.is_empty(), "清空后记录应为空")
	assert_false(FileAccess.file_exists(SpellBookManager.SPELL_BOOK_USER_PATH), "清空后应删掉 user:// 档")


func test_save_manager_clear_is_safe_without_saved_file() -> void:
	# 全新档：user://save_data.cfg 不存在 → 无任何段；清空不应报错（曾 erase 不存在的段）
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	var mgr := SaveManager.new()
	mgr.load()
	mgr.clear_player_data()
	assert_true(mgr.high_scores.is_empty(), "无档时清空也应安全")


func test_save_manager_clear_wipes_scores_keeps_settings() -> void:
	var mgr := SaveManager.new()
	mgr.load()
	mgr.set_setting("volume_bgm", 0.5)
	mgr.save_high_score(1, 999)
	assert_eq(mgr.get_high_score(1), 999, "先写一个高分")
	mgr.clear_player_data()
	assert_true(mgr.high_scores.is_empty(), "高分应清空")
	assert_eq(mgr.get_setting("volume_bgm", -1.0), 0.5, "设置应保留")


# ═══ 存档可靠性（A）═══

func test_save_manager_round_trip_and_format_version() -> void:
	var mgr := _fresh_manager()
	assert_true(mgr.set_setting("volume_bgm", 0.35), "写设置应成功")
	assert_true(mgr.set_setting("fullscreen", true), "写开关应成功")
	assert_true(mgr.save_high_score(3, 12345), "写高分应成功")

	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SAVE_PATH), OK, "正式档应可读")
	assert_eq(int(config.get_value("meta", "version", 0)), SaveManager.FORMAT_VERSION,
		"应写入格式版本")

	var loaded := _fresh_manager()
	loaded.load()
	assert_almost_eq(float(loaded.get_setting("volume_bgm", 0.0)), 0.35, 0.001, "设置应回读")
	assert_true(bool(loaded.get_setting("fullscreen", false)), "开关应回读")
	assert_eq(loaded.get_high_score(3), 12345, "高分应回读")


func test_save_manager_atomic_write_and_backup() -> void:
	var mgr := _fresh_manager()
	assert_true(mgr.set_setting("volume_bgm", 0.25), "第一次保存应成功")
	assert_true(mgr.set_setting("volume_bgm", 0.75), "第二次保存应成功")

	assert_false(FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "提交后不应残留临时档")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "第二次保存应留下旧档备份")

	var backup := ConfigFile.new()
	assert_eq(backup.load(TEST_SAVE_PATH + ".bak"), OK, "备份应可读")
	assert_almost_eq(float(backup.get_value("settings", "volume_bgm", 0.0)), 0.25, 0.001,
		"备份应是上一版（0.25），而不是当前版")


func test_save_manager_recovers_from_backup_when_main_is_corrupt() -> void:
	var mgr := _fresh_manager()
	assert_true(mgr.set_setting("volume_bgm", 0.2), "先写可恢复的旧版")
	assert_true(mgr.set_setting("volume_bgm", 0.8), "再写新版（旧版进 .bak）")

	# 模拟写到一半 / 手改坏：正式档变成非 ConfigFile 内容
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	assert_not_null(file, "应能打开正式档模拟损坏")
	if file != null:
		file.store_string("not a config file")
		file.close()

	var recovered := _fresh_manager()
	recovered.load()
	assert_almost_eq(float(recovered.get_setting("volume_bgm", 0.0)), 0.2, 0.001,
		"主档坏掉应回退到备份")
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH), "坏主档应被移走")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"), "坏档应隔离为 .corrupt")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "好备份应保留")


func test_save_manager_reload_clears_stale_state() -> void:
	var mgr := _fresh_manager()
	assert_true(mgr.set_setting("volume_bgm", 0.4), "先落盘一个设置")
	mgr.settings["ghost"] = 1.0
	mgr.high_scores[99] = 7

	mgr.load()
	assert_false(mgr.settings.has("ghost"), "重载应清掉未落盘的旧 key")
	assert_eq(mgr.get_high_score(99), 0, "重载应清掉未落盘的旧高分")
	assert_almost_eq(float(mgr.get_setting("volume_bgm", 0.0)), 0.4, 0.001,
		"磁盘上的设置仍应保留")


func test_save_manager_sanitizes_invalid_values() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "volume_bgm", 5.0)
	config.set_value("settings", "fullscreen", "yes")
	config.set_value("settings", "max_fps", 999)
	config.set_value("high_scores", "abc", 10)
	config.set_value("high_scores", "1", -5)
	config.set_value("high_scores", "2", 123)
	assert_eq(config.save(TEST_SAVE_PATH), OK, "测试档应能写入")

	var mgr := _fresh_manager()
	mgr.load()
	assert_almost_eq(float(mgr.get_setting("volume_bgm", -1.0)), 1.0, 0.001,
		"音量越界应收敛到 1.0")
	assert_false(bool(mgr.get_setting("fullscreen", true)), "非法开关应回退 false")
	assert_eq(int(mgr.get_setting("max_fps", -1)), 0, "非法帧率应回退 0")
	assert_eq(mgr.get_high_score(1), 0, "负分应丢弃")
	assert_eq(mgr.get_high_score(2), 123, "合法高分应保留")


func test_save_manager_reports_write_failure() -> void:
	var mgr := SaveManager.new()
	mgr.save_path = "user://missing_dir_for_save/test_save.cfg"
	assert_false(mgr.set_setting("volume_bgm", 0.5), "目录不存在时应返回 false")
	assert_ne(mgr.get_last_save_error(), OK, "应记录具体错误")


func _fresh_manager() -> SaveManager:
	var mgr := SaveManager.new()
	mgr.save_path = TEST_SAVE_PATH
	return mgr


func _remove_save_files(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		var file_path: String = path + String(suffix)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
