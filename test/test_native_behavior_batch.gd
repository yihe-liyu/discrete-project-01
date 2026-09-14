extends GutTest
## L3.5-3a：无状态 behavior_batch（数组进/出）与有状态 behavior_tick 1:1；并验证 dead 返回。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(1024, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(64.0, 832.0, 32.0)
	return s


func _reg(store, lc: BulletLifecycle) -> Array:
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	return [pid, c]


func _seeds(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append([Vector2(200.0 + i * 40.0, 300.0), Vector2(0.0, -180.0).rotated((i - n * 0.5) * 0.2)])
	return out


func test_batch_curve_matches_tick() -> void:
	if not _available(): pending("无扩展"); return
	var lc := BulletLifecycle.curve(2.0, 1.0)
	var st_tick = _store()
	var rt: Array = _reg(st_tick, lc)
	var st_batch = _store()
	var rb: Array = _reg(st_batch, lc)
	var pid: int = rt[0]
	var n := 10
	var seeds := _seeds(n)

	# 有状态：spawn + tick
	for s in seeds:
		var id: int = st_tick.spawn(s[0], s[1], 0, 0, Color.WHITE)
		st_tick.set_program(id, pid)

	# 无状态：数组
	var pos := PackedVector2Array(); var vel := PackedVector2Array()
	var life := PackedFloat32Array(); var fx := PackedFloat32Array()
	var prog := PackedInt32Array(); var phase := PackedInt32Array()
	var tick := PackedInt32Array(); var elapsed := PackedFloat32Array(); var slots := PackedFloat32Array()
	for s in seeds:
		pos.append(s[0]); vel.append(s[1]); life.append(0.0); fx.append(0.0)
		prog.append(pid); phase.append(0); tick.append(0); elapsed.append(0.0)
	for k in n * 8:
		slots.append(0.0)

	for f in 120:
		st_tick.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
		var res: Dictionary = st_batch.behavior_batch(pos.size(), pos, vel, life, fx, prog, phase, tick, elapsed, slots, DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
		pos = res["positions"]; vel = res["velocities"]; life = res["life"]; fx = res["fx"]
		prog = res["program"]; phase = res["phase"]; tick = res["tick"]; elapsed = res["elapsed"]; slots = res["slots"]
		assert_eq(res["dead"].size(), 0, "curve 不应有 dead")
		assert_eq(st_tick.get_active_count(), pos.size(), "活跃数帧 %d" % f)
		for i in pos.size():
			if not st_tick.get_position(i).is_equal_approx(pos[i]):
				fail_test("batch 位置帧 %d 行 %d" % [f, i]); return
			if not st_tick.get_velocity(i).is_equal_approx(vel[i]):
				fail_test("batch 速度帧 %d 行 %d" % [f, i]); return
	pass_test("batch ↔ tick 120 帧一致")


func test_batch_bounce_returns_dead() -> void:
	if not _available(): pending("无扩展"); return
	var boss: Node2D = add_child_autofree(Node2D.new())
	boss.position = Vector2(448.0, 100.0)
	var factory := func() -> BulletData:
		var d := BulletData.new(); d.velocity = Vector2(1, 1); return d
	var lc := BulletLifecycle.bounce(100.0, 0.3, 0.0, factory, &"")
	var st = _store()
	var r: Array = _reg(st, lc)
	var pid: int = r[0]
	var seeds := _seeds(8)
	var pos := PackedVector2Array(); var vel := PackedVector2Array()
	var life := PackedFloat32Array(); var fx := PackedFloat32Array()
	var prog := PackedInt32Array(); var phase := PackedInt32Array()
	var tick := PackedInt32Array(); var elapsed := PackedFloat32Array(); var slots := PackedFloat32Array()
	for s in seeds:
		pos.append(s[0]); vel.append(s[1]); life.append(0.0); fx.append(0.0)
		prog.append(pid); phase.append(0); tick.append(0); elapsed.append(0.0)
	for k in 8 * 8:
		slots.append(0.0)
	var dead_total := 0
	var enemies := PackedVector2Array()
	for f in 400:
		# 位置积分由调用方负责（游戏里 _physics_process 做）；behavior_batch 只改速度。
		for i in pos.size():
			pos[i] = pos[i] + vel[i] * DT
		var res: Dictionary = st.behavior_batch(pos.size(), pos, vel, life, fx, prog, phase, tick, elapsed, slots, DT, Vector2.ZERO, boss.global_position, true, enemies)
		pos = res["positions"]; vel = res["velocities"]; life = res["life"]; fx = res["fx"]
		prog = res["program"]; phase = res["phase"]; tick = res["tick"]; elapsed = res["elapsed"]; slots = res["slots"]
		dead_total += res["dead"].size()
		if res["dead"].size() == 0:
			continue
		# 调用方按 dead 重放（降序 swap）
		var ids: Array = []
		for id in res["dead"]:
			ids.append(id)
		ids.sort(); ids.reverse()
		for id in ids:
			var last := pos.size() - 1
			if id != last:
				pos[id] = pos[last]; vel[id] = vel[last]; life[id] = life[last]; fx[id] = fx[last]
				prog[id] = prog[last]; phase[id] = phase[last]; tick[id] = tick[last]; elapsed[id] = elapsed[last]
				for s in 8:
					slots[id * 8 + s] = slots[last * 8 + s]
			pos.resize(last); vel.resize(last); life.resize(last); fx.resize(last)
			prog.resize(last); phase.resize(last); tick.resize(last); elapsed.resize(last)
			slots.resize(last * 8)
	assert_gt(dead_total, 0, "bounce 应返回 dead")
	assert_eq(pos.size(), 0, "全部碰框后应清空")
	pass_test("bounce dead 返回 + 重放正确")


func test_batch_anchor_drift_first_frame_uses_initial() -> void:
	if not _available(): pending("无扩展"); return
	# 新弹首帧必须用 initial_drift（不是 0 + speed·dt）；batch 路径没有 set_program，
	# 内部状态（_pfresh/_pnext/_phasend...）要在 tick==0 时初始化。
	var lc := BulletLifecycle.marisa_laser(0, Vector2.ZERO, 0.0, 800.0, 50.0)
	var st = _store()
	var r: Array = _reg(st, lc)
	var pid: int = r[0]
	var pos := PackedVector2Array([Vector2(100.0, 100.0)])
	var vel := PackedVector2Array([Vector2.ZERO])
	var life := PackedFloat32Array([100.0])
	var fx := PackedFloat32Array([0.0])
	var prog := PackedInt32Array([pid])
	var phase := PackedInt32Array([0])
	var tick := PackedInt32Array([0])
	var elapsed := PackedFloat32Array([0.0])
	var slots := PackedFloat32Array()
	slots.resize(8)
	var player := Vector2(200.0, 300.0)
	var res: Dictionary = st.behavior_batch(1, pos, vel, life, fx, prog, phase, tick, elapsed, slots, DT, player, Vector2.ZERO, false, PackedVector2Array())
	var out: Vector2 = res["positions"][0]
	assert_almost_eq(out.x, 200.0, 0.01, "angle=0 段应贴 player x")
	assert_almost_eq(out.y, 250.0, 0.01, "首帧应用 initial_drift=50（player.y - 50）")
