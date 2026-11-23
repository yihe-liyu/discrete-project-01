extends GutTest
## Replay 菜单：25 行槽位、单条名字 / 日期 / 机体 / 难度 / 面数展示与改名。

const MENU = preload("res://scenes/ui/replay_menu.tscn")

var _path := ReplaySession.DIR + "/test_menu.json"


func before_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func after_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_lists_replay_with_columns() -> void:
	var rec := Replay.new()
	rec.begin(60, 123, ReplaySession.SIM_VERSION)
	rec.metadata = {
		"name": "TESTNAME", "difficulty": 1, "character": 0,
		"start_stage_no": 1, "stage_no": 2, "result": "game_over",
		"recorded_at": "2026-11-26T20:21:00", "score": 4321,
	}
	rec.capture_tick(0, 0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ReplaySession.DIR))
	assert_true(rec.save(_path), "应先写出一份 replay")

	var menu: Node = MENU.instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	assert_not_null(menu.get_node_or_null("ReplayBox"), "回放页应生成列表容器")
	assert_eq(menu._entries.size(), 1, "应列出刚写的 replay")
	assert_eq(menu._grid_rows.size(), 10, "每页固定 10 行")
	assert_eq(menu._rows.size(), 1, "只有一条真实回放")
	var text := str(menu._row_text(0))
	assert_true(text.contains("Ｎｏ．　０１"), "应显示全角编号")
	assert_true(text.contains("ＴＥＳＴＮＡＭＥ"), "应显示单条名字")
	assert_true(text.contains("２６／１１／２６　２０：２１"), "应显示录制时间")
	assert_true(text.contains("Ｒｅｉｍｕ"), "应显示机体（无 B）")
	assert_true(text.contains("Ｎｏｒｍａｌ"), "应显示难度")
	assert_true(text.contains("Ｓｔａｇｅ　２"), "应显示完整面数")
	assert_true(text.contains("０．０％"), "应显示处理落率")

	menu._turn_page(1)
	assert_eq(menu._page_offset, 10, "PageDown 应翻到第 11–20 槽")
	assert_true(str(menu._grid_rows[0].get_child(0).text).contains("Ｎｏ．　１１"), "第二页从 No.11 开始")
	menu._turn_page(1)
	assert_eq(menu._grid_rows.size(), 5, "最后一页只剩 No.21–25 五行")


func test_rename_replay_persists_name() -> void:
	var rec := Replay.new()
	rec.begin(60, 123, ReplaySession.SIM_VERSION)
	rec.metadata = {"name": "OLD", "difficulty": 1, "character": 0, "stage_no": 1}
	rec.capture_tick(0, 0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ReplaySession.DIR))
	assert_true(rec.save(_path))
	assert_true(ReplaySession.rename_replay(_path, "NEW NAME"))
	var loaded := Replay.new()
	assert_true(loaded.load_file(_path))
	assert_eq(str(loaded.metadata.get("name", "")), "NEW NAME")
