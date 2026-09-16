extends GutTest
## 自机诱导弹不该追"还没进入战斗的 Boss"（对话 / 进场期）。
## 机制：Boss 开战前 is_targetable()=false → 目标查询（WorldQuery → 内核）拿不到它。


func test_enemy_is_always_targetable() -> void:
	var enemy := Enemy.new()
	assert_true(enemy.is_targetable(), "杂兵恒为可追目标")
	enemy.free()


func test_boss_not_targetable_before_phase() -> void:
	var boss = load("res://scripts/enemy/boss.gd").new()
	autofree(boss)
	assert_false(boss.is_targetable(), "还没 start_phase → 不是目标")

	var phase := PhaseData.new()
	phase.hp = 5
	phase.time_limit = 10.0
	boss.start_phase(phase)
	assert_true(boss.is_targetable(), "进入阶段后才是目标")


func test_registry_targetables_exclude_pre_battle_boss() -> void:
	var reg := EntityRegistry.new()
	var enemy := Enemy.new()
	var boss = load("res://scripts/enemy/boss.gd").new()
	reg.register_enemy(enemy)
	reg.register_enemy(boss)
	assert_eq(reg.get_active_enemies().size(), 2, "在场表仍含 Boss")
	var targets := reg.get_targetable_enemies()
	assert_eq(targets.size(), 1, "可选目标排除未开战 Boss")
	assert_eq(targets[0], enemy, "留下的应是杂兵")
	enemy.free()
	boss.free()
