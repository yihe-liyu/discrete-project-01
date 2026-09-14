extends GutTest
## 最小原语覆盖（9 Move / 5 Until / 5 Action）—— 每个原语一条最小 lifecycle，
## 与参考解释器 LifecycleBehavior 逐位对照。它同时是「原语能干什么」的活文档。
##
## 为什么单独一份：预设级 parity 只覆盖"被 preset 用到"的原语。实测 9 个 Move 里有 4 个
## （speed_lerp / scale_speed / set_heading / set_speed）**没有任何 preset 使用 → 零覆盖**。
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


func test_primitive_move_speed_lerp() -> void:
	## 速度在 ramp 秒内从 from 线性插值到 to（沿当前朝向）。
	var lc := BulletLifecycle.new()
	lc.speed_lerp(120.0, 320.0, 1.0)
	lc.until_elapsed(1.52)
	_parity("move:speed_lerp", lc, 90, _spread(4, 400.0), BehaviorContext.new())


func test_primitive_move_scale_speed() -> void:
	## 速度乘 f（**每帧**乘，故会复利）。
	var lc := BulletLifecycle.new()
	lc.scale_speed(1.05)
	lc.until_elapsed(0.52)
	_parity("move:scale_speed", lc, 30, _spread(4, 400.0), BehaviorContext.new())


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
	## 转向目标（这里自机）+ 可选速度爬升。转向是反馈环 → 在浮点尚未放大的地平线内对照。
	var player: Node2D = add_child_autofree(Node2D.new())
	player.position = Vector2(448.0, 500.0)
	var ctx := BehaviorContext.new()
	ctx.setup(player)
	var lc := BulletLifecycle.new()
	lc.steer(BulletLifecycle.T_PLAYER, deg_to_rad(360.0), 1.0, 0.0, 150.0, 300.0, 0.0)
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


func test_primitive_until_state() -> void:
	## 状态槽与常量比较（这里：rotate 的槽 0 累计转角 >= 0.4 弧度）。
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.42)
	lc.until_state(0, BulletLifecycle.CMP_GE, 0.42)
	lc.despawn()
	_parity("until:state", lc, 60, _spread(4, 400.0), BehaviorContext.new())


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
	lc.emit(factory, BulletLifecycle.heading(0.0), 200.0, false)
	_parity("action:emit", lc, 40, _spread(4, 400.0), BehaviorContext.new())


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
