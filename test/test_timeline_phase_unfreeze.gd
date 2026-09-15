extends GutTest
## B 方案回归：Boss 阶段战斗不再冻结时间轴
## —— 绝对时间事件（at）战斗期间照常触发；wait() 仍等 phase_cleared 激活

func test_absolute_events_fire_during_boss_phase():
	var timeline := Timeline.new()
	var is_fired: Array[String] = []
	timeline.at(5.0).do(func(): is_fired.append("a"))

	var boss: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	var phase := PhaseData.new()
	phase.name = "测试阶段"
	phase.hp = 100
	phase.time_limit = 10.0
	timeline.at(2.0).start_phase(func(): return boss, phase)

	# 模拟战斗推进 6 秒（Boss 阶段已开始，但绝对事件应照常触发）
	for i in 10:
		timeline.tick(0.6)
	assert_eq(is_fired.size(), 1, "战斗期间绝对时间事件应照常触发")

	# wait 事件：击破前不触发
	var wait_fired: Array[String] = []
	timeline.wait(1.0).do(func(): wait_fired.append("w"))
	for i in 10:
		timeline.tick(0.6)
	assert_eq(wait_fired.size(), 0, "未击破前 wait 事件不应触发")

	# 击破阶段 → wait 激活
	boss.clear_phase(true)
	for i in 10:
		timeline.tick(0.6)
	assert_eq(wait_fired.size(), 1, "击破后 wait 事件应触发")
