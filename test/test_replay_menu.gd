extends GutTest
## Replay 菜单：列出 Replay 文件并生成可选项。

const MENU = preload("res://scenes/ui/replay_menu.tscn")

var _path := ReplaySession.DIR + "/test_menu_v2.json"


func before_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func after_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_lists_v2_entry() -> void:
	var rec := Replay.new()
	rec.begin(60, 123, ReplaySession.SIM_VERSION)
	rec.metadata = {"difficulty": 1, "character": 0, "start_stage_no": 1, "score": 4321}
	rec.capture_tick(0, 0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ReplaySession.DIR))
	assert_true(rec.save(_path), "应先写出一份 v2 回放")

	var menu: Node = MENU.instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	assert_not_null(menu.get_node_or_null("ReplayBox"), "回放页应生成列表容器")
	assert_eq(menu._rows.size(), 1, "应列出刚写的 v2 回放")
	assert_true(str(menu._rows[0].text).contains("4321"), "行内应显示分数")
