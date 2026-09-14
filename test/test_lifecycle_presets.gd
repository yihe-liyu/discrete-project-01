extends GutTest
## L2：其余 preset 与现有 GDScript 行为 parity（见 docs/LIFECYCLE_MODEL.md §9）。

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
		var req: Array = []
		for id in system.take_despawn_requests():
			req.append(id)
		req.sort()
		req.reverse()
		for id in req:
			system.despawn(id)


func _parity(tag: String, beh_a: Behavior, params_a: Dictionary, lc: BulletLifecycle,
		_host_a, host_b, ctx: BehaviorContext, spawns: Array, frames: int) -> void:
	var bt := BulletType.new()
	var sys_a := _system()
	var sys_b := _system()
	var beh_b := LifecycleBehavior.new()
	beh_b.host = host_b
	for s in spawns:
		sys_a.spawn(bt, s[0], s[1], Color.WHITE, &"ref", params_a)
		sys_b.spawn(bt, s[0], s[1], Color.WHITE, &"lifecycle", {&"lifecycle": lc})
	for f in frames:
		_step(sys_a, beh_a, ctx, 1)
		_step(sys_b, beh_b, ctx, 1)
		if sys_a.get_active_count() != sys_b.get_active_count():
			fail_test("%s 活跃数帧 %d：%d vs %d" % [tag, f, sys_a.get_active_count(), sys_b.get_active_count()])
			return
		for i in sys_a.get_active_count():
			if not sys_a.get_position(i).is_equal_approx(sys_b.get_position(i)):
				fail_test("%s 位置帧 %d 行 %d" % [tag, f, i])
				return
			if not sys_a.get_velocity(i).is_equal_approx(sys_b.get_velocity(i)):
				fail_test("%s 速度帧 %d 行 %d: A=%s B=%s" % [tag, f, i, sys_a.get_velocity(i), sys_b.get_velocity(i)])
				return
	pass_test("%s %d 帧逐位一致" % [tag, frames])


func _spawns_spread(n: int, y: float) -> Array:
	var out: Array = []
	for i in n:
		out.append([Vector2(200.0 + i * 40.0, y), Vector2(0.0, -180.0).rotated((i - n * 0.5) * 0.2)])
	return out


func test_accel_preset_parity() -> void:
	_parity("accel", AccelBehavior.new(), {&"accel": 90.0}, BulletLifecycle.accel(90.0),
		null, null, BehaviorContext.new(), _spawns_spread(6, 300.0), 120)


func test_world_accel_preset_parity() -> void:
	var beh = preload("res://test/reference/behavior/world_accel_behavior.gd").new()
	_parity("world_accel", beh, {&"world_accel": Vector2(0.0, 300.0)}, BulletLifecycle.world_accel(Vector2(0.0, 300.0)),
		null, null, BehaviorContext.new(), _spawns_spread(6, 300.0), 120)


func test_radial_accel_preset_parity() -> void:
	var boss: Node2D = add_child_autofree(Node2D.new())
	boss.position = Vector2(448.0, 100.0)
	var factory := func() -> BulletData:
		var d := BulletData.new(); d.velocity = Vector2(1.0, 1.0); return d
	var ha := FakeHost.new(); ha.boss = boss
	var hb := FakeHost.new(); hb.boss = boss
	var beh = preload("res://test/reference/behavior/radial_accel_behavior.gd").new()
	beh.host = ha
	_parity("radial_accel", beh, {&"accel_rate": 120.0, &"spawn_factory": factory, &"sfx": "", &"sfx_db": 0.0},
		BulletLifecycle.radial_accel(120.0, factory, &""), ha, hb, BehaviorContext.new(), _spawns_spread(6, 400.0), 200)
	assert_gt(ha.spawns.size(), 0, "应至少一次顶边换弹")
	assert_eq(hb.spawns.size(), ha.spawns.size(), "换弹数一致")


func test_laser_follow_preset_parity() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 600.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var beh := LaserFollowBehavior.new()
	var params := {&"anchor_id": 0, &"anchor_offset": Vector2(0.0, 0.0), &"drift_speed": 1000.0, &"angle": 0.0, &"initial_drift": 0.0}
	var lc := BulletLifecycle.laser_follow(0, Vector2.ZERO, 0.0, 1000.0, 0.0)
	var spawns: Array = []
	for i in 4:
		spawns.append([Vector2(400.0 + i * 10.0, 600.0), Vector2.ZERO])
	_parity("laser_follow", beh, params, lc, null, null, ctx, spawns, 60)


func test_homing_preset_parity() -> void:
	var enemy: Node2D = add_child_autofree(Node2D.new())
	enemy.position = Vector2(448.0, 100.0)
	var provider := func() -> Array: return [enemy]
	var ctx := BehaviorContext.new()
	ctx.setup(null, WorldQuery.new())
	ctx.get_world().setup(provider)
	var beh = preload("res://test/reference/behavior/homing_behavior.gd").new()
	var params := {&"homing_angle_per_sec": deg_to_rad(720.0), &"accel_time": 1.0, &"min_speed": 200.0,
		&"max_speed": 500.0, &"homing_duration": 2.0, &"proximity_boost": 150.0}
	var lc := BulletLifecycle.homing(deg_to_rad(720.0), 1.0, 200.0, 500.0, 2.0, 150.0)
	var spawns: Array = []
	for i in 6:
		spawns.append([Vector2(300.0 + i * 50.0, 500.0), Vector2(0.0, -150.0).rotated((i - 3) * 0.2)])
	_parity("homing", beh, params, lc, null, null, ctx, spawns, 150)


func test_avoid_player_preset_parity() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var beh := AvoidPlayerBehavior.new(150.0, 0.6)
	var lc := BulletLifecycle.avoid_player(150.0, 0.05, 0.6)
	var spawns: Array = []
	for i in 6:
		spawns.append([Vector2(448.0 + (i - 3) * 30.0, 500.0 + (i - 3) * 20.0), Vector2(0.0, -120.0)])
	_parity("avoid_player", beh, {}, lc, null, null, ctx, spawns, 120)

func test_marisa_laser_preset_parity() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(300.0, 600.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var beh = preload("res://test/reference/behavior/marisa_laser_behavior.gd").new()
	var params := {&"anchor_id": 0, &"anchor_offset": Vector2(10.0, 0.0), &"drift_speed": 800.0, &"angle": 0.3, &"initial_drift": 5.0}
	var lc := BulletLifecycle.marisa_laser(0, Vector2(10.0, 0.0), 0.3, 800.0, 5.0)
	var spawns: Array = []
	for i in 3:
		spawns.append([Vector2(280.0 + i * 5.0, 600.0), Vector2(0.0, -200.0)])
	_parity("marisa_laser", beh, params, lc, null, null, ctx, spawns, 30)


func test_non_mid_flee_preset_parity() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var boss: Node2D = add_child_autofree(Node2D.new())
	boss.position = Vector2(448.0, 120.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var r := 150.0
	var burst := func(pos: Vector2, boss_pos: Vector2, has_boss: bool, _host) -> bool:
		return has_boss and pos.distance_to(boss_pos) < r
	var ha := FakeHost.new(); ha.boss = boss
	var hb := FakeHost.new(); hb.boss = boss
	var beh = preload("res://test/reference/behavior/non_mid_flee_behavior.gd").new()
	beh.host = ha
	var params := {&"player_proximity": 150.0, &"on_flee_burst": burst}
	var lc := BulletLifecycle.non_mid_flee(150.0, r, burst)
	var spawns: Array = []
	for i in 6:
		spawns.append([Vector2(448.0 + (i - 3) * 20.0, 500.0 + (i - 3) * 15.0), Vector2(0.0, -200.0)])
	_parity("non_mid_flee", beh, params, lc, ha, hb, ctx, spawns, 150)

