extends GutTest
## GameScene 接入：普通局自动开录，tick 钩子写入 ReplayV2，能落盘并读回。

const GAME_SCENE = preload("res://scenes/game_scene.tscn")


func before_each() -> void:
	ReplayV2Session.cancel_recording()
	ReplayV2Session.stop_playback()
	SimClock.reset()
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	SaveData.reset_session()
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0


func after_each() -> void:
	ReplayV2Session.cancel_recording()
	ReplayV2Session.stop_playback()
	SimClock.reset()
	SaveData.reset_session()


func test_normal_run_records_ticks_and_saves_v2_file() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 200:
		await get_tree().physics_frame

	assert_true(ReplayV2Session.is_recording(), "普通局应自动开录")
	assert_gt(ReplayV2Session.replay_tick_count(), 0, "应已录到 tick")

	var path := ReplayV2Session.finish_recording({"result": "test"})
	assert_ne(path, "", "结束录制应落盘")
	assert_true(FileAccess.file_exists(path), "回放文件应存在")
	var rec := ReplayV2.new()
	assert_true(rec.load_file(path), "新文件应能被 v2 读取")
	assert_gt(rec.tick_count(), 0, "回放应至少有一个 tick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_recorded_run_playback_matches_hashes() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 300:
		await get_tree().physics_frame
	var path := ReplayV2Session.finish_recording({"result": "test"})
	assert_ne(path, "", "录制应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplayV2Session.start_playback(path), "应能进入回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 200:
		await get_tree().physics_frame
	assert_true(ReplayV2Session.is_playing(), "回放应还在进行")
	assert_false(ReplayV2Session.has_diverged(), "回放前几 tick 不应出现哈希分歧")
	ReplayV2Session.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
