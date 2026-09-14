extends GutTest
## L3：原生 behavior_tick（packed program）↔ GDScript 参考解释器 LifecycleBehavior 逐位 parity。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


class FakeHost extends RefCounted:
	var boss: Node2D = null
	var spawns: Array = []
	var sfx: Array = []
	func get_boss() -> Node2D: return boss
	func queue_spawn(data, pos: Vector2, dir: Vector2) -> void:
		spawns.append({&"pos": pos, &"dir": dir, &"vel": data.velocity if data != null else Vector2.ZERO})
	func play_sfx(key: StringName, _db: float) -> void: sfx.append(key)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


## 数值容差：GDScript 标量是 64 位，原生是 32 位 —— 三角函数类会累积 ~1e-6/帧 的漂移。
func _close(a: Vector2, b: Vector2, eps := 2e-3) -> bool:
	return (a - b).length() <= eps * maxf(1.0, maxf(a.length(), b.length()))


func _gs() -> BulletSystem:
	var s: BulletSystem = autofree(BulletSystem.new())
	s.cull_rect = CULL
	s.cull_margin = 0.0
	s.default_lifetime = 100.0
	return s


func _apply_events(ev: Dictionary, compiled: Dictionary, host: FakeHost, boss: Node2D, has_boss: bool) -> void:
	var kinds: PackedInt32Array = ev["kind"]
	var local: PackedInt32Array = ev["local"]
	var xs: PackedFloat32Array = ev["x"]
	var ys: PackedFloat32Array = ev["y"]
	var dxs: PackedFloat32Array = ev["dx"]
	var dys: PackedFloat32Array = ev["dy"]
	var vals: PackedFloat32Array = ev["val"]
	var acts: Array = compiled["actions"]
	var sfx: Array = compiled["sfx"]
	for k in kinds.size():
		match kinds[k]:
			0:
				var fn: Callable = acts[local[k]]
				var b = fn.call()
				if b != null:
					b.velocity = Vector2(0.0, vals[k])
					host.queue_spawn(b, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]))
			1:
				host.play_sfx(sfx[local[k]], vals[k])
			2:
				var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
				(acts[local[k]] as Callable).call(Vector2(xs[k], ys[k]), boss_pos, has_boss, host)


func _run(tag: String, lc: BulletLifecycle, beh_a: Behavior, params_a: Dictionary,
		host_a: FakeHost, ctx: BehaviorContext, spawns: Array, frames: int,
		player: Vector2, boss: Node2D, has_boss: bool, enemies: Array,
		anchor_base: PackedVector2Array = PackedVector2Array()) -> void:
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(1024, CULL)
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
	var compiled: Dictionary = lc.compile()
	var pid: int = store.register_program(compiled["ops"], compiled["args"], compiled["move_start"], compiled["move_count"], compiled["until_idx"], compiled["act_start"], compiled["act_count"], compiled["phase_count"], compiled["slots"])

	var gs := _gs()
	var beh_b := LifecycleBehavior.new()
	var host_b := FakeHost.new()
	host_b.boss = boss
	beh_b.host = host_b
	var host_nat := FakeHost.new()
	host_nat.boss = boss
	var bt := BulletType.new()
	var enemy_pos := PackedVector2Array()
	for e in enemies:
		enemy_pos.append(e.global_position)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	for s in spawns:
		gs.spawn(bt, s[0], s[1], Color.WHITE, &"lifecycle", {&"lifecycle": lc})
		var id: int = store.spawn(s[0], s[1], 0, 0, Color.WHITE)
		store.set_program(id, pid)

	for f in frames:
		gs._physics_process(DT)
		for i in gs.get_active_count():
			beh_b.process(gs, i, ctx)
		var req: Array = []
		for id in gs.take_despawn_requests():
			req.append(id)
		req.sort(); req.reverse()
		for id in req:
			gs.despawn(id)

		store.integrate(DT)
		var ev: Dictionary = store.behavior_tick(DT, player, boss_pos, has_boss, enemy_pos, anchor_base)
		_apply_events(ev, compiled, host_nat, boss, has_boss)

		if gs.get_active_count() != store.get_active_count():
			fail_test("%s 活跃数帧 %d：%d vs %d" % [tag, f, gs.get_active_count(), store.get_active_count()])
			return
		for i in gs.get_active_count():
			if not _close(gs.get_position(i), store.get_position(i)):
				fail_test("%s 位置帧 %d 行 %d：A=%s B=%s" % [tag, f, i, gs.get_position(i), store.get_position(i)]); return
			if not _close(gs.get_velocity(i), store.get_velocity(i)):
				fail_test("%s 速度帧 %d 行 %d：A=%s B=%s" % [tag, f, i, gs.get_velocity(i), store.get_velocity(i)]); return
	assert_eq(host_nat.spawns.size(), host_b.spawns.size(), "%s 发射事件数 nat=%d ref=%d" % [tag, host_nat.spawns.size(), host_b.spawns.size()])
	for k in host_b.spawns.size():
		assert_true(host_nat.spawns[k].pos.is_equal_approx(host_b.spawns[k].pos), "%s 发射位置 #%d" % [tag, k])
		assert_true(host_nat.spawns[k].dir.is_equal_approx(host_b.spawns[k].dir), "%s 发射方向 #%d" % [tag, k])
	assert_eq(host_nat.sfx.size(), host_b.sfx.size(), "%s sfx 事件数" % tag)
	pass_test("%s %d 帧原生↔参考一致" % [tag, frames])


func _spread(n: int, y: float) -> Array:
	var out: Array = []
	for i in n:
		out.append([Vector2(200.0 + i * 40.0, y), Vector2(0.0, -180.0).rotated((i - n * 0.5) * 0.2)])
	return out


func test_native_curve() -> void:
	if not _available(): pending("无扩展"); return
	_run("curve", BulletLifecycle.curve(2.0, 1.0), CurveBehavior.new(), {&"curve": 2.0, &"curve_limit": 1.0}, FakeHost.new(), BehaviorContext.new(), _spread(6, 300.0), 120, Vector2.ZERO, null, false, [])


func test_native_accel() -> void:
	if not _available(): pending("无扩展"); return
	_run("accel", BulletLifecycle.accel(90.0), AccelBehavior.new(), {&"accel": 90.0}, FakeHost.new(), BehaviorContext.new(), _spread(6, 300.0), 120, Vector2.ZERO, null, false, [])


func test_native_world_accel() -> void:
	if not _available(): pending("无扩展"); return
	_run("world_accel", BulletLifecycle.world_accel(Vector2(0, 300.0)), preload("res://scripts/kernel_bridge/behavior/world_accel_behavior.gd").new(), {&"world_accel": Vector2(0, 300.0)}, FakeHost.new(), BehaviorContext.new(), _spread(6, 300.0), 120, Vector2.ZERO, null, false, [])


func test_native_bounce() -> void:
	if not _available(): pending("无扩展"); return
	var boss: Node2D = add_child_autofree(Node2D.new()); boss.position = Vector2(448.0, 200.0)
	var factory := func() -> BulletData:
		var d := BulletData.new(); d.velocity = Vector2(1, 1); return d
	var ha := FakeHost.new(); ha.boss = boss
	var beh = preload("res://scripts/kernel_bridge/behavior/bounce_behavior.gd").new()
	beh.host = ha
	var params := {&"accel": 100.0, &"bounce_angle": 0.3, &"spawn_factory": factory, &"spawn_speed": 0.0, &"sfx": "", &"sfx_db": 0.0}
	_run("bounce", BulletLifecycle.bounce(100.0, 0.3, 0.0, factory, &""), beh, params, ha, BehaviorContext.new(), _spread(8, 300.0), 300, Vector2.ZERO, boss, true, [])


func test_native_avoid_player() -> void:
	if not _available(): pending("无扩展"); return
	var player: Node2D = add_child_autofree(Node2D.new()); player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new(); ctx.setup(player)
	var spawns: Array = []
	for i in 6:
		spawns.append([Vector2(448.0 + (i - 3) * 30.0, 500.0 + (i - 3) * 20.0), Vector2(0.0, -120.0)])
	_run("avoid_player", BulletLifecycle.avoid_player(150.0, 0.05, 0.6), AvoidPlayerBehavior.new(150.0, 0.6), {}, FakeHost.new(), ctx, spawns, 120, player.global_position, null, false, [])

func _spread_at(n: int, y: float, vel_y: float) -> Array:
	var out: Array = []
	for i in n:
		out.append([Vector2(200.0 + i * 40.0, y), Vector2(0.0, vel_y).rotated((i - n * 0.5) * 0.15)])
	return out


func test_native_homing() -> void:
	if not _available(): pending("无扩展"); return
	var enemy: Node2D = add_child_autofree(Node2D.new()); enemy.position = Vector2(448.0, 100.0)
	var ctx := BehaviorContext.new(); ctx.setup(null, WorldQuery.new())
	ctx.get_world().setup(func() -> Array: return [enemy])
	var lc := BulletLifecycle.homing(deg_to_rad(720.0), 1.0, 200.0, 500.0, 2.0, 150.0)
	# 注意：steer 是反馈环（转向→位置→角度），32 位↔64 位浮点差会被放大成方向翻转。
	# 故在「加速未饱和（ramp=1s）、反馈尚未放大」的地平线内对照。
	_run("homing", lc, CurveBehavior.new(), {}, FakeHost.new(), ctx, _spread_at(6, 500.0, -150.0), 45, Vector2.ZERO, null, false, [enemy])


func test_native_radial_accel() -> void:
	if not _available(): pending("无扩展"); return
	var factory := func() -> BulletData:
		var d := BulletData.new(); d.velocity = Vector2(1, 1); return d
	var lc := BulletLifecycle.radial_accel(120.0, factory, &"")
	_run("radial_accel", lc, CurveBehavior.new(), {}, FakeHost.new(), BehaviorContext.new(), _spread_at(6, 400.0, -180.0), 200, Vector2.ZERO, null, false, [])


func test_native_non_mid_flee() -> void:
	if not _available(): pending("无扩展"); return
	var player: Node2D = add_child_autofree(Node2D.new()); player.position = Vector2(448.0, 500.0)
	var boss: Node2D = add_child_autofree(Node2D.new()); boss.position = Vector2(448.0, 120.0)
	var ctx := BehaviorContext.new(); ctx.setup(player)
	var r := 150.0
	var burst := func(pos: Vector2, boss_pos: Vector2, has_boss: bool, _host) -> bool:
		return has_boss and pos.distance_to(boss_pos) < r
	var lc := BulletLifecycle.non_mid_flee(150.0, r, burst)
	var spawns: Array = []
	for i in 6:
		spawns.append([Vector2(448.0 + (i - 3) * 20.0, 500.0 + (i - 3) * 15.0), Vector2(0.0, -200.0)])
	_run("non_mid_flee", lc, CurveBehavior.new(), {}, FakeHost.new(), ctx, spawns, 150, player.global_position, boss, true, [])


func test_native_marisa_laser() -> void:
	if not _available(): pending("无扩展"); return
	var player: Node2D = add_child_autofree(Node2D.new()); player.position = Vector2(300.0, 600.0)
	# 真实游戏用非 0 anchor_id（子机是 World 兄弟）；历史原生把它整个忽略 → 段全粘在 player 上。
	var anchor: Node2D = add_child_autofree(Node2D.new()); anchor.position = Vector2(340.0, 560.0)
	var ctx := BehaviorContext.new(); ctx.setup(player)
	var off := Vector2(10.0, 0.0)
	var lc := BulletLifecycle.marisa_laser(anchor.get_instance_id(), off, 0.3, 800.0, 5.0)
	var spawns: Array = []
	for i in 3:
		spawns.append([Vector2(280.0 + i * 5.0, 600.0), Vector2(0.0, -200.0)])
	# 手工按 use_global 语义算 base（不复用被测 helper）→ 原生若忽略锚点会立刻发散。
	var base := PackedVector2Array([anchor.global_position + off])
	_run("marisa_laser", lc, CurveBehavior.new(), {}, FakeHost.new(), ctx, spawns, 30, player.global_position, null, false, [], base)

