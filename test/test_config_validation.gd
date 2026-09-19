extends GutTest
## 配置校验层测试

func test_phase_data_valid_ok():
	var pd := PhaseData.new()
	pd.name = "正常符"
	pd.time_limit = 30.0
	pd.hp = 1000
	pd.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	assert_eq(pd.validate(), [], "合法 PhaseData 应无错误")

func test_phase_time_limit_zero_caught():
	var pd := PhaseData.new()
	pd.name = "坏符"
	pd.time_limit = 0.0  # 除零风险
	pd.hp = 1000
	pd.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	var errs := pd.validate()
	assert_true(not errs.is_empty(), "time_limit=0 应报错")
	assert_eq(errs.filter(func(e): return e.contains("time_limit")).size(), 1, "应报 time_limit 错误")

func test_phase_hp_zero_caught():
	var pd := PhaseData.new()
	pd.time_limit = 30.0
	pd.hp = 0
	pd.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	assert_true(not pd.validate().is_empty(), "hp=0 应报错")

func test_phase_no_scripts_ok():
	# 纯移动/演示阶段可以无脚本（不校验脚本）
	var pd := PhaseData.new()
	pd.time_limit = 30.0
	pd.hp = 1000
	assert_eq(pd.validate(), [], "无脚本的合法数值阶段应无错误")

func test_stage_data_validation():
	var stage_data := StageData.new()
	stage_data.stage_id = 1
	stage_data.create_script = load("res://scripts/coroutine/timeline/timeline.gd")
	assert_eq(stage_data.validate(), [], "合法 StageData 应无错误")
	var bad := StageData.new()
	bad.stage_id = 0
	bad.create_script = null
	assert_true(not bad.validate().is_empty(), "stage_id=0 + 无脚本应报错")

func test_stage_registry_duplicate_caught():
	var reg := StageRegistry.new()
	var s1 := StageData.new()
	s1.stage_id = 1
	s1.create_script = load("res://scripts/coroutine/timeline/timeline.gd")
	var s2 := StageData.new()
	s2.stage_id = 1  # 重复
	s2.create_script = load("res://scripts/coroutine/timeline/timeline.gd")
	reg.stages = [s1, s2]
	var errs := reg.validate()
	assert_eq(errs.filter(func(e): return e.contains("重复")).size(), 1, "重复 stage_id 应报错")

func test_boss_data_validates_phases():
	var bd := BossData.new()
	var bad := PhaseData.new()
	bad.time_limit = 0.0
	bad.hp = 500
	bad.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	bd.phases_normal = [bad]
	var errs := bd.validate()
	assert_true(not errs.is_empty(), "含非法 phase 的 Boss 应报错")
