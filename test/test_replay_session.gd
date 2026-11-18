extends GutTest
## ReplaySession：一局录制能落盘，并出现在回放列表里。

func before_each() -> void:
	ReplaySession.cancel_run()

func after_each() -> void:
	ReplaySession.cancel_run()
	ReplaySession.stop_playback()
	SaveData.reset_session()

func test_finish_writes_file_and_lists_it() -> void:
	assert_true(ReplaySession.start_run(), "首次 start_run 应开始录制")
	assert_true(ReplaySession.is_recording())
	ReplaySession.capture_frame()
	ReplaySession.capture_frame()
	var path := ReplaySession.finish_run({
		"difficulty": 2, "character": 1, "stage_no": 1, "score": 4321,
	})
	assert_ne(path, "", "结束时应写出回放文件")
	assert_false(ReplaySession.is_recording(), "落盘后应停止录制")
	assert_true(FileAccess.file_exists(path), "回放文件应存在")

	var entries := ReplaySession.list_replays()
	var found := false
	for e in entries:
		if e.get("path") == path:
			found = true
			assert_eq(int(e.get("duration", 0)), 2, "帧数应写进列表")
			assert_eq(int(e.get("metadata", {}).get("score", 0)), 4321)
	assert_true(found, "新回放应出现在列表里")
	if path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_start_run_is_idempotent_while_recording() -> void:
	assert_true(ReplaySession.start_run())
	assert_false(ReplaySession.start_run(), "切面 reload 不应重置正在录的局")
	ReplaySession.cancel_run()
	assert_false(ReplaySession.is_recording())


func test_playback_loads_route_seed_and_input() -> void:
	# 造一份可回放：seed + 一帧 shoot。
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray([1 << ReplayRecorder.ACTIONS.find("shoot")])
	rec.duration_frames = 1
	rec.metadata = {"difficulty": 1, "character": 0}
	rec.events = [{"frame": 0, "action": "cancel&bomb"}]
	var path := "user://test_replay_playback.json"
	assert_true(rec.save(path))

	assert_true(ReplaySession.start_playback(path), "应能进入回放")
	assert_true(ReplaySession.is_playing())
	assert_eq(SaveData.selected_difficulty, 1)
	assert_eq(SaveData.current_stage_id, 1)
	assert_eq(RNG.get_seed(), rec.rng_seed, "回放应恢复录制种子")
	assert_true(ReplaySession.advance_frame(), "首帧应可推进")
	assert_true(PlayerInput.is_action_pressed("shoot"), "回放输入应覆盖真实 Input")
	assert_eq(ReplaySession.poll_events(), [&"cancel&bomb"], "离散 bomb 事件应按帧触发")
	assert_false(ReplaySession.advance_frame(), "帧用完后应结束")
	assert_false(ReplaySession.is_playing())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_replay_menu_builds_list() -> void:
	var menu = load("res://scenes/ui/replay_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	assert_not_null(menu.get_node_or_null("ReplayBox"), "回放页应生成列表容器")
