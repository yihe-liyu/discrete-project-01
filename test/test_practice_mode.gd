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
	SaveData.start_practice(phase, boss.visual, boss.boss_name, 1, 0)

	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var res: PlayerResources = EntityRegistry.current.get_player_resources()
	assert_not_null(res, "练习应有自机资源")
	if res:
		assert_eq(res.lives, 0, "练习残机应为 0")
		assert_eq(res.bomb_count, 0, "练习 bomb 应为 0")
		assert_eq(res.power_raw, 300, "练习火力应为满(300)")
	SaveData.end_practice()
