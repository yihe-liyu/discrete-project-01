extends GutTest
## 最小原语覆盖（9 Move op / 5 Until / 5 Action）—— 每个原语一条最小 lifecycle，
## 与参考解释器 LifecycleBehavior 逐位对照。它同时是「原语能干什么」的活文档。
##
## 为什么单独一份：预设级 parity 只覆盖"被 preset 用到"的原语。实测 9 个 Move 里有 4 个
## （speed_lerp / speed_mul / set_heading / set_speed）**没有任何 preset 使用 → 零覆盖**。
## 这里按原语逐条锚定；预设级 parity 仍留在 test_native_executor.gd（集成层）。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)

## 阈值不要压在 k/60 上：参考侧 64 位累加（0.49999…）、原生 32 位（0.5）会差一帧。
## 故下面 `until_elapsed` / state 阈值都取帧边界**之间**的值。


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


## 一条原语的 parity：同一份 lc 分别喂 原生 behavior_tick 与 参考解释器，逐帧对照位置/速度/事件。
func _parity(tag: String, lc: BulletLifecycle, frames: int, spawns: Array, ctx: BehaviorContext,
		player: Vector2 = Vector2.ZERO, boss: Node2D = null, has_boss: bool = false,
		enemies: Array = []) -> void:
	if not _available():
		pending("未构建原生扩展")
		return
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(1024, CULL)
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
	var compiled: Dictionary = lc.compile()
	var pid: int = store.register_program(compiled["ops"], compiled["args"], compiled["move_start"], compiled["move_count"], compiled["until_idx"], compiled["act_start"], compiled["act_count"], compiled["phase_count"], compiled["slots"])

	var gs := _gs()
	var beh := LifecycleBehavior.new()
	var host_ref := FakeHost.new()
	host_ref.boss = boss
	beh.host = host_ref
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
			beh.process(gs, i, ctx)
		var req: Array = []
		for id in gs.take_despawn_requests():
			req.append(id)
		req.sort(); req.reverse()
		for id in req:
			gs.despawn(id)
		store.integrate(DT)
		_apply_events(store.behavior_tick(DT, player, boss_pos, has_boss, enemy_pos, PackedVector2Array()), compiled, host_nat, boss, has_boss)
		if gs.get_active_count() != store.get_active_count():
			fail_test("%s 活跃数帧 %d：%d vs %d" % [tag, f, gs.get_active_count(), store.get_active_count()]); return
		for i in gs.get_active_count():
			if not _close(gs.get_position(i), store.get_position(i)):
				fail_test("%s 位置帧 %d 行 %d：A=%s B=%s" % [tag, f, i, gs.get_position(i), store.get_position(i)]); return
			if not _close(gs.get_velocity(i), store.get_velocity(i)):
				fail_test("%s 速度帧 %d 行 %d：A=%s B=%s" % [tag, f, i, gs.get_velocity(i), store.get_velocity(i)]); return
	assert_eq(host_nat.spawns.size(), host_ref.spawns.size(), "%s 发射事件数 nat=%d ref=%d" % [tag, host_nat.spawns.size(), host_ref.spawns.size()])
	for k in host_ref.spawns.size():
		assert_true(host_nat.spawns[k].pos.is_equal_approx(host_ref.spawns[k].pos), "%s 发射位置 #%d" % [tag, k])
		assert_true(host_nat.spawns[k].dir.is_equal_approx(host_ref.spawns[k].dir), "%s 发射方向 #%d" % [tag, k])
	assert_eq(host_nat.sfx.size(), host_ref.sfx.size(), "%s sfx 事件数" % tag)
	pass_test("%s %d 帧原生↔参考一致" % [tag, frames])


func _spread(n: int, y: float, vel_y := -180.0) -> Array:
	var out: Array = []
	for i in n:
		out.append([Vector2(200.0 + i * 40.0, y), Vector2(0.0, vel_y).rotated((i - n * 0.5) * 0.2)])
	return out


# ═══════════════════════════════════════════════ Move（9）═══

func test_primitive_move_accel_world() -> void:
	## 世界坐标恒定加速度：速度 += v·dt（与朝向无关）。
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0.0, 300.0))
	lc.until_elapsed(1.52)
	_parity("move:accel_world", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_accel_heading() -> void:
	## 沿当前朝向加速：速度大小 += a·dt，方向不变。
	var lc := BulletLifecycle.new()
	lc.accel_heading(200.0)
	lc.until_elapsed(1.52)
	_parity("move:accel_heading", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_rotate() -> void:
	## 角速度 w（弧度/秒）；limit>0 时累计转角钳到 limit（这里 0.5 弧度）。
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.5)
	lc.until_elapsed(1.52)
	_parity("move:rotate", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_rotate_velocity() -> void:
	## V12：只转速度（朝向不动）—— 原生↔参考 parity。
	var lc := BulletLifecycle.new()
	lc.rotate_velocity(2.0, 0.5)
	lc.until_elapsed(1.52)
	_parity("move:rotate_velocity", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_rotate_heading() -> void:
	## V12：只转朝向（速度不动）。
	var lc := BulletLifecycle.new()
	lc.rotate_heading(2.0, 0.5)
	lc.until_elapsed(1.52)
	_parity("move:rotate_heading", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_rotate_velocity_keeps_heading() -> void:
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.rotate_velocity(PI * 0.5, 0.0)
	lc.until_never()
	var store = _combo_store()
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	store.set_program(id, pid)
	store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(store.get_forward(id).is_equal_approx(Vector2(0, -1)), "rotate_velocity 不应改朝向")
	assert_false(store.get_velocity(id).is_equal_approx(Vector2(0, -100)), "速度应被旋转")
	pass_test("rotate_velocity 只转速度")


func test_primitive_move_rotate_heading_keeps_velocity() -> void:
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.rotate_heading(PI * 0.5, 0.0)
	lc.until_never()
	var store = _combo_store()
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	store.set_program(id, pid)
	store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(store.get_velocity(id).is_equal_approx(Vector2(0, -100)), "rotate_heading 不应改速度")
	assert_false(store.get_forward(id).is_equal_approx(Vector2(0, -1)), "朝向应被旋转")
	pass_test("rotate_heading 只转朝向")


func test_primitive_move_set_speed_stationary() -> void:
	## V15：静止弹 set_speed 用「朝向」定方向（零速出生朝向 = 向下 (0,1)）。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.set_speed(100.0)
	lc.until_never()
	var store = _combo_store()
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(Vector2.ZERO, Vector2.ZERO, 0, 0, Color.WHITE)
	store.set_program(id, pid)
	store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(store.get_velocity(id).is_equal_approx(Vector2(0, 100)), "静止弹 set_speed 应沿朝向(0,1)给速度")
	pass_test("set_speed 对静止弹用朝向")


func test_primitive_move_speed_lerp() -> void:
	## 速度在 ramp 秒内从 from 线性插值到 to（沿当前朝向）。
	var lc := BulletLifecycle.new()
	lc.speed_lerp(120.0, 320.0, 1.0)
	lc.until_elapsed(1.52)
	_parity("move:speed_lerp", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_speed_mul() -> void:
	## 每帧速度乘 f（**复利/指数**，不是瞬时设定）。
	var lc := BulletLifecycle.new()
	lc.speed_mul(1.05)
	lc.until_elapsed(0.52)
	_parity("move:speed_mul", lc, 30, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_set_heading() -> void:
	## 直接设朝向（方向表达式 heading/toward/away），速度大小不变。
	var lc := BulletLifecycle.new()
	lc.set_heading(BulletLifecycle.heading(PI * 0.5))
	lc.until_elapsed(0.52)
	_parity("move:set_heading", lc, 30, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_set_speed() -> void:
	## 直接设速度大小（朝向不变）。
	var lc := BulletLifecycle.new()
	lc.set_speed(500.0)
	lc.until_elapsed(0.52)
	_parity("move:set_speed", lc, 30, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_steer() -> void:
	## 转向目标（这里自机），只转向不改速度。转向是反馈环 → 在浮点尚未放大的地平线内对照。
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.steer(BulletLifecycle.T_PLAYER, deg_to_rad(360.0), 1.0, 0.0, 0.0)
	lc.until_elapsed(1.52)
	_parity("move:steer", lc, 45, _spread(4, 200.0), ctx, player.global_position)


func test_primitive_move_anchor_drift() -> void:
	## pos = 锚点 + dir(angle)·累计漂移；anchor_id=0 → 自机 + offset（首帧取 initial，不推进）。
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(300.0, 600.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.anchor_drift(0, Vector2(10.0, 0.0), 0.3, 800.0, false, 0.0, false)
	lc.until_elapsed(0.52)
	_parity("move:anchor_drift", lc, 30, _spread(3, 600.0), ctx, player.global_position)


func test_primitive_move_drift() -> void:
	## 从相位起点沿 dir 匀速平移（不锚定外部对象）；不改速度/朝向 → 相位结束后按原速度自由飞出。
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 200.0)          # 沿"上"整体平移 200 px/s
	lc.until_elapsed(0.52)
	lc.then()
	lc.until_never()
	_parity("move:drift", lc, 60, _spread(4, 400.0), BehaviorContext.new())


# ═══════════════════════════════════════════════ Until（5+1）═══

func test_primitive_until_never() -> void:
	## 永不满足 —— 弹一直飞，不回收。
	var lc := BulletLifecycle.new()
	lc.until_never()
	_parity("until:never", lc, 60, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_until_elapsed() -> void:
	## 经过 t 秒 → 相位结束。
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.52)
	lc.despawn()
	_parity("until:elapsed", lc, 60, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_until_near() -> void:
	## 距目标 < r → 相位结束。弹朝自机飞，约 17 帧内触发。
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 300.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.until_near(BulletLifecycle.T_PLAYER, 50.0)
	lc.despawn()
	var spawns: Array = []
	for i in 3:
		spawns.append([Vector2(448.0, 420.0 + i * 20.0), Vector2(0.0, -180.0)])
	_parity("until:near", lc, 60, spawns, ctx, player.global_position)


func test_primitive_until_at_wall() -> void:
	## 碰到掩码指定的墙 → 相位结束（这里只测顶墙）。
	var lc := BulletLifecycle.new()
	lc.until_at_wall(BulletLifecycle.WALL_TOP)
	lc.despawn()
	var spawns: Array = []
	for i in 3:
		spawns.append([Vector2(200.0 + i * 30.0, GameConfig.FIELD_TOP + 8.0), Vector2(0.0, -200.0)])
	_parity("until:at_wall", lc, 30, spawns, BehaviorContext.new())


func test_primitive_until_turned() -> void:
	## 便捷形式：当前相位 rotate 的累计转角 >= 其 limit（curve 用法）。
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.62)
	lc.until_turned()
	lc.despawn()
	_parity("until:turned", lc, 60, _spread(4, 400.0), BehaviorContext.new())


# ═══════════════════════════════════════════════ Action（5）═══

func test_primitive_action_sfx() -> void:
	## 相位结束时播一次音效（事件回传宿主）。
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.32)
	lc.sfx(&"kira", -6.0)
	_parity("action:sfx", lc, 40, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_action_emit() -> void:
	## 相位结束时生成替换弹（工厂返回 BulletData，宿主侧执行）。
	var factory := func() -> BulletData:
		var d := BulletData.new()
		d.velocity = Vector2(1.0, 1.0)
		return d
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.32)
	lc.emit(factory, BulletLifecycle.heading(0.0), 200.0, BulletLifecycle.AT_CURRENT)
	_parity("action:emit", lc, 40, _spread(4, 400.0), BehaviorContext.new())


func test_action_emit_at_phase_end_uses_wall_point() -> void:
	## V7：at=AT_PHASE_END 用 until(at_wall) 输出的相位结束落点（夹到框上）。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.until_at_wall(BulletLifecycle.WALL_TOP)
	lc.emit(func() -> BulletData: return BulletData.new(), BulletLifecycle.heading(PI), 100.0, BulletLifecycle.AT_PHASE_END)
	var store = _combo_store()
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(Vector2(400.0, GameConfig.FIELD_TOP + 1.0), Vector2(0, -200), 0, 0, Color.WHITE)
	store.set_program(id, pid)
	store.integrate(DT)
	var res: Dictionary = store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	var ys: PackedFloat32Array = res["y"]
	assert_gt(ys.size(), 0, "应产生 emit 事件")
	assert_almost_eq(ys[0], GameConfig.FIELD_TOP, 0.5, "at=AT_PHASE_END 应用夹到墙上的落点")
	pass_test("AT_PHASE_END 用 until 落点")


func test_primitive_action_despawn() -> void:
	## 相位结束时回收自己。
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.32)
	lc.despawn()
	_parity("action:despawn", lc, 40, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_action_on_end_heading() -> void:
	## 相位结束时转向（保持速度大小）—— 这里朝远离自机；用 then() 观察下一相位。
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.22)
	lc.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
	lc.then()
	lc.until_elapsed(1.02)
	_parity("action:on_end_heading", lc, 40, _spread(4, 300.0), ctx, player.global_position)


func test_primitive_action_on_end_call() -> void:
	## 相位结束时回调 GDScript（一次性、低频）。参考侧**不经 host**，故用共享计数器：
	## 原生 + 参考各回调一次 → 总数为子弹数的 2 倍。
	var calls := [0]
	var fn := func(_pos: Vector2, _boss_pos: Vector2, _has_boss: bool, _host) -> bool:
		calls[0] += 1
		return true
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.22)
	lc.on_end_call(fn)
	var spawns := _spread(4, 400.0)
	_parity("action:on_end_call", lc, 40, spawns, BehaviorContext.new())
	assert_eq(calls[0], spawns.size() * 2, "原生 + 参考各回调一次/弹")


# ═══════════════════════════════════════════════ 组合（V1 回归）═══
# 之前每个原语单独 parity，覆盖不到「同相位多个有状态初始化 unit」；V1 共享 fresh 的 bug 因此漏网。
# 下面这条既是行为回归（原生），也做原生↔参考 parity（防止两边再次分叉）。

func _run_behavior_full(store, lc: BulletLifecycle, start: Vector2, vel: Vector2, frames: int, player: Vector2 = Vector2.ZERO) -> Dictionary:
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(start, vel, 0, 0, Color.WHITE)
	store.set_program(id, pid)
	for _f in frames:
		store.integrate(DT)
		store.behavior_tick(DT, player, Vector2.ZERO, false, PackedVector2Array())
	return {&"pos": store.get_position(id), &"vel": store.get_velocity(id)}


func _run_behavior(store, lc: BulletLifecycle, start: Vector2, vel: Vector2, frames: int, player: Vector2 = Vector2.ZERO) -> Vector2:
	return _run_behavior_full(store, lc, start, vel, frames, player)[&"pos"]


func test_combo_two_drifts_do_not_collide() -> void:
	## V1 回归：同相位两个 drift 各自按自己的槽判「相位首帧」。
	## 旧实现共享一个 per-bullet fresh → 第二个 drift 的起点槽未初始化 → 首帧瞬移到原点附近。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 100.0)     # 向上
	lc.drift(PI, 100.0)      # 向下（后写者覆盖位置：结果 = 从各自相位起点向下）
	lc.until_never()
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(64, CULL); store.set_margin(0.0); store.set_default_life(100.0)
	store.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)

	var p0: Vector2 = _run_behavior(store, lc, Vector2(500.0, 500.0), Vector2(0, -50), 1)
	assert_almost_eq(p0.x, 500.0, 0.5, "首帧 x 不应被冲到原点")
	assert_almost_eq(p0.y, 500.0 - 50.0 * DT, 0.5, "首帧两个 drift initial 都是 0 → 只应保留积分位移（旧实现落在 y≈1.67）")

	var p1: Vector2 = _run_behavior(store, lc, Vector2(500.0, 500.0), Vector2(0, -50), 2)
	assert_almost_eq(p1.y, 500.0 + 50.0 * DT, 0.5, "第 2 帧应由后写者（向下）从它的相位起点推进")
	pass_test("同相位双 drift 不互踩")


func test_combo_drift_drift_parity_native_reference() -> void:
	## 同一条双 drift 描述符在原生与参考解释器逐步一致（修复后两边都按槽判 fresh）。
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 100.0)
	lc.drift(PI, 100.0)
	lc.until_never()
	_parity("combo:drift+drift", lc, 60, _spread(4, 400.0), BehaviorContext.new())


func _combo_store():
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(64, CULL); store.set_margin(0.0); store.set_default_life(100.0)
	store.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
	return store


func test_combo_drift_plus_anchor_drift() -> void:
	## 同相位 drift + anchor_drift：两者都写位置（anchor_drift 后写覆盖），但 fresh 必须按槽独立。
	## 旧共享 fresh：drift 先跑会吞掉标志 → anchor_drift 首帧 initial 被跳过（多漂一步）。
	if not _available(): pending("未构建原生扩展"); return
	var player := Vector2(300.0, 400.0)
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 100.0)
	lc.anchor_drift(0, Vector2.ZERO, PI, 50.0, false, 0.0, false)
	lc.until_never()
	var store = _combo_store()

	var f0: Dictionary = _run_behavior_full(store, lc, Vector2(500.0, 500.0), Vector2(0, -50), 1, player)
	assert_almost_eq((f0[&"pos"] as Vector2).x, player.x, 0.2, "首帧 x 应正好是锚点")
	assert_almost_eq((f0[&"pos"] as Vector2).y, player.y, 0.2, "anchor_drift 首帧 initial=0 → 不应被 drift 抢先消费 fresh 而多漂 50·dt")
	var f1: Dictionary = _run_behavior_full(store, lc, Vector2(500.0, 500.0), Vector2(0, -50), 2, player)
	assert_almost_eq((f1[&"pos"] as Vector2).y, player.y + 50.0 * DT, 0.2, "第 2 帧 anchor_drift 从自己的相位起点推进")
	pass_test("同相位 drift + anchor_drift 各自 fresh")


func test_combo_drift_anchor_drift_parity_native_reference() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(300.0, 400.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 100.0)
	lc.anchor_drift(0, Vector2.ZERO, PI, 50.0, false, 0.0, false)
	lc.until_never()
	_parity("combo:drift+anchor_drift", lc, 60, _spread(4, 400.0), ctx, player.global_position)


func test_combo_steer_speed_lerp() -> void:
	## steer 只转向、speed_lerp 管速度：组合时速度严格按 lerp，方向被 steer 转过去。
	if not _available(): pending("未构建原生扩展"); return
	var player := Vector2(700.0, 800.0)
	var lc := BulletLifecycle.new()
	lc.speed_lerp(100.0, 300.0, 1.0)
	lc.steer(BulletLifecycle.T_PLAYER, deg_to_rad(360.0), 0.0, 0.0, 0.0)
	lc.until_never()
	var out: Dictionary = _run_behavior_full(_combo_store(), lc, Vector2(448.0, 800.0), Vector2(0, -100), 30, player)
	var vel: Vector2 = out[&"vel"]
	assert_almost_eq(vel.length(), 200.0, 2.0, "ramp=1s，30 帧(0.5s) 后速度应为 100→300 的中点 200")
	assert_lt(absf(vel.angle_to(Vector2(1.0, 0.0))), 0.15, "steer 应把方向转向自机（右侧）")
	pass_test("steer + speed_lerp 组合")


func test_position_op_is_unified() -> void:
	## V18：anchor_drift / drift 都编译成同一个 M_POSITION op（mode 不同），不再各占一个 op。
	var d := BulletLifecycle.new()
	d.drift(0.0, 10.0)
	d.until_never()
	assert_eq(d.compile()["ops"][0], BulletLifecycle.OP_M_POSITION, "drift = M_POSITION")
	var a := BulletLifecycle.new()
	a.anchor_drift(0, Vector2.ZERO, 0.0, 10.0)
	a.until_never()
	assert_eq(a.compile()["ops"][0], BulletLifecycle.OP_M_POSITION, "anchor_drift = M_POSITION")
	pass_test("位置来源统一为一个 op")


func test_combo_position_mode_preserves_velocity() -> void:
	## V18 过渡语义：position 模式只写 pos、不碰 v；相位结束后按速度轴原样接力。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.drift(PI * 0.5, 100.0)      # 向右平移
	lc.until_elapsed(0.32)
	lc.then()
	lc.until_never()
	var out: Dictionary = _run_behavior_full(_combo_store(), lc, Vector2(400.0, 500.0), Vector2(0, -120.0), 40)
	assert_true((out[&"vel"] as Vector2).is_equal_approx(Vector2(0, -120)), "position 模式不得改写 velocity")
	assert_gt((out[&"pos"] as Vector2).x, 400.0, "相位 1 应向右刚性平移")
	pass_test("position 模式释放后按速度轴飞")


func test_position_render_heading_uses_render_channel() -> void:
	## V19：render_heading 只写独立 render_rot 通道；velocity 保持（不再借道）。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.anchor_drift(0, Vector2.ZERO, 0.0, 800.0, false, 0.0, true)   # render_heading=true
	lc.until_never()
	var store = _combo_store()
	var c: Dictionary = lc.compile()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	var id: int = store.spawn(Vector2(100.0, 100.0), Vector2(0, -50), 0, 0, Color.WHITE)
	store.set_program(id, pid)
	store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(store.get_velocity(id).is_equal_approx(Vector2(0, -50)), "render_heading 不得改写 velocity")
	# angle=0 → adir=(0,-1) → atan2(adir_y, adir_x) = -PI/2
	assert_almost_eq(store.get_render_rots()[id], -PI / 2.0, 1e-3, "render_rot 应为漂移方向角")
	pass_test("render_heading 走独立渲染通道")


func test_combo_slot_budget_overflow_rejected() -> void:
	## V20：固定 stride=8。3 个 drift = 9 槽 → 原生拒绝注册（返回 -1），不再静默越界串行。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	lc.drift(0.0, 90.0)
	lc.drift(0.0, 30.0)
	lc.drift(0.0, 10.0)
	lc.until_never()
	assert_eq(lc.slots, 9, "3 个 drift 应占 9 槽")
	var c: Dictionary = lc.compile()
	var store = _combo_store()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	assert_eq(pid, -1, "超过 SLOT_STRIDE 的 program 应被拒绝（返回 -1）")
	pass_test("超槽 program 被拒绝")


func test_combo_slot_budget_at_limit_ok() -> void:
	## 恰好 8 槽仍可用（8 个 rotate 各占 1 槽）。
	if not _available(): pending("未构建原生扩展"); return
	var lc := BulletLifecycle.new()
	for _i in 8:
		lc.rotate(0.1, 0.0)
	lc.until_never()
	assert_eq(lc.slots, 8, "8 个 rotate 应占 8 槽")
	var c: Dictionary = lc.compile()
	var store = _combo_store()
	var pid: int = store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	assert_true(pid >= 0, "恰好 8 槽应被接受")
	pass_test("8 槽边界可用")


func test_combo_steer_is_angle_only() -> void:
	## V2：steer 不接管速度 —— 单独使用时速度大小必须原样保持。
	if not _available(): pending("未构建原生扩展"); return
	var player := Vector2(700.0, 800.0)
	var lc := BulletLifecycle.new()
	lc.steer(BulletLifecycle.T_PLAYER, deg_to_rad(360.0), 0.0, 0.0, 0.0)
	lc.until_never()
	var out: Dictionary = _run_behavior_full(_combo_store(), lc, Vector2(448.0, 800.0), Vector2(0, -123.4), 30, player)
	var vel: Vector2 = out[&"vel"]
	assert_almost_eq(vel.length(), 123.4, 0.5, "steer 只转向：速度大小必须保持")
	assert_lt(absf(vel.angle_to(Vector2(1.0, 0.0))), 0.15, "方向应转向自机")
	pass_test("steer 是纯角转向")


func test_combo_steer_speed_lerp_parity_native_reference() -> void:
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.speed_lerp(100.0, 300.0, 1.0)
	lc.steer(BulletLifecycle.T_PLAYER, deg_to_rad(360.0), 0.0, 0.0, 0.0)
	lc.until_never()
	_parity("combo:steer+speed_lerp", lc, 45, _spread(4, 200.0), ctx, player.global_position)


func test_combo_cross_phase_slots_reset_parity() -> void:
	## 两段各自 rotate 独立槽：相位切换清零槽 + 重置 fresh。原生↔参考逐帧一致。
	# limit 取 0.62（0.31s ≈ 18.6 帧）：避开 k/60 帧边界，否则原生 32 位与参考 64 位会在
	# 「刚好到达 limit」的那一帧各差一帧（existing test_primitive_until_turned 同款取值）。
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.62)
	lc.until_turned()
	lc.then()
	lc.rotate(2.0, 0.62)
	lc.until_turned()
	lc.despawn()
	_parity("combo:phase-reset", lc, 90, _spread(4, 400.0), BehaviorContext.new())
