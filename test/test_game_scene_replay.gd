extends GutTest
## GameScene 接入：普通局自动开录，tick 钩子写入 ReplayV2，能落盘并读回。

const GAME_SCENE = preload("res://scenes/game_scene.tscn")


func before_each() -> void:
	ReplayV2Session.cancel_recording()
	ReplayV2Session.stop_playback()
	ReplayV2Session.debug_capture = false
	ReplayV2Session.debug_snapshots.clear()
	SimClock.reset()
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	SaveData.reset_session()
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0


func after_each() -> void:
	ReplayV2Session.cancel_recording()
	ReplayV2Session.stop_playback()
	ReplayV2Session.debug_capture = false
	ReplayV2Session.debug_snapshots.clear()
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
	ReplayV2Session.debug_capture = false
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_bomb_command_is_recorded_and_replayed() -> void:
	ReplayV2Session.debug_capture = true
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 20:
		await get_tree().physics_frame
	PlayerInput.queue_command(&"bomb")
	for _i in 280:
		await get_tree().physics_frame
	var path := ReplayV2Session.finish_recording({"result": "test"})
	assert_ne(path, "", "bomb 局应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplayV2Session.start_playback(path), "bomb 局应能回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 300:
		await get_tree().physics_frame
	assert_true(ReplayV2Session.is_playing(), "bomb 回放应还在进行")
	assert_false(ReplayV2Session.has_diverged(), "bomb 命令回放不应出现哈希分歧")
	ReplayV2Session.stop_playback()
	ReplayV2Session.debug_capture = false
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 跨面起点（Stage 2）必须把录制时的自机资源恢复回来，否则第一帧就 hash 不一致。
func test_mid_route_start_restores_resources() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	assert_true(SaveData.begin_route_for_difficulty(1))
	var route := SaveData.current_route()
	assert_not_null(route)
	assert_gt(route.stages.size(), 1, "测试路线至少要有两面")
	SaveData.current_route_index = 1
	SaveData.current_stage_id = route.stages[1].stage_id
	var seed_res := PlayerResources.new()
	seed_res.lives = 5
	seed_res.bomb_count = 4
	seed_res.power_raw = 200
	seed_res.current_score = 123456
	seed_res.graze_count = 77
	SaveData.capture_run_state(seed_res)
	SaveData.is_route_transition = true

	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 30:
		await get_tree().physics_frame
	var path := ReplayV2Session.finish_recording({"result": "test"})
	assert_ne(path, "", "跨面起点也应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplayV2Session.start_playback(path), "跨面起点应能回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 20:
		await get_tree().physics_frame
	assert_true(ReplayV2Session.is_playing(), "跨面起点回放应还在进行")
	assert_false(ReplayV2Session.has_diverged(), "跨面起点第一帧不应分歧")
	ReplayV2Session.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
