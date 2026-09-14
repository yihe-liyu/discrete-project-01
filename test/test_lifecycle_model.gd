extends GutTest
## L1：BulletLifecycle 描述符 + GDScript 参考解释器 ↔ 现有 GDScript 行为 **parity**。
## 见 docs/LIFECYCLE_MODEL.md §9（L1）。bounce = 条件性最强；curve = 状态机 + 钳位。

const DT := 1.0 / 60.0


class FakeHost extends RefCounted:
	var boss: Node2D = null
	var spawns: Array = []
	var sfx: Array = []

	func get_boss() -> Node2D:
		return boss

	func queue_spawn(data, pos: Vector2, dir: Vector2) -> void:
		spawns.append({&"pos": pos, &"dir": dir, &"vel": data.velocity if data != null else Vector2.ZERO})

	func play_sfx(key: StringName, _db: float) -> void:
		sfx.append(key)


func _system() -> BulletSystem:
	var s: BulletSystem = autofree(BulletSystem.new())
	s.cull_rect = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
	s.cull_margin = 0.0
	s.default_lifetime = 100.0
	return s


func _step(system: BulletSystem, behavior: Behavior, ctx: BehaviorContext, frames: int) -> void:
	for _f in frames:
		system._physics_process(DT)
		var n: int = system.get_active_count()
		for i in n:
			behavior.process(system, i, ctx)
		# 正确回收：按 id **降序**。swap-with-last 下升序会让大 id 在 count 缩小后失效。
		# 注：现引擎 BehaviorProcessor 正是**升序** drain（多弹同帧回收丢一个），见日志。
		var req: Array = []
		for id in system.take_despawn_requests():
			req.append(id)
		req.sort()
		req.reverse()
		for id in req:
			system.despawn(id)


func test_bounce_lifecycle_parity() -> void:
	var bt := BulletType.new()
	var boss: Node2D = add_child_autofree(Node2D.new())
	boss.position = Vector2(448.0, 200.0)
	var ctx := BehaviorContext.new()

	var sys_a := _system()
	var beh_a = preload("res://test/reference/behavior/bounce_behavior.gd").new()
	var host_a := FakeHost.new()
	host_a.boss = boss
	beh_a.host = host_a

	var sys_b := _system()
	var beh_b := LifecycleBehavior.new()
	var host_b := FakeHost.new()
	host_b.boss = boss
	beh_b.host = host_b

	var factory := func() -> BulletData:
		var d := BulletData.new()
		d.velocity = Vector2(1.0, 1.0)
		return d

	var params_a := {
		&"accel": 100.0, &"bounce_angle": 0.3, &"spawn_factory": factory,
		&"spawn_speed": 0.0, &"sfx": "", &"sfx_db": 0.0,
	}
	var lc := BulletLifecycle.bounce(100.0, 0.3, 0.0, factory, &"")
	var params_b := {&"lifecycle": lc}

	var n := 10
	for i in n:
		var pos := Vector2(200.0 + i * 40.0, 300.0)
		var vel := Vector2(0.0, -180.0).rotated((i - n * 0.5) * 0.35)
		sys_a.spawn(bt, pos, vel, Color.WHITE, &"bounce", params_a)
		sys_b.spawn(bt, pos, vel, Color.WHITE, &"lifecycle", params_b)

	for f in 400:
		_step(sys_a, beh_a, ctx, 1)
		_step(sys_b, beh_b, ctx, 1)
		if sys_a.get_active_count() != sys_b.get_active_count():
			fail_test("活跃数帧 %d 分歧：%d vs %d" % [f, sys_a.get_active_count(), sys_b.get_active_count()])
			return
		for i in sys_a.get_active_count():
			if not sys_a.get_velocity(i).is_equal_approx(sys_b.get_velocity(i)):
				fail_test("速度帧 %d 行 %d 分歧：%s vs %s" % [f, i, sys_a.get_velocity(i), sys_b.get_velocity(i)])
				return
			if not sys_a.get_position(i).is_equal_approx(sys_b.get_position(i)):
				fail_test("位置帧 %d 行 %d 分歧" % [f, i])
				return

	assert_eq(host_b.spawns.size(), host_a.spawns.size(), "替换弹发射数")
	for k in host_a.spawns.size():
		assert_true(host_b.spawns[k].pos.is_equal_approx(host_a.spawns[k].pos), "替换弹位置 #%d" % k)
		assert_true(host_b.spawns[k].dir.is_equal_approx(host_a.spawns[k].dir), "替换弹方向 #%d" % k)
		assert_true(host_b.spawns[k].vel.is_equal_approx(host_a.spawns[k].vel), "替换弹速度 #%d" % k)
	assert_gt(host_a.spawns.size(), 0, "应至少有一次碰框换弹")


func test_curve_lifecycle_parity() -> void:
	var bt := BulletType.new()
	var ctx := BehaviorContext.new()

	var sys_a := _system()
	var beh_a := CurveBehavior.new()

	var sys_b := _system()
	var beh_b := LifecycleBehavior.new()

	var w := 2.0
	var limit := 1.0
	var params_a := {&"curve": w, &"curve_limit": limit}
	var params_b := {&"lifecycle": BulletLifecycle.curve(w, limit)}

	for i in 6:
		var pos := Vector2(300.0 + i * 20.0, 400.0)
		var vel := Vector2.UP * 150.0
		sys_a.spawn(bt, pos, vel, Color.WHITE, &"curve", params_a)
		sys_b.spawn(bt, pos, vel, Color.WHITE, &"lifecycle", params_b)

	for f in 180:
		_step(sys_a, beh_a, ctx, 1)
		_step(sys_b, beh_b, ctx, 1)
		if sys_a.get_active_count() != sys_b.get_active_count():
			fail_test("curve 活跃数帧 %d 分歧" % f)
			return
		for i in sys_a.get_active_count():
			if not sys_a.get_velocity(i).is_equal_approx(sys_b.get_velocity(i)):
				fail_test("curve 速度帧 %d 行 %d 分歧" % [f, i])
				return
			if not sys_a.get_position(i).is_equal_approx(sys_b.get_position(i)):
				fail_test("curve 位置帧 %d 行 %d 分歧" % [f, i])
				return
	pass_test("curve %d 帧逐位一致" % 180)

## 组合性：两段各自 rotate 一个独立槽。若相位切换不清槽，第二段会「以为已转满」→ 立刻结束。
func test_composition_phases_isolate_slots() -> void:
	var bt := BulletType.new()
	var system := _system()
	var beh := LifecycleBehavior.new()
	var ctx := BehaviorContext.new()
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 1.0)
	lc.until_turned()
	lc.then()
	lc.rotate(2.0, 1.0)
	lc.until_turned()
	lc.despawn()
	system.spawn(bt, Vector2(300.0, 400.0), Vector2.UP * 100.0, Color.WHITE, &"lifecycle", {&"lifecycle": lc})
	_step(system, beh, ctx, 50)
	assert_eq(system.get_active_count(), 1, "第二相位应仍在转（1.0s 前不应结束）")
	_step(system, beh, ctx, 15)
	assert_eq(system.get_active_count(), 0, "两段各转满 1 弧度后应回收（约 1.0s）")

