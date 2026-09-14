extends GutTest
## 练习模式：残机/bomb 归零、火力拉满（reset_practice 必须在自机绑定后生效）

func test_practice_mode_zeroes_lives_and_bombs():
	var phase: PhaseData = BossCatalog.phase_at(1, 0, 1)
	var boss: BossData = BossCatalog.boss_of_phase(1, 0)
	if phase == null or boss == null:
		pending("stage1 phase0 无 boss 数据")
		return
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	PracticeSession.start(phase, boss.visual, boss.boss_name, 1, 0)

	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var rt: StageRuntime = inst.get_node("World/StageRuntime")
	var res: PlayerResources = rt.entity_registry.get_player_resources()
	assert_not_null(res, "练习应有自机资源")
	if res:
		assert_eq(res.lives, 0, "练习残机应为 0")
		assert_eq(res.bomb_count, 0, "练习 bomb 应为 0")
		assert_eq(res.power_raw, 300, "练习火力应为满(300)")
	PracticeSession.finish()


## 回归：练习结束必须清空载荷——否则「先打练习，再进普通流程」会看到残留 practice_phase
## （game_scene 告警「practice_phase 已设置但 is_practice_mode=false」并误判）。
func test_end_practice_clears_payload():
	SaveData.restarting = false
	PracticeSession.start(PhaseData.new(), null, "测试", 1, 0)
	assert_true(PracticeSession.is_practice_mode, "start_practice 应置位练习模式")
	PracticeSession.finish()
	assert_false(PracticeSession.is_practice_mode, "end_practice 应复位练习模式")
	assert_null(PracticeSession.phase, "end_practice 应清空 practice_phase")
	assert_null(PracticeSession.boss_scene, "应清空 practice_boss_scene")
	assert_eq(PracticeSession.boss_name, "", "应清空 practice_name")
	assert_eq(PracticeSession.stage_id, 1, "应复位 practice_stage_id")
	assert_eq(PracticeSession.phase_index, 0, "应复位 practice_phase_index")
	assert_null(PracticeSession.background, "应清空 practice_background")


## 回归：reset_all（普通开局 / 重开）也应自愈清掉练习载荷。
func test_reset_all_clears_practice_payload():
	SaveData.restarting = false
	PracticeSession.start(PhaseData.new(), null, "测试", 1, 0)
	SaveData.reset_all(null)
	assert_false(PracticeSession.is_practice_mode, "reset_all 应复位练习模式")
	assert_null(PracticeSession.phase, "reset_all 应清空 practice_phase")
