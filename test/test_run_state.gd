extends GutTest
## 路线切面：自机资源快照跨场景继承；单关练习 / 新开一局仍然全套复位。

func after_each() -> void:
	SaveData.clear_run_state()
	SaveData.is_restarting = false
	SaveData.is_stage_practice = false
	SaveData.save_mgr.high_scores.clear()
	PracticeSession.finish()

func _stage_runtime(stage_id: int = 99) -> StageRuntime:
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	var world := Node2D.new()
	add_child_autofree(world)
	rt.world = world
	var holder := Node2D.new()
	add_child_autofree(holder)
	rt.entity_registry.bind_player(StageHost.make_player(
		holder, preload("res://scripts/debug/ghost_player.gd"), "Player",
		preload("res://data/player_data/reimu_data.tres")))
	var data := StageData.new()
	data.stage_id = stage_id
	data.create_script = CoroutineScript
	rt.load_stage(data)
	return rt

func _full_resources() -> PlayerResources:
	var r := PlayerResources.new()
	r.reset_all()
	r.current_score = 12345
	r.max_point = 20000
	r.graze_count = 42
	r.power_raw = 200
	r.lives = 4
	r.life_fragments = 2
	r.bomb_count = 5
	r.bomb_fragments = 1
	r.memory_value = 77.0
	return r

func test_capture_and_apply_roundtrip() -> void:
	var a := _full_resources()
	SaveData.capture_run_state(a)
	var b := PlayerResources.new()
	b.reset_all()
	assert_true(SaveData.apply_run_state(b), "有快照时应恢复")
	assert_eq(b.current_score, a.current_score)
	assert_eq(b.max_point, a.max_point)
	assert_eq(b.graze_count, a.graze_count)
	assert_eq(b.power_raw, a.power_raw)
	assert_eq(b.lives, a.lives)
	assert_eq(b.life_fragments, a.life_fragments)
	assert_eq(b.bomb_count, a.bomb_count)
	assert_eq(b.bomb_fragments, a.bomb_fragments)
	assert_eq(b.memory_value, a.memory_value)

func test_reset_all_clears_carried_state() -> void:
	SaveData.capture_run_state(_full_resources())
	SaveData.reset_all(null)
	assert_true(SaveData.run_state.is_empty(), "reset_all 应清掉跨面快照")
	assert_false(SaveData.apply_run_state(PlayerResources.new()), "清掉后不能恢复")

func test_stage_load_does_not_reset_player_resources() -> void:
	var rt := _stage_runtime()
	var res := rt.entity_registry.get_player_resources()
	res.reset_all()
	res.current_score = 777
	res.lives = 5
	assert_eq(res.current_score, 777, "load_stage 不应重置整局分数")
	assert_eq(res.lives, 5, "load_stage 不应重置残机")


func test_normal_finish_writes_run_high_score_key_zero() -> void:
	var rt := _stage_runtime(99)
	var res := rt.entity_registry.get_player_resources()
	res.current_score = 1234
	rt.finish_stage()
	assert_eq(SaveData.get_high_score(0), 1234, "正常路线高分写 run key 0")
	assert_eq(SaveData.get_high_score(99), 0, "正常路线不污染单关高分")


func test_stage_practice_finish_writes_stage_high_score() -> void:
	SaveData.is_stage_practice = true
	var rt := _stage_runtime(99)
	var res := rt.entity_registry.get_player_resources()
	res.current_score = 555
	rt.finish_stage()
	assert_eq(SaveData.get_high_score(99), 555, "关卡练习高分写本面 key")
	assert_eq(SaveData.get_high_score(0), 0, "关卡练习不写 run 高分")
