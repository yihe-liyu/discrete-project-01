## LifecycleBehavior —— BulletLifecycle 描述符的 GDScript 参考解释器（L1.5）。
##
## 见 docs/LIFECYCLE_MODEL.md §3。它是 Behavior 的一个 tenant：从 params.lifecycle 取描述符。
## 状态**显式**：每弹一个 slots 数组（由 builder 按相位自动分配），相位切换清零 →
## unit 组合不互相污染。L3 由原生执行器替换（schema 不变）。
class_name LifecycleBehavior
extends Behavior

## KernelBehaviorHost 或测试假体（emit / sfx 用）。
var host


func process(system: BulletSystem, bullet_id: int, ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var lc = params.get(&"lifecycle", null)
	if lc == null:
		return
	var st: Variant = system.get_behavior_state(bullet_id)
	if not (st is Dictionary):
		st = _new_state(lc)
		system.set_behavior_state(bullet_id, st)
	var phases: Array = lc.phases
	var pi: int = int(st[&"phase"])
	if pi >= phases.size():
		return
	var phase: Dictionary = phases[pi]
	var dt: float = system.get_delta()
	st[&"tick"] = int(st[&"tick"]) + 1
	st[&"elapsed"] = float(st[&"elapsed"]) + dt
	for mv in phase[&"moves"]:
		_apply_move(system, bullet_id, st, mv, dt, ctx)
	if _check_until(system, bullet_id, st, phase[&"until"], ctx):
		_run_actions(system, bullet_id, st, phase[&"on_end"], ctx)
		_enter_phase(st, pi + 1)


func _new_state(lc) -> Dictionary:
	var count: int = int(lc.slots)
	var slots := []
	slots.resize(count)
	slots.fill(0.0)
	return {
		&"phase": 0,
		&"elapsed": 0.0,
		&"slots": slots,
		&"end_pos": Vector2.ZERO,
		&"has_end_pos": false,
		&"next_check": 0.0,
		&"tick": 0,
		&"fresh": true,
	}


func _enter_phase(st: Dictionary, phase: int) -> void:
	st[&"phase"] = phase
	st[&"elapsed"] = 0.0
	st[&"end_pos"] = Vector2.ZERO
	st[&"has_end_pos"] = false
	st[&"next_check"] = 0.0
	st[&"fresh"] = true
	var slots: Array = st[&"slots"]
	for i in slots.size():
		slots[i] = 0.0


func _apply_move(system: BulletSystem, id: int, st: Dictionary, mv: Dictionary, dt: float, ctx: BehaviorContext) -> void:
	match mv[&"op"]:
		BulletLifecycle.M_ACCEL_WORLD:
			system.set_velocity(id, system.get_velocity(id) + Vector2(mv[&"vec"]) * dt)
		BulletLifecycle.M_ACCEL_HEADING:
			var v := system.get_velocity(id)
			var dir := v.normalized()
			if dir != Vector2.ZERO:
				system.set_velocity(id, v + dir * float(mv[&"a"]) * dt)
		BulletLifecycle.M_ROTATE:
			var slots: Array = st[&"slots"]
			var si: int = int(mv[&"slot"])
			var turned: float = float(slots[si])
			var step: float = float(mv[&"w"]) * dt
			var limit: float = float(mv[&"limit"])
			if limit > 0.0:
				var remain: float = limit - turned
				if remain <= 0.0:
					return
				step = clampf(step, -remain, remain)
			slots[si] = turned + absf(step)
			system.set_velocity(id, system.get_velocity(id).rotated(step))
		BulletLifecycle.M_STEER:
			var from := system.get_position(id)
			var vel := system.get_velocity(id)
			var cur := vel.normalized()
			if cur != Vector2.ZERO:
				var ramp: float = float(mv[&"ramp"])
				var factor: float = 1.0 if ramp <= 0.0 else clampf(float(st[&"elapsed"]) / ramp, 0.0, 1.0)
				var rotated := cur
				var steer_until: float = float(mv[&"steer_until"])
				var can_steer: bool = steer_until <= 0.0 or float(st[&"elapsed"]) <= steer_until
				var tp = _target_pos(mv[&"target"], from, ctx) if can_steer else null
				if tp != null:
					var diff: Vector2 = tp - from
					var dist: float = maxf(diff.length(), 1.0)
					var dw: float = 1.0
					var dist_weight: float = float(mv[&"dist_weight"])
					if dist_weight > 0.0:
						dw = 1.0 + dist_weight / (dist + dist_weight)
					var max_turn: float = float(mv[&"max_turn"]) * factor * dw * dt
					rotated = cur.rotated(clampf(cur.angle_to(diff / dist), -max_turn, max_turn))
				var sf: float = float(mv[&"speed_from"])
				if is_nan(sf):
					system.set_velocity(id, rotated * vel.length())
				else:
					system.set_velocity(id, rotated * lerpf(sf, float(mv[&"speed_to"]), factor))
		BulletLifecycle.M_SPEED_LERP:
			var ramp2: float = float(mv[&"ramp"])
			var f2: float = 1.0 if ramp2 <= 0.0 else clampf(float(st[&"elapsed"]) / ramp2, 0.0, 1.0)
			var d2 := system.get_velocity(id).normalized()
			if d2 != Vector2.ZERO:
				system.set_velocity(id, d2 * lerpf(float(mv[&"from"]), float(mv[&"to"]), f2))
		BulletLifecycle.M_SCALE_SPEED:
			system.set_velocity(id, system.get_velocity(id) * float(mv[&"f"]))
		BulletLifecycle.M_SET_HEADING:
			var d3 := _dir(mv[&"dir"], system.get_position(id), ctx)
			if d3 != Vector2.ZERO:
				system.set_velocity(id, d3 * system.get_velocity(id).length())
		BulletLifecycle.M_SET_SPEED:
			var d4 := system.get_velocity(id).normalized()
			if d4 != Vector2.ZERO:
				system.set_velocity(id, d4 * float(mv[&"speed"]))
		BulletLifecycle.M_ANCHOR_DRIFT:
			var base := _anchor_pos(int(mv[&"anchor_id"]), Vector2(mv[&"offset"]), bool(mv[&"use_global"]), ctx)
			var slots2: Array = st[&"slots"]
			var si2: int = int(mv[&"slot"])
			if bool(st[&"fresh"]):
				slots2[si2] = float(mv[&"initial"])   # 首帧：初始漂移，不推进（与 laser_follow 1:1）
				st[&"fresh"] = false
			else:
				slots2[si2] = float(slots2[si2]) + float(mv[&"speed"]) * dt
			var adir := Vector2(sin(float(mv[&"angle"])), -cos(float(mv[&"angle"])))
			system.set_position(id, base + adir * float(slots2[si2]))
			if bool(mv[&"render_heading"]):
				system.set_velocity(id, adir)
		_:
			push_warning("LifecycleBehavior: 未知 move '%s'" % mv[&"op"])


func _check_until(system: BulletSystem, id: int, st: Dictionary, cond: Dictionary, ctx: BehaviorContext) -> bool:
	match cond[&"op"]:
		BulletLifecycle.C_NEVER:
			return false
		BulletLifecycle.C_ELAPSED:
			return float(st[&"elapsed"]) >= float(cond[&"t"])
		BulletLifecycle.C_NEAR:
			var every_ticks: int = int(cond[&"every_ticks"])
			if every_ticks > 0 and int(st[&"tick"]) % every_ticks != 0:
				return false
			var every: float = float(cond[&"every"])
			if every > 0.0:
				if float(st[&"elapsed"]) < float(st[&"next_check"]):
					return false
				st[&"next_check"] = float(st[&"elapsed"]) + every
			var tp = _target_pos(cond[&"target"], system.get_position(id), ctx)
			if tp == null:
				return false
			return system.get_position(id).distance_to(tp) < float(cond[&"r"])
		BulletLifecycle.C_AT_WALL:
			var mask: int = int(cond[&"mask"])
			var pos := system.get_position(id)
			var clamped := pos
			if (mask & BulletLifecycle.WALL_LEFT) and pos.x <= GameConfig.FIELD_LEFT:
				clamped.x = GameConfig.FIELD_LEFT
			elif (mask & BulletLifecycle.WALL_RIGHT) and pos.x >= GameConfig.FIELD_RIGHT:
				clamped.x = GameConfig.FIELD_RIGHT
			if (mask & BulletLifecycle.WALL_TOP) and pos.y <= GameConfig.FIELD_TOP:
				clamped.y = GameConfig.FIELD_TOP
			if clamped != pos:
				st[&"end_pos"] = clamped
				st[&"has_end_pos"] = true
				return true
			return false
		BulletLifecycle.C_STATE:
			var sv: float = float(st[&"slots"][int(cond[&"slot"])])
			return sv >= float(cond[&"value"]) if int(cond[&"cmp"]) == BulletLifecycle.CMP_GE else sv <= float(cond[&"value"])
		_:
			return false


func _run_actions(system: BulletSystem, id: int, st: Dictionary, actions: Array, ctx: BehaviorContext) -> void:
	for act in actions:
		match act[&"op"]:
			BulletLifecycle.A_SFX:
				if act[&"key"] != &"" and host != null and host.has_method("play_sfx"):
					host.play_sfx(act[&"key"], float(act[&"db"]))
			BulletLifecycle.A_EMIT:
				_do_emit(system, id, st, act, ctx)
			BulletLifecycle.A_DESPAWN:
				system.request_despawn(id)
			BulletLifecycle.A_SET_HEADING:
				var d := _dir(act[&"dir"], system.get_position(id), ctx)
				if d != Vector2.ZERO:
					system.set_velocity(id, d * system.get_velocity(id).length())
			BulletLifecycle.A_SET_SPEED:
				var d2 := system.get_velocity(id).normalized()
				if d2 != Vector2.ZERO:
					system.set_velocity(id, d2 * float(act[&"speed"]))
			BulletLifecycle.A_CALL:
				_call(act[&"fn"], system, id, ctx)


func _do_emit(system: BulletSystem, id: int, st: Dictionary, act: Dictionary, ctx: BehaviorContext) -> void:
	var at: Vector2 = system.get_position(id)
	if bool(act[&"at_end"]) and bool(st[&"has_end_pos"]):
		at = Vector2(st[&"end_pos"])
	var speed: float = system.get_velocity(id).length()
	if float(act[&"speed"]) > 0.0:
		speed = float(act[&"speed"])
	var dir: Vector2 = _dir(act[&"dir"], at, ctx)
	var factory: Callable = act.get(&"factory", Callable())
	if factory.is_valid() and host != null and host.has_method("queue_spawn"):
		var b = factory.call()
		if b != null:
			b.velocity = Vector2(0, speed)
			host.queue_spawn(b, at, dir)


# ── 内容回调（一次性、低频）──
func _call(fn: Callable, system: BulletSystem, id: int, _ctx: BehaviorContext) -> void:
	if not fn.is_valid():
		return
	var boss = _boss()
	var has_boss: bool = is_instance_valid(boss)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	fn.call(system.get_position(id), boss_pos, has_boss, host)


# ── 目标 / 方向 / 锚点 ──
func _target_pos(target: StringName, from: Vector2, ctx: BehaviorContext) -> Variant:
	match target:
		BulletLifecycle.T_PLAYER:
			return ctx.get_player_position()
		BulletLifecycle.T_BOSS:
			var boss = _boss()
			return boss.global_position if is_instance_valid(boss) else null
		BulletLifecycle.T_NEAREST_ENEMY:
			# 与 homing_behavior._nearest_enemy 1:1：跳过时符 / 未开战 Boss。
			var best: Node2D = null
			var bd := INF
			for e in ctx.get_world().get_enemies():
				if e is Boss:
					var ph: PhaseData = (e as Boss).current_phase()
					if not ph or ph.is_timeout_only:
						continue
				var d2: float = from.distance_squared_to(e.global_position)
				if d2 < bd:
					bd = d2
					best = e
			if best == null:
				return null
			return best.global_position
		_:
			return null


func _dir(spec: Dictionary, pos: Vector2, ctx: BehaviorContext) -> Vector2:
	var angle: float = float(spec[&"angle"])
	match spec[&"kind"]:
		BulletLifecycle.D_HEADING:
			return Vector2(sin(angle), -cos(angle))
		BulletLifecycle.D_TOWARD:
			var tp = _target_pos(spec[&"target"], pos, ctx)
			var base: Vector2 = (tp - pos).normalized() if tp != null else Vector2.DOWN
			return base.rotated(angle)
		BulletLifecycle.D_AWAY:
			var tp2 = _target_pos(spec[&"target"], pos, ctx)
			var base2: Vector2 = (pos - tp2).normalized() if tp2 != null else Vector2.DOWN
			return base2.rotated(angle)
		_:
			return Vector2.DOWN


func _anchor_pos(anchor_id: int, offset: Vector2, use_global: bool, ctx: BehaviorContext) -> Vector2:
	return BulletLifecycle.anchor_base(anchor_id, offset, use_global, ctx.get_player_position())


func _boss():
	return host.get_boss() if host != null and host.has_method("get_boss") else null