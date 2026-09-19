extends GutTest
## 「清空数据」：符卡记录 + 高分归零；**设置保留**。

func test_spell_book_clear_wipes_records_and_user_file() -> void:
	var mgr := SpellBookManager.new()
	mgr.spell_book = SpellRecordBook.new()
	mgr.spell_book.get_or_create(1, 0, 0, 0, 1, 123, 1, 1)
	mgr.save()
	assert_true(FileAccess.file_exists(SpellBookManager.SPELL_BOOK_USER_PATH), "应写出 user:// 档")
	mgr.clear_player_data()
	assert_true(mgr.spell_book.records.is_empty(), "清空后记录应为空")
	assert_false(FileAccess.file_exists(SpellBookManager.SPELL_BOOK_USER_PATH), "清空后应删掉 user:// 档")


func test_save_manager_clear_wipes_scores_keeps_settings() -> void:
	var mgr := SaveManager.new()
	mgr.load()
	mgr.set_setting("volume_bgm", 0.5)
	mgr.save_high_score(1, 999)
	assert_eq(mgr.get_high_score(1), 999, "先写一个高分")
	mgr.clear_player_data()
	assert_true(mgr.high_scores.is_empty(), "高分应清空")
	assert_eq(mgr.get_setting("volume_bgm", -1.0), 0.5, "设置应保留")
