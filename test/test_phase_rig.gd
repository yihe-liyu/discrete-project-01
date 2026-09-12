extends GutTest
## 阶段组合台（M4）测试：壳副本 / 双槽默认 / 开演真实生成

const SHELL := preload("res://scripts/workbench/phase_shell.gd")
const RIG := preload("res://scripts/workbench/phase_bench.gd")




func test_phase_shell_copy_does_not_mutate_base():
	var base := PhaseData.new()
	base.name = "测试符"
	base.uid = 77
	base.hp = 1234
	base.time_limit = 45.0
	base.bonus = 99
	base.params = {"a": 1}
	var mv := load("res://data/stages/stage01/phase/non_mid01/non_mid01_move.gd")
	var sh := load("res://data/stages/stage01/phase/non_mid01/non_mid01_shoot.gd")
	var s = SHELL.new()
	var d: PhaseData = s.build_copy(base, mv, sh, 2000.0, 20.0)
	assert_eq(d.hp, 2000, "HP 覆盖")
	assert_eq(d.time_limit, 20.0, "时限覆盖")
	assert_eq(d.uid, 77, "uid 保留")
	assert_eq(d.move_script, mv, "move 槽")
	assert_eq(d.shoot_script, sh, "shoot 槽")
	assert_eq(d.bonus, 99, "bonus 保留")
	assert_eq(d.params.get("a", 0), 1, "params 复制（独立字典）")
	assert_eq(base.hp, 1234, "原资源未被修改")
	assert_eq(base.time_limit, 45.0, "原时限未被修改")


func test_phase_rig_select_defaults_from_tres():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	# 找"道中非符1"在目录里的下标（顺序来自扫描，不写死）
	var phases = rig._catalog.by_role("phase")
	var idx := -1
	for i in phases.size():
		if phases[i].path.ends_with("non_mid01.tres"):
			idx = i
	assert_true(idx >= 0, "目录含 non_mid01")
	if idx < 0:
		return
	rig._select_phase(idx)
	var p: PhaseData = load("res://data/stages/stage01/phase/non_mid01/non_mid01.tres")
	assert_eq(rig._hp_spin.value, float(p.hp), "HP 默认=阶段值")
	assert_eq(rig._time_spin.value, p.time_limit, "时限默认=阶段值")
	assert_true(rig._move_sel.selected > 0, "move 槽默认选中")
	assert_true(rig._shoot_sel.selected > 0, "shoot 槽默认选中")
	assert_eq(rig._move_path, "res://data/stages/stage01/phase/non_mid01/non_mid01_move.gd", "move 路径")
	# 清空 shoot 槽 → 解析为 null
	rig._shoot_sel.selected = 0
	assert_null(rig._resolve_slot(rig._shoot_sel, "boss_shoot"), "空槽=不发射")
	rig.queue_free()



func test_dual_param_panels_for_slots():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	# 选 spell053（试符：move=random_dir_move, shoot=orbit_spiral）
	var phases = rig._catalog.by_role("phase")
	var idx := -1
	for i in phases.size():
		if phases[i].path.ends_with("spell053.tres"):
			idx = i
	assert_true(idx >= 0, "目录含 spell053")
	if idx < 0:
		return
	rig._select_phase(idx)
	# shoot 面板枚举出 orbit_spiral 的参数（orbit_speed 等）
	var shoot_rows = rig._shoot_params.get_rows()
	var found_speed := false
	for row in shoot_rows:
		if row.name == "orbit_speed":
			found_speed = true
			row.ctrl.value = 20.0
	assert_true(found_speed, "弹幕槽参数面板含 orbit_speed（%d 行）" % shoot_rows.size())
	# move 面板（random_dir_move）也应有行
	var move_rows = rig._move_params.get_rows()
	assert_true(move_rows.size() >= 1, "移动槽参数面板有行（%d）" % move_rows.size())
	# 合并收集
	var merged := {}
	merged.merge(rig._move_params.collect())
	merged.merge(rig._shoot_params.collect())
	assert_eq(merged.get("orbit_speed", 0.0), 20.0, "合并后 shoot 参数生效")
	rig.queue_free()

func test_phase_rig_play_spawns_boss():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	var phases = rig._catalog.by_role("phase")
	var idx := -1
	for i in phases.size():
		if phases[i].path.ends_with("non_mid01.tres"):
			idx = i
	rig._select_phase(idx)
	rig._boss_pos = Vector2(GameConfig.FIELD_CENTER_X, 250.0)
	GameState.active_enemies.clear()
	rig._play()
	assert_true(GameState.get_active_enemies().size() >= 1,
		"开演生成 Boss（%d）" % GameState.get_active_enemies().size())
	rig._clear_all()
	rig.queue_free()