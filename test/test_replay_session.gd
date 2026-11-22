extends GutTest
## ReplaySession：一局录制能落盘，并出现在回放列表里。

func before_each() -> void:
	ReplaySession.cancel_run()

func after_each() -> void:
	GameplayClock.reset()
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
	rec.events = [{"frame": 0, "tick": 0, "action": "cancel&bomb"}]
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


func test_engine_tick_events_are_relative_to_recording_start() -> void:
	# 跨进程回放：录制时 Engine 帧号很大，回放时 Engine 帧号很小/更小。
	# 事件必须按「录制内相对 tick」消费，不能因为绝对帧号已过就一开始全部触发。
	var rec := ReplayRecorder.new()
	rec.start()
	rec.start_engine_tick = Engine.get_physics_frames() - 1000
	rec.frames = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	rec.duration_frames = 10
	rec.events = [{
		"frame": 4,
		"tick": 5,
		"engine_tick": rec.start_engine_tick + 5,
		"action": "memory_release",
		"after_sample": false,
	}]
	var path := "user://test_replay_engine_tick.json"
	assert_true(rec.save(path))
	assert_true(ReplaySession.start_playback(path))
	assert_true(ReplaySession.advance_frame())
	assert_eq(ReplaySession.poll_events(), [], "相对第 5 tick 的事件不能在第一帧就触发")
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## GameplayClock 冻结期：GameScene 被树暂停，但回放帧必须继续推进。
## 这是 deathbomb 新时序的关键——时钟走、玩法停。
func test_freeze_keeps_replay_frames_running() -> void:
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray()
	for i in 120:
		rec.frames.append(0)
	rec.duration_frames = 120
	rec.metadata = {"difficulty": 1, "character": 0, "start_stage_id": 1}
	var path := "user://test_replay_freeze_pump.json"
	assert_true(rec.save(path), "写测试回放")
	assert_true(ReplaySession.start_playback(path), "进入回放")

	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(ReplaySession.is_playing(), "回放应仍在进行")
	var before := ReplaySession.current_frame()
	assert_gt(before, 0, "正常帧应推进回放")

	GameplayClock.freeze(self)
	assert_true(get_tree().paused, "冻结应暂停树")
	for i in 5:
		await get_tree().physics_frame
	assert_true(GameplayClock.is_frozen(), "窗口仍冻结")
	assert_gt(ReplaySession.current_frame(), before, "冻结期回放帧也必须推进")

	GameplayClock.unfreeze(self)
	await get_tree().process_frame
	assert_false(get_tree().paused, "解冻应恢复树")
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 新录制按“录制帧 tick”排程，而不是 Engine 帧号：
## 录制中暂停 / 场景切换会让 Engine 帧号与已录帧数拉开空隙，用 Engine 帧会把事件整体推迟。
func test_clock_freeze_events_follow_recorded_tick_not_engine_gap() -> void:
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray()
	for i in 10:
		rec.frames.append(0)
	rec.duration_frames = 10
	rec.start_engine_tick = Engine.get_physics_frames() - 500
	rec.events = [{
		"frame": 4,
		"tick": 5,
		"engine_tick": rec.start_engine_tick + 2000,
		"action": "memory_release",
		"after_sample": false,
	}]
	var path := "user://test_replay_tick_gap.json"
	assert_true(rec.save(path), "写测试回放")
	assert_true(ReplaySession.start_playback(path), "进入回放")
	for i in 5:
		assert_true(ReplaySession.advance_frame(), "推进第 %d 帧" % (i + 1))
	assert_eq(ReplaySession.poll_events(), [&"memory_release"], "事件应按 tick=5 到点，不被 Engine 空隙推迟")
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 对话推进也按录制帧排程：Engine 空隙不能把对话推进提前消费完。
func test_clock_freeze_dialogue_advance_follows_recorded_frame() -> void:
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray()
	for i in 10:
		rec.frames.append(0)
	rec.duration_frames = 10
	rec.start_engine_tick = Engine.get_physics_frames() - 500
	rec.dialogue_advances = [{
		"engine_tick": rec.start_engine_tick + 2000,
		"frame": 4,
	}]
	var path := "user://test_replay_dialogue_frame.json"
	assert_true(rec.save(path), "写测试回放")
	assert_true(ReplaySession.start_playback(path), "进入回放")
	for i in 3:
		ReplaySession.advance_frame()
	assert_false(ReplaySession.poll_dialogue_advance(), "第 4 帧之前不消费")
	ReplaySession.advance_frame()
	assert_true(ReplaySession.poll_dialogue_advance(), "到第 4 帧消费")
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_replay_menu_builds_list() -> void:
	var menu = load("res://scenes/ui/replay_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu.on_enter()
	assert_not_null(menu.get_node_or_null("ReplayBox"), "回放页应生成列表容器")

class ProcessProbe extends Node:
	var ticks: int = 0
	func _process(_delta: float) -> void:
		ticks += 1

func test_process_runs_at_zero_time_scale() -> void:
	var p := ProcessProbe.new()
	add_child_autofree(p)
	Engine.time_scale = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	Engine.time_scale = 1.0
	assert_gt(p.ticks, 0, "time_scale=0 时 _process 仍应运行（deathbomb 事件轮询依赖它）")

class PhysicsProbe extends Node:
	var ticks: int = 0
	func _physics_process(_delta: float) -> void:
		ticks += 1

func test_physics_runs_at_zero_time_scale() -> void:
	var p := PhysicsProbe.new()
	add_child_autofree(p)
	Engine.time_scale = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	Engine.time_scale = 1.0
	print("physics ticks at zero time_scale: ", p.ticks)
	assert_gt(p.ticks, 0, "time_scale=0 时 _physics_process 仍应运行")


func test_deathbomb_event_is_not_consumed_early() -> void:
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray([0, 0, 0])
	rec.duration_frames = 3
	rec.events = [{"frame": 1, "tick": 1, "action": "cancel&bomb"}]
	var path := "user://test_replay_deathbomb.json"
	assert_true(rec.save(path))
	assert_true(ReplaySession.start_playback(path))
	assert_eq(ReplaySession.poll_events(), [], "事件必须按录制帧号准时消费")
	assert_true(ReplaySession.advance_frame())
	assert_eq(ReplaySession.poll_events(), [&"cancel&bomb"])
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_far_future_bomb_is_not_consumed_early() -> void:
	var rec := ReplayRecorder.new()
	rec.start()
	rec.frames = PackedByteArray([0, 0, 0])
	rec.duration_frames = 3
	rec.events = [{"frame": 2, "tick": 2, "action": "cancel&bomb"}]
	var path := "user://test_replay_far_bomb.json"
	assert_true(rec.save(path))
	assert_true(ReplaySession.start_playback(path))
	assert_eq(ReplaySession.poll_events(), [], "未来 bomb 不能提前消费")
	ReplaySession.stop_playback()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_delete_replay_only_in_replay_dir() -> void:
	var path := ReplaySession.DIR + "/test_delete_me.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f)
	if f != null:
		f.store_string("{}")
	assert_true(ReplaySession.delete_replay(path), "应能删除回放目录内文件")
	assert_false(FileAccess.file_exists(path))
	assert_false(ReplaySession.delete_replay("/tmp/not_a_replay.json"), "目录外文件必须拒绝")


func test_replay_menu_rebuild_does_not_accumulate_nodes() -> void:
	var menu = load("res://scenes/ui/replay_menu.tscn").instantiate()
	add_child_autofree(menu)
	menu._show_replays()
	menu._show_replays()
	var boxes := 0
	var hints := 0
	for child in menu.get_children():
		if str(child.name).begins_with("ReplayBox"):
			boxes += 1
		if str(child.name).begins_with("HintLabel"):
			hints += 1
	assert_eq(boxes, 1, "重建列表后只应保留一个 ReplayBox")
	assert_eq(hints, 1, "重建列表后只应保留一个 HintLabel")
