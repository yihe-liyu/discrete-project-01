extends GutTest
## 阶段组合台测试：壳副本 / 双槽默认 / 开演真实生成

const SHELL := preload("res://scripts/workbench/phase_shell.gd")
const RIG := preload("res://scripts/workbench/phase_bench.gd")
const PARAM_PANEL := preload("res://scripts/workbench/param_panel.gd")




func test_phase_shell_copy_does_not_mutate_base():
	var base := PhaseData.new()
	base.name = "测试符"
	base.uid = 77
	base.hp = 1234
	base.time_limit = 45.0
	base.bonus = 99
	base.params = {"a": 1}
	var mv := preload("res://test/fixtures/lifecycle_port_behavior.gd")
	var sh := preload("res://test/fixtures/no_port_behavior.gd")
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


## 取目录里**第一张同时带 move+shoot 的阶段**下标。
## ⚠️ 不写死路径/文件名 —— 内容改名、重排、增删都不该让**机制**测试红（那是内容校验测试的活）。
func _pick_phase(rig, need_scripts: bool = true) -> int:
	var phases = rig._catalog.by_role("phase")
	for i in phases.size():
		if not need_scripts:
			return i
		var p: PhaseData = load(phases[i].path)
		if p != null and p.move_script != null and p.shoot_script != null:
			return i
	return -1


func test_phase_rig_select_defaults_from_tres():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	var idx := _pick_phase(rig, true)
	assert_true(idx >= 0, "目录里应有同时带 move+shoot 的阶段")
	if idx < 0:
		rig.queue_free()
		return
	rig._select_phase(idx)
	var p: PhaseData = load(rig._catalog.by_role("phase")[idx].path)
	assert_eq(rig._hp_spin.value, float(p.hp), "HP 默认=阶段值")
	assert_eq(rig._time_spin.value, p.time_limit, "时限默认=阶段值")
	assert_true(rig._move_sel.selected > 0, "move 槽默认选中")
	assert_true(rig._shoot_sel.selected > 0, "shoot 槽默认选中")
	assert_eq(rig._move_path, (p.move_script as Script).resource_path, "move 路径 = 该阶段自己引用的脚本")
	# 清空 shoot 槽 → 解析为 null
	rig._shoot_sel.selected = 0
	assert_null(rig._resolve_slot(rig._shoot_sel, "boss_shoot"), "空槽=不发射")
	rig.queue_free()


func test_phase_bench_drops_script_param_panels():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	# 任选一张阶段即可：本用例只验「阶段台不再挂脚本改参数面板」
	var idx := _pick_phase(rig, false)
	assert_true(idx >= 0, "目录里应有阶段")
	if idx < 0:
		rig.queue_free()
		return
	rig._select_phase(idx)
	assert_false(rig.has_method("_rebuild_param_panels"), "阶段台已移除参数面板接口")
	assert_eq(_find_param_panels(rig).size(), 0, "阶段台 UI 不再挂载脚本改参数面板")
	rig.queue_free()


func test_phase_rig_play_spawns_boss():
	var rig = RIG.new()
	add_child_autofree(rig)
	await get_tree().process_frame
	var idx := _pick_phase(rig, true)
	assert_true(idx >= 0, "目录里应有阶段")
	if idx < 0:
		rig.queue_free()
		return
	rig._select_phase(idx)
	rig._boss_pos = Vector2(GameConfig.FIELD_CENTER_X, 250.0)
	rig._stage_runtime.entity_registry.enemies.clear()
	rig._play()
	assert_true(rig._stage_runtime.entity_registry.get_active_enemies().size() >= 1,
		"开演生成 Boss（%d）" % rig._stage_runtime.entity_registry.get_active_enemies().size())
	rig._clear_all()
	rig.queue_free()


## 递归找 param_panel.gd 实例（回归守卫：阶段台不应再有脚本改参数 UI）
func _find_param_panels(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for c in n.get_children():
		if c.get_script() == PARAM_PANEL:
			out.append(c)
		out.append_array(_find_param_panels(c))
	return out
