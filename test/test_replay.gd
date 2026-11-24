extends GutTest
## Replay：新格式只存输入 + 命令 + 哈希；录制 -> 落盘 -> 回放逐 tick 一致。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FIXTURES = preload("res://test/fixtures/fixture_lib.gd")


func after_each() -> void:
	PlayerInput.clear_override()
	PlayerInput.clear_latch()
	SimClock.reset()


func test_format_roundtrip_and_old_version_rejected() -> void:
	var rec := Replay.new()
	rec.begin(60, 42, "test-sim")
	rec.content_hash = "content-a"
	rec.capture_tick(0b1000, Replay.COMMAND_BOMB, 123, {"player": 111, "bullets": 222})
	rec.capture_tick(0b0100, Replay.COMMAND_MEMORY, 456)

	var path := "user://test_replay_format.json"
	assert_true(rec.save(path))
	var loaded := Replay.new()
	assert_true(loaded.load_file(path))
	assert_eq(loaded.tick_count(), 2)
	assert_eq(loaded.rng_seed, 42)
	assert_eq(loaded.content_hash, "content-a", "内容指纹应往返")
	assert_eq(loaded.mask_at(0), 0b1000)
	assert_eq(loaded.command_at(0), Replay.COMMAND_BOMB)
	assert_eq(loaded.hash_at(1), 456)
	assert_eq(int(loaded.fields_at(0).get("player", 0)), 111, "分项哈希应往返")
	assert_eq(int(loaded.fields_at(0).get("bullets", 0)), 222)
	assert_false(Replay.new().load_dict({"version": 1, "seed": "0", "duration": 0}),
		"旧 v1 JSON 必须被拒绝")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_record_then_replay_has_same_hash_per_tick() -> void:
	var rec := Replay.new()
	rec.begin(60, 12345, "test-sim")
	var recorded := _run_once(rec.rng_seed, rec, null)
	assert_eq(recorded, rec.hashes, "录制哈希应与运行时一致")

	var path := "user://test_replay_run.json"
	assert_true(rec.save(path), "应能落盘")
	var loaded := Replay.new()
	assert_true(loaded.load_file(path), "应能读回")

	var replayed := _run_once(loaded.rng_seed, null, loaded)
	assert_eq(replayed.size(), recorded.size())
	for i in recorded.size():
		if replayed[i] != recorded[i]:
			assert_eq(replayed[i], recorded[i], "回放首个分歧 tick=%d" % i)
			return
	assert_eq(replayed, recorded, "回放必须逐 tick 与录制一致")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 录制：recorder != null；回放：replay != null。两者都为空时按脚本生成输入。
func _run_once(p_seed: int, recorder: Replay, replay: Replay, ticks: int = 120) -> Array[int]:
	RNG.set_seed(p_seed)

	var host := KernelBulletHost.new()
	add_child_autofree(host)
	var physics := KernelBulletPhysics.new()
	physics.setup(host)

	var player: Player = PLAYER_SCENE.instantiate()
	player.player_data = FIXTURES.player_data()
	add_child_autofree(player)
	player.global_position = Vector2(448, 640)
	player.is_invincible = false

	var reg := EntityRegistry.new()
	reg.bind_player(player)
	physics.entity_registry = reg
	host.system.set_seed(p_seed)

	var move_right := 1 << PlayerInput.ACTIONS.find("move_right")
	var shoot := 1 << PlayerInput.ACTIONS.find("shoot")
	var hashes: Array[int] = []
	for tick in ticks:
		var mask := replay.mask_at(tick) if replay != null else 0
		if replay == null:
			if tick < 80:
				mask |= move_right
			if tick % 20 < 10:
				mask |= shoot
		PlayerInput.set_override_mask(mask)
		PlayerInput.latch()

		player._physics_process(1.0 / 60.0)
		if tick % 9 == 0:
			var spec := SpawnSpec.new().enemy().tex("小玉")
			spec.velocity = Vector2.DOWN * 180.0
			host.shoot(spec, Vector2(320 + (tick % 5) * 32, 100), Vector2.DOWN)
		host.system.step(1.0 / 60.0)
		physics.process()

		var state_hash := SimHash.of(reg, host.system, tick)
		hashes.append(state_hash)
		if recorder != null:
			recorder.capture_tick(mask, 0, state_hash)

	PlayerInput.clear_override()
	return hashes


func test_600_ticks_minimal_microbench() -> void:
	var started := Time.get_ticks_msec()
	var hashes := _run_once(12345, null, null, 600)
	var elapsed := Time.get_ticks_msec() - started
	assert_eq(hashes.size(), 600)
	assert_lt(elapsed, 5000, "600 tick 最小 microbench 应在 5s 内完成（实测 %d ms；不覆盖 GameScene）" % elapsed)


func test_start_playback_rejects_other_sim_version() -> void:
	var rec := Replay.new()
	rec.begin(60, 111, "other-sim")
	rec.capture_tick(0, 0, 0)
	var path := "user://test_replay_version.json"
	assert_true(rec.save(path))
	assert_false(ReplaySession.start_playback(path), "sim_version 不匹配必须拒绝")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_finish_does_not_overwrite_start_stage() -> void:
	ReplaySession.cancel_recording()
	assert_true(ReplaySession.start_recording({
		"start_stage_id": 1, "start_stage_no": 1, "difficulty": 1, "character": 0,
	}))
	var path := ReplaySession.finish_recording({"result": "game_over", "stage_id": 2, "stage_no": 2})
	assert_ne(path, "")
	var rec := Replay.new()
	assert_true(rec.load_file(path))
	assert_eq(int(rec.metadata.get("start_stage_id", 0)), 1, "结束 stage 不得覆盖起始 stage")
	assert_eq(int(rec.metadata.get("start_stage_no", 0)), 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_dialogue_advance_is_captured_as_command() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	assert_true(ReplaySession.start_recording({"difficulty": 1, "character": 0}))
	ReplaySession.record_dialogue_advance()
	ReplaySession.record_tick(0, 0, 7)
	var path := ReplaySession.finish_recording({"result": "test"})
	var rec := Replay.new()
	assert_true(rec.load_file(path))
	assert_ne(rec.command_at(0) & Replay.COMMAND_DIALOGUE_ADVANCE, 0, "按 Z 推进对话应进命令位")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_finish_recording_can_target_slot_and_name() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	assert_true(ReplaySession.start_recording({"result": "save"}))
	ReplaySession.record_tick(0, 0, 1)
	var path := ReplaySession.DIR + "/slot_test.json"
	var saved := ReplaySession.finish_recording({"slot": 7}, path, "测试录像")
	assert_eq(saved, path, "保存页应能指定槽位路径")
	var rec := Replay.new()
	assert_true(rec.load_file(path))
	assert_eq(str(rec.metadata.get("name", "")), "测试录像", "名字应写入 metadata")
	assert_eq(int(rec.metadata.get("slot", 0)), 7, "槽位号应写入 metadata")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_slot_entries_keep_fixed_slot_numbers() -> void:
	var path_a := ReplaySession.DIR + "/slot_fixed_a.json"
	var path_b := ReplaySession.DIR + "/slot_fixed_b.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ReplaySession.DIR))
	for pair in [[path_a, 22], [path_b, 23]]:
		var rec := Replay.new()
		rec.begin(60, 1, ReplaySession.SIM_VERSION)
		rec.metadata = {"slot": pair[1], "name": "fixed"}
		rec.capture_tick(0, 0, 0)
		assert_true(rec.save(pair[0]))
	var slots := ReplaySession.slot_entries()
	assert_eq(str(slots[21].get("path", "")), path_a, "槽位 22 应保持原位")
	assert_eq(str(slots[22].get("path", "")), path_b, "槽位 23 应保持原位")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_a))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_b))
