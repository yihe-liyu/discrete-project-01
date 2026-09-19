extends GutTest
## Timeline.sequence_phases：按序连打阶段（击破 → gap → 下一张；只有最后一张击破后才武装 wait）。
## 用鸭子类型假 Boss（有 start_phase + phase_cleared 信号），不依赖真实 Boss 场景。

class FakeBoss extends Node:
	signal phase_cleared(captured: bool, bonus: int)
	var started: Array[PhaseData] = []
	func start_phase(data: PhaseData) -> void:
		started.append(data)


func _phase(p_name: String) -> PhaseData:
	var p := PhaseData.new()
	p.name = p_name
	p.time_limit = 30.0
	p.hp = 100
	return p


func test_sequence_phases_in_order_with_gap() -> void:
	var tl := Timeline.new()
	var fake := FakeBoss.new()
	add_child_autofree(fake)
	var phases: Array[PhaseData] = [_phase("P0"), _phase("P1"), _phase("P2")]
	tl.at(0.0).sequence_phases(func(): return fake, phases, 1.0)

	tl.tick(0.1)
	assert_eq(fake.started.size(), 1, "起手 P0")
	assert_eq(fake.started[0].name, "P0")

	fake.phase_cleared.emit(false, 0)   # P0 击破
	tl.tick(0.5)                        # 未到 gap
	assert_eq(fake.started.size(), 1, "gap 未到不进下一张")
	tl.tick(0.6)                        # 累计 1.1 ≥ 1.0
	assert_eq(fake.started.size(), 2, "gap 到 → P1")
	assert_eq(fake.started[1].name, "P1")

	fake.phase_cleared.emit(false, 0)   # P1 击破
	tl.tick(1.1)
	assert_eq(fake.started.size(), 3, "P2")
	assert_eq(fake.started[2].name, "P2")

	fake.phase_cleared.emit(false, 0)   # 最后一张击破
	tl.tick(0.1)
	assert_eq(fake.started.size(), 3, "序列结束不再起")


func test_sequence_phases_arms_wait_only_after_last() -> void:
	var tl := Timeline.new()
	var fake := FakeBoss.new()
	add_child_autofree(fake)
	var phases: Array[PhaseData] = [_phase("P0"), _phase("P1")]
	var fired: Array = []
	tl.at(0.0).sequence_phases(func(): return fake, phases, 0.0)
	tl.wait(2.0).do(func(): fired.append("retreat"))

	tl.tick(0.1)                          # P0 起手
	fake.phase_cleared.emit(false, 0)     # P0 击破（非最后 → 不武装 wait）
	tl.tick(0.1)                          # gap 0 → P1 起手
	assert_eq(fake.started.size(), 2, "P1 起手")
	assert_true(fired.is_empty(), "中途不应触发 retreat")
	tl.tick(2.1)
	assert_true(fired.is_empty(), "最后一张击破前 wait 不触发")

	fake.phase_cleared.emit(false, 0)     # P1（最后）击破 → 武装 wait
	tl.tick(0.1)
	tl.tick(2.1)
	assert_eq(fired, ["retreat"], "全部打完后 2s 才 retreat")


func test_sequence_phases_empty_arms_wait_immediately() -> void:
	var tl := Timeline.new()
	var empty: Array[PhaseData] = []
	var fired: Array = []
	tl.at(0.0).sequence_phases(func(): return null, empty, 1.0)
	tl.wait(0.5).do(func(): fired.append("x"))
	tl.tick(0.1)
	tl.tick(0.6)
	assert_eq(fired, ["x"], "空表视作已打完 → wait 正常触发")
