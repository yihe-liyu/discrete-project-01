## LifecycleBehavior —— BulletLifecycle 描述符的 GDScript 参考解释器（L1.5）。
##
## 见 docs/LIFECYCLE_MODEL.md §3。它是 Behavior 的一个 tenant：从 params.lifecycle 取描述符。
## 状态**显式**：每弹一个 slots 数组（由 builder 按相位自动分配），相位切换清零 →
## unit 组合不互相污染。L3 由原生执行器替换（schema 不变）。
class_name LifecycleBehavior
extends Behavior

const LIFECYCLE_HOOKS_SCRIPT = preload("res://scripts/kernel_bridge/lifecycle/lifecycle_hooks.gd")

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
	# V1：fresh 是「每槽一个 bool」，不是「每弹一个 bool」——同相位的多个有状态 unit
	# （anchor_drift / drift）各自按自己的槽判相位首帧，互不消费。
	var fresh := []
	fresh.resize(count)
	fresh.fill(true)
	return {
		&"phase": 0,
		&"elapsed": 0.0,
		&"slots": slots,
		&"end_pos": Vector2.ZERO,
		&"has_end_pos": false,
		&"next_check": 0.0,
		&"tick": 0,
		&"fresh": fresh,
	}


func _enter_phase(st: Dictionary, phase: int) -> void:
	st[&"phase"] = phase
	st[&"elapsed"] = 0.0
	st[&"end_pos"] = Vector2.ZERO
	st[&"has_end_pos"] = false
	st[&"next_check"] = 0.0
	var slots: Array = st[&"slots"]
	var fresh: Array = st[&"fresh"]
	for i in slots.size():
		slots[i] = 0.0
		fresh[i] = true


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
			# V12：mode=2（只转朝向）参考侧无朝向可转 → 速度不动；0/1 都转速度。
			if int(mv[&"mode"]) != BulletLifecycle.ROT_HEADING:
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
				# V2：steer 只转向、不改速度（速度交给 speed_lerp / set_speed）。
				system.set_velocity(id, rotated * vel.length())
		BulletLifecycle.M_SPEED_LERP:
			var ramp2: float = float(mv[&"ramp"])
			var f2: float = 1.0 if ramp2 <= 0.0 else clampf(float(st[&"elapsed"]) / ramp2, 0.0, 1.0)
			var d2 := system.get_velocity(id).normalized()
			if d2 != Vector2.ZERO:
				system.set_velocity(id, d2 * lerpf(float(mv[&"from"]), float(mv[&"to"]), f2))
		BulletLifecycle.M_SPEED_MUL:
			system.set_velocity(id, system.get_velocity(id) * float(mv[&"f"]))
		BulletLifecycle.M_SET_HEADING:
			var d3 := _dir(mv[&"dir"], system.get_position(id), ctx)
			if d3 != Vector2.ZERO:
				system.set_velocity(id, d3 * system.get_velocity(id).length())
		BulletLifecycle.M_SET_SPEED:
			var d4 := system.get_velocity(id).normalized()
			if d4 == Vector2.ZERO:
				d4 = Vector2(0, 1)   # V15：参考侧无朝向，用零速出生的默认朝向 (0,1) 近似
			system.set_velocity(id, d4 * float(mv[&"speed"]))
		BulletLifecycle.M_POSITION:
			# V18：位置来源统一（mode 0=PHASE_START / 1=ANCHOR）；只有本 op 写 pos。
			var mode: int = int(mv[&"mode"])
			var slot: int = int(mv[&"slot"])
			var slots2: Array = st[&"slots"]
			var fresh2: Array = st[&"fresh"]
			var base: Vector2
			if mode == BulletLifecycle.POS_PHASE_START:
				var bx: int = int(mv[&"sx"])
				var by: int = int(mv[&"sy"])
				if bool(fresh2[slot]):        # V1：按槽判 fresh
					slots2[bx] = system.get_position(id).x   # 首帧：记下相位起点
					slots2[by] = system.get_position(id).y
					slots2[slot] = float(mv[&"initial"])
					fresh2[slot] = false
				else:
					slots2[slot] = float(slots2[slot]) + float(mv[&"speed"]) * dt
				base = Vector2(float(slots2[bx]), float(slots2[by]))
			else:
				base = _anchor_pos(int(mv[&"anchor_id"]), Vector2(mv[&"offset"]), bool(mv[&"use_global"]), ctx)
				if bool(fresh2[slot]):
					slots2[slot] = float(mv[&"initial"])
					fresh2[slot] = false
				else:
					slots2[slot] = float(slots2[slot]) + float(mv[&"speed"]) * dt
			var adir := Vector2(sin(float(mv[&"angle"])), -cos(float(mv[&"angle"])))
			system.set_position(id, base + adir * float(slots2[slot]))
			# V19：render_heading 不再写 velocity（原生走独立 render_rot 通道；参考侧无渲染，不模拟）。
		_:
			push_warning("LifecycleBehavior: 未知 move '%s'" % mv[&"op"])


func _check_until(system: BulletSystem, id: int, st: Dictionary, cond: Dictionary, ctx: BehaviorContext) -> bool:
	# V6：通用节流（先帧门控，再秒节流），对所有条件一致。
	var every_ticks: int = int(cond.get(&"every_ticks", 0))
	if every_ticks > 0 and int(st[&"tick"]) % every_ticks != 0:
		return false
	var every: float = float(cond.get(&"every", 0.0))
	if every > 0.0:
		if float(st[&"elapsed"]) < float(st[&"next_check"]):
			return false
		st[&"next_check"] = float(st[&"elapsed"]) + every
	match cond[&"op"]:
		BulletLifecycle.C_NEVER:
			return false
		BulletLifecycle.C_ELAPSED:
			return float(st[&"elapsed"]) >= float(cond[&"t"])
		BulletLifecycle.C_NEAR:
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
			var si: int = int(cond[&"slot"])
			var slots: Array = st[&"slots"]
			if si < 0 or si >= slots.size():   # V8：slot 边界守卫
				return false
			var sv: float = float(slots[si])
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
			BulletLifecycle.A_EMIT_VARIANT:
				# V9：参考侧不模拟随机/分支 → 取未命中分支 spawns[0]；方向用 forward（参考 _dir 回退 DOWN）。
				var spawns_ref: Array = act.get(&"spawns", [])
				if not spawns_ref.is_empty():
					var synthetic := {
						&"spawn": spawns_ref[0],
						&"dir": BulletLifecycle.forward(),
						&"speed": act.get(&"speed", 0.0),
						&"at": act.get(&"at", 0),
					}
					_do_emit(system, id, st, synthetic, ctx)
			BulletLifecycle.A_DESPAWN:
				system.request_despawn(id)
			BulletLifecycle.A_SET_HEADING:
				var d := _dir(act[&"dir"], system.get_position(id), ctx)
				if d != Vector2.ZERO:
					system.set_velocity(id, d * system.get_velocity(id).length())
			BulletLifecycle.A_SET_SPEED:
				var d2 := system.get_velocity(id).normalized()
				if d2 == Vector2.ZERO:
					d2 = Vector2(0, 1)   # V15
				system.set_velocity(id, d2 * float(act[&"speed"]))
			BulletLifecycle.A_CALL:
				_call(act[&"call"], system, id, ctx)


func _do_emit(system: BulletSystem, id: int, st: Dictionary, act: Dictionary, ctx: BehaviorContext) -> void:
	var at: Vector2 = system.get_position(id)
	if int(act.get(&"at", 0)) == 1 and bool(st[&"has_end_pos"]):   # V7：at = AT_PHASE_END
		at = Vector2(st[&"end_pos"])
	var speed: float = system.get_velocity(id).length()
	if float(act[&"speed"]) > 0.0:
		speed = float(act[&"speed"])
	var dir: Vector2 = _dir(act[&"dir"], at, ctx)
	var spawn: Variant = act.get(&"spawn", act.get(&"factory", null))
	if spawn != null and host != null and host.has_method("queue_spawn"):
		var b = spawn.call() if spawn is Callable else spawn
		if b != null:
			b.velocity = Vector2(0, speed)
			host.queue_spawn(b, at, dir)


# ── 内容回调（一次性、低频）──
func _call(hook: Variant, system: BulletSystem, id: int, _ctx: BehaviorContext) -> void:
	var fn: Callable = hook if hook is Callable else LIFECYCLE_HOOKS_SCRIPT.resolve(hook)
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
			# V14：只取「宿主提供的候选集」里最近的一个；targetability 策略归宿主
			# （EntityRegistry.get_targetable_enemies → Enemy.is_targetable），内核不内嵌过滤。
			var best: Node2D = null
			var bd := INF
			for e in ctx.get_world().get_enemies():
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
			# NOTE：参考解释器**不模拟**"自身朝向"（K2）与随机（K1）—— 这两个是原生专属；
			# 用到它们的组合不走 parity 测试（见 test_heading_state / test_kernel_random）。
			return Vector2.DOWN


func _anchor_pos(anchor_id: int, offset: Vector2, use_global: bool, ctx: BehaviorContext) -> Vector2:
	return BulletLifecycle.anchor_base(anchor_id, offset, use_global, ctx.get_player_position())


func _boss():
	return host.get_boss() if host != null and host.has_method("get_boss") else null