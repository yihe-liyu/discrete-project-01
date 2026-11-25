extends GutTest
## GameScene 接入：普通局自动开录，tick 钩子写入 Replay，能落盘并读回。

const GAME_SCENE = preload("res://scenes/game_scene.tscn")


func before_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	ReplaySession.debug_capture = false
	ReplaySession.debug_snapshots.clear()
	SimClock.reset()
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	SaveData.reset_session()
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0


func after_each() -> void:
	ReplaySession.cancel_recording()
	ReplaySession.stop_playback()
	ReplaySession.debug_capture = false
	ReplaySession.debug_snapshots.clear()
	SimClock.reset()
	SaveData.reset_session()


func test_normal_run_records_ticks_and_saves_v2_file() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 200:
		await get_tree().physics_frame

	assert_true(ReplaySession.is_recording(), "普通局应自动开录")
	assert_gt(ReplaySession.replay_tick_count(), 0, "应已录到 tick")

	var path := ReplaySession.finish_recording({"result": "test"})
	assert_ne(path, "", "结束录制应落盘")
	assert_true(FileAccess.file_exists(path), "回放文件应存在")
	var rec := Replay.new()
	assert_true(rec.load_file(path), "新文件应能被 v2 读取")
	assert_gt(rec.tick_count(), 0, "回放应至少有一个 tick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_recorded_run_playback_matches_hashes() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 300:
		await get_tree().physics_frame
	var path := ReplaySession.finish_recording({"result": "test"})
	assert_ne(path, "", "录制应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplaySession.start_playback(path), "应能进入回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 200:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_playing(), "回放应还在进行")
	assert_false(ReplaySession.has_diverged(), "回放前几 tick 不应出现哈希分歧")
	ReplaySession.stop_playback()
	ReplaySession.debug_capture = false
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_bomb_command_is_recorded_and_replayed() -> void:
	ReplaySession.debug_capture = true
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 20:
		await get_tree().physics_frame
	PlayerInput.queue_command(&"bomb")
	for _i in 280:
		await get_tree().physics_frame
	var path := ReplaySession.finish_recording({"result": "test"})
	assert_ne(path, "", "bomb 局应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplaySession.start_playback(path), "bomb 局应能回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 300:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_playing(), "bomb 回放应还在进行")
	assert_false(ReplaySession.has_diverged(), "bomb 命令回放不应出现哈希分歧")
	ReplaySession.stop_playback()
	ReplaySession.debug_capture = false
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
	var path := ReplaySession.finish_recording({"result": "test"})
	assert_ne(path, "", "跨面起点也应落盘")

	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplaySession.start_playback(path), "跨面起点应能回放")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 20:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_playing(), "跨面起点回放应还在进行")
	assert_false(ReplaySession.has_diverged(), "跨面起点第一帧不应分歧")
	ReplaySession.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 单关练习：录制应带 practice_mode=stage；回放必须恢复单关练习态。
func test_stage_practice_records_and_plays_back() -> void:
	SaveData.is_stage_practice = true
	SaveData.current_stage_id = 1
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 120:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_recording(), "单关练习也应开录")
	var path := ReplaySession.finish_recording({"result": "test"})
	var rec := Replay.new()
	assert_true(rec.load_file(path))
	assert_eq(str(rec.metadata.get("practice_mode", "")), "stage", "应记录单关练习模式")
	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplaySession.start_playback(path), "单关练习录像应能回放")
	assert_true(ReplaySession.is_practice_playback(), "回放应标记为练习")
	assert_true(SaveData.is_stage_practice, "回放应恢复单关练习标志")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 60:
		await get_tree().physics_frame
	assert_false(ReplaySession.has_diverged(), "单关练习前 60 tick 不应分歧")
	ReplaySession.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 符卡练习：录制 / 回放都必须恢复同一个 phase。
func test_spell_practice_records_and_plays_back() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var phase := BossCatalog.phase_at(1, 0, 1)
	var boss := BossCatalog.boss_of_phase(1, 0)
	assert_not_null(phase)
	assert_not_null(boss)
	PracticeSession.start(phase, boss.visual, boss.boss_name, 1, 0, boss.spell_background,
		BossCatalog.practice_bgm_key(boss, 1))
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 120:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_recording(), "符卡练习也应开录")
	var path := ReplaySession.finish_recording({"result": "test"})
	var rec := Replay.new()
	assert_true(rec.load_file(path))
	assert_eq(str(rec.metadata.get("practice_mode", "")), "spell", "应记录符卡练习模式")
	assert_eq(int(rec.metadata.get("practice_phase_index", -1)), 0)
	scene.queue_free()
	await get_tree().process_frame

	assert_true(ReplaySession.start_playback(path), "符卡练习录像应能回放")
	assert_true(ReplaySession.is_practice_playback(), "回放应标记为符卡练习")
	assert_true(PracticeSession.is_practice_mode, "回放应恢复符卡练习载荷")
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 60:
		await get_tree().physics_frame
	assert_false(ReplaySession.has_diverged(), "符卡练习前 60 tick 不应分歧")
	ReplaySession.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 符卡练习 Boss 击破：先播正常流程的全破演出，再弹结果页；结果页前不能自动落盘。
func test_spell_practice_boss_defeat_waits_for_effect_then_result() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var phase := BossCatalog.phase_at(1, 0, 1)
	var boss_data := BossCatalog.boss_of_phase(1, 0)
	PracticeSession.start(phase, boss_data.visual, boss_data.boss_name, 1, 0,
		boss_data.spell_background, BossCatalog.practice_bgm_key(boss_data, 1))
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 20:
		await get_tree().physics_frame
	var runtime = scene.get_node("%StageRuntime")
	var enemies: Array = runtime.entity_registry.get_active_enemies()
	assert_gt(enemies.size(), 0, "练习 Boss 应已生成")
	var boss = enemies[0]
	boss.phase_cleared.emit(true, 0)
	assert_true(ReplaySession.is_recording(), "击破后结果页出现前不应自动落盘")
	for _i in 140:
		await get_tree().physics_frame
	assert_true(GameManager.has_open_overlay(), "演出结束后应弹出结果页")
	assert_true(ReplaySession.is_recording(), "结果页不能自动结束录像")
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 64:
			for page in child.get_children():
				if page is BasePage:
					GameManager.pop_overlay_menu(page)
	get_tree().paused = false
	GameManager.current_state = GameManager.AppState.MENU
	SimClock.reset()


## 回放自然播完后应停在结束页，而不是直接切场景。
func test_replay_natural_end_shows_end_page() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 10:
		await get_tree().physics_frame
	var path := ReplaySession.finish_recording({"result": "test"})
	assert_ne(path, "")
	scene.queue_free()
	await get_tree().process_frame
	assert_true(ReplaySession.start_playback(path))
	var playback: Node = GAME_SCENE.instantiate()
	add_child_autofree(playback)
	for _i in 30:
		await get_tree().physics_frame
	assert_true(ReplaySession.is_playing(), "结束页出现前录像会话不应被清")
	assert_true(GameManager.has_open_overlay(), "回放播完应弹出结束页")
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 64:
			for page in child.get_children():
				if page is BasePage:
					GameManager.pop_overlay_menu(page)
	get_tree().paused = false
	GameManager.current_state = GameManager.AppState.MENU
	ReplaySession.stop_playback()
	playback.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 练习模式失败（死亡）应弹出练习失败页，而不是普通 Game Over；录像保留到用户选择。
func test_practice_failure_shows_fail_menu() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var phase := BossCatalog.phase_at(1, 0, 1)
	var boss_data := BossCatalog.boss_of_phase(1, 0)
	PracticeSession.start(phase, boss_data.visual, boss_data.boss_name, 1, 0,
		boss_data.spell_background, BossCatalog.practice_bgm_key(boss_data, 1))
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 10:
		await get_tree().physics_frame
	GameEvents.player_death.emit()
	for _i in 120:
		await get_tree().physics_frame
	assert_true(GameManager.has_open_overlay(), "练习失败应弹失败页")
	assert_true(ReplaySession.is_recording(), "失败页出现时录像不应被自动结束")
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 64:
			for page in child.get_children():
				if page is BasePage:
					GameManager.pop_overlay_menu(page)
	get_tree().paused = false
	GameManager.current_state = GameManager.AppState.MENU
	ReplaySession.cancel_recording()
	SimClock.reset()


func _overlay_page_named(node_name: String) -> Node:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 64:
			for page in child.get_children():
				if page.name == node_name:
					return page
	return null


## 失败页 → 保存页 → X 返回后必须能再次进入保存页。
func test_practice_fail_save_cancel_can_reopen() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var phase := BossCatalog.phase_at(1, 0, 1)
	var boss_data := BossCatalog.boss_of_phase(1, 0)
	PracticeSession.start(phase, boss_data.visual, boss_data.boss_name, 1, 0,
		boss_data.spell_background, BossCatalog.practice_bgm_key(boss_data, 1))
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 10:
		await get_tree().physics_frame
	GameEvents.player_death.emit()
	for _i in 120:
		await get_tree().physics_frame
	var fail_page: Node = _overlay_page_named("PracticeFailMenu")
	assert_not_null(fail_page, "失败页应打开")
	fail_page.finished.emit({"action": "save"})
	await get_tree().process_frame
	await get_tree().process_frame
	var save_page: Node = _overlay_page_named("PauseReplaySave")
	assert_not_null(save_page, "保存页应打开")
	save_page.go_back()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(fail_page.visible, "X 返回后失败页应恢复可见")
	fail_page.finished.emit({"action": "save"})
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(_overlay_page_named("PauseReplaySave"), "返回后应能再次进入保存页")
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer == 64:
			for page in child.get_children():
				if page is BasePage:
					GameManager.pop_overlay_menu(page)
	get_tree().paused = false
	GameManager.current_state = GameManager.AppState.MENU
	ReplaySession.cancel_recording()
	SimClock.reset()


## 失败页按“返回标题菜单”必须切回标题，不能先恢复游戏继续跑。
func test_practice_fail_return_goes_to_title() -> void:
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var phase := BossCatalog.phase_at(1, 0, 1)
	var boss_data := BossCatalog.boss_of_phase(1, 0)
	PracticeSession.start(phase, boss_data.visual, boss_data.boss_name, 1, 0,
		boss_data.spell_background, BossCatalog.practice_bgm_key(boss_data, 1))
	var scene: Node = GAME_SCENE.instantiate()
	add_child_autofree(scene)
	for _i in 10:
		await get_tree().physics_frame
	GameEvents.player_death.emit()
	for _i in 120:
		await get_tree().physics_frame
	var fail_page: Node = _overlay_page_named("PracticeFailMenu")
	assert_not_null(fail_page)
	fail_page.finished.emit({"action": "return"})
	await get_tree().create_timer(1.20, true).timeout
	assert_eq(GameManager.current_state, GameManager.AppState.MENU, "应回到标题菜单状态")
	assert_true(GameManager.current_scene_path.ends_with("main_menu.tscn"), "应切回标题场景")


## 切场景后 HUD 应复用同一个实例，而不是跟着 GameScene 重建。
func test_hud_survives_game_scene_rebuild() -> void:
	var first: Node = GAME_SCENE.instantiate()
	add_child_autofree(first)
	for _i in 10:
		await get_tree().physics_frame
	var hud: GameUI = HudLayer.get_game_ui()
	assert_not_null(hud, "进游戏后应收养 HUD")
	first.queue_free()
	await get_tree().process_frame
	var second: Node = GAME_SCENE.instantiate()
	add_child_autofree(second)
	for _i in 10:
		await get_tree().physics_frame
	assert_eq(HudLayer.get_game_ui(), hud, "切场景后 HUD 实例应保持不变")
	assert_true(hud.is_inside_tree(), "持久 HUD 应仍在树里")
	assert_true(hud.visible, "游戏场景里 HUD 应可见")
	second.queue_free()
	await get_tree().process_frame
