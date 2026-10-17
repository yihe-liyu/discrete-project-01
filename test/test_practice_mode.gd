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
	SaveData.is_restarting = false
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
	SaveData.is_restarting = false
	PracticeSession.start(PhaseData.new(), null, "测试", 1, 0)
	SaveData.reset_all(null)
	assert_false(PracticeSession.is_practice_mode, "reset_all 应复位练习模式")
	assert_null(PracticeSession.phase, "reset_all 应清空 practice_phase")


## 练习 BGM key 随载荷走（菜单按选中的卡解析后传进来），结束时要清干净
func test_practice_bgm_key_travels_with_payload_and_clears():
	SaveData.is_restarting = false
	PracticeSession.start(PhaseData.new(), null, "测试", 9, 0, null, "stageEX_boss")
	assert_eq(PracticeSession.bgm_key, "stageEX_boss", "载荷应带上本局 BGM key")
	PracticeSession.finish()
	assert_eq(PracticeSession.bgm_key, "", "结束练习应清空 BGM key（防残留到下一局）")


# ═══ 关卡练习：起始火力（第 1 面例外，其余拉满）═══

func after_each() -> void:
	# 全是全局静态状态 ⇒ 必须还原，别漏给后面的用例
	SaveData.is_stage_practice = false
	SaveData.current_stage_id = 1
	PracticeSession.finish()


## 纯判定：关卡练习 + 面 ≥ 2 ⇒ 满火力；第 1 面 / 非练习 ⇒ 不拉满
func test_practice_full_power_rule():
	SaveData.is_stage_practice = true
	SaveData.current_stage_id = 1
	assert_false(SaveData.practice_starts_at_full_power(), "第 1 面按正常 1.00 起步（不拉满）")
	SaveData.current_stage_id = 2
	assert_true(SaveData.practice_starts_at_full_power(), "第 2 面起应从满火力开始")
	SaveData.is_stage_practice = false
	SaveData.current_stage_id = 2
	assert_false(SaveData.practice_starts_at_full_power(), "**普通流程**第 2 面也不拉满（只影响练习）")


## 端到端：关卡练习第 2 面 ⇒ 真场景里自机火力 = 满
func test_stage_practice_stage_two_starts_at_full_power():
	var res: PlayerResources = await _boot_stage_play(2, true)
	assert_not_null(res, "应有自机资源")
	if res:
		assert_eq(res.power_raw, PlayerResources.MAX_POWER_RAW,
			"第 2 面练习应从**满火力**开始（练后面几面不该还从 1.00 攒）")


## 端到端：第 1 面是例外 ⇒ 仍按正常 1.00 起步
func test_stage_practice_stage_one_keeps_normal_power():
	var res: PlayerResources = await _boot_stage_play(1, true)
	if res:
		assert_eq(res.power_raw, 0, "第 1 面练习仍按正常 1.00 起步")


## 起一局**关卡玩法**（`is_stage_practice` 控制是不是练习）并取自机资源
func _boot_stage_play(stage_id: int, stage_practice: bool) -> PlayerResources:
	PracticeSession.finish()                 # 关卡玩法不是符卡练习
	SaveData.is_stage_practice = stage_practice
	SaveData.current_stage_id = stage_id
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	var inst: Node = load("res://scenes/game_scene.tscn").instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var rt: StageRuntime = inst.get_node("World/StageRuntime")
	return rt.entity_registry.get_player_resources()
