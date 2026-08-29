extends GutTest
## 小数伤害累积器测试

func test_enemy_fractional_damage_accumulates():
	var enemy = load("res://scenes/enemy.tscn").instantiate()
	autofree(enemy)
	enemy.enemy_data = EnemyData.new()
	enemy._apply_enemy_data(enemy.enemy_data)
	enemy.max_hp = 3
	enemy.hp = 3
	# 0.5 伤害 × 2 = 1 血
	enemy.take_damage(0.5)
	assert_eq(enemy.hp, 3, "0.5 伤害不足 1，不应扣血")
	enemy.take_damage(0.5)
	assert_eq(enemy.hp, 2, "两次 0.5 累积 = 1 血")
	# 0.3 × 4 = 1.2 → 扣 1 血余 0.2
	enemy._dmg_acc = 0.0
	enemy.hp = 2
	for i in 4:
		enemy.take_damage(0.3)
	assert_eq(enemy.hp, 1, "0.3×4=1.2 → 扣 1 血")

func test_boss_fractional_damage():
	var boss = load("res://scripts/enemy/boss.gd").new()
	autofree(boss)
	var phase := PhaseData.new()
	phase.hp = 5
	phase.time_limit = 10.0
	phase.bonus = 100
	boss.start_phase(phase)
	boss._invincible = false
	boss._hp = 5
	boss.take_damage(0.25)
	assert_eq(boss.hp, 5, "0.25 不足 1 不扣血")
	boss.take_damage(0.25)
	boss.take_damage(0.25)
	boss.take_damage(0.25)
	assert_eq(boss.hp, 4, "0.25×4=1 → 扣 1 血")
