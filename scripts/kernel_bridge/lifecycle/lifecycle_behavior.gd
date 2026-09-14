## LifecycleBehavior —— BulletLifecycle 描述符的 GDScript 参考解释器（L1）。
##
## 见 docs/LIFECYCLE_MODEL.md §3。它是 Behavior 的一个 tenant：从 params.lifecycle 取描述符，
## 在当前相位施加 moves，判定 until，成立则跑 on_end 动作并进入下一相位。
## L3 由原生执行器替换（schema 不变）；本文件随 GDScript 行为在 L4 删除。
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
		st = {
			&"phase": 0,
			&"turned": 0.0,
			&"elapsed": 0.0,
			&"drift": float(params.get(&"initial_drift", 0.0)),
			&"hit_pos": null,
		}
		system.set_behavior_state(bullet_id, st)
	var phases: Array = lc.phases
	var pi: int = int(st[&"phase"])
	if pi >= phases.size():
		return
	var phase: Dictionary = phases[pi]
	var dt: float = system.get_delta()
	st[&"elapsed"] = float(st[&"elapsed"]) + dt
	for mv in phase[&"moves"]:
		_apply_move(system, bullet_id, st, mv, dt, ctx)
	if _check_until(system, bullet_id, st, phase[&"until"], ctx):
		_run_actions(system, bullet_id, st, phase[&"on_end"], ctx)
		st[&"phase"] = pi + 1


func _apply_move(system: BulletSystem, id: int, st: Dictionary, mv: Dictionary, dt: float, ctx: BehaviorContext) -> void:
	match mv[&"kind"]:
		BulletLifecycle.M_ACCEL_WORLD:
			system.set_velocity(id, system.get_velocity(id) + Vector2(mv[&"vec"]) * dt)
		BulletLifecycle.M_ACCEL_ALONG_VEL:
			var v := system.get_velocity(id)
			var dir := v.normalized()
			if dir != Vector2.ZERO:
				system.set_velocity(id, v + dir * float(mv[&"a"]) * dt)
		BulletLifecycle.M_ROTATE:
			var turned: float = float(st[&"turned"])
			var step: float = float(mv[&"w"]) * dt
			var limit: float = float(mv[&"limit"])
			if limit > 0.0:
				var remain: float = limit - turned
				if remain <= 0.0:
					return
				step = clampf(step, -remain, remain)
			st[&"turned"] = turned + absf(step)
			system.set_velocity(id, system.get_velocity(id).rotated(step))
		BulletLifecycle.M_SET_VEL:
			system.set_velocity(id, Vector2(mv[&"dir"]).normalized() * float(mv[&"speed"]))
		BulletLifecycle.M_SCALE:
			system.set_velocity(id, system.get_velocity(id) * float(mv[&"f"]))
		BulletLifecycle.M_SPEED_RAMP:
			var t: float = 1.0 if float(mv[&"time"]) <= 0.0 else clampf(float(st[&"elapsed"]) / float(mv[&"time"]), 0.0, 1.0)
			var d := system.get_velocity(id).normalized()
			if d != Vector2.ZERO:
				system.set_velocity(id, d * lerpf(float(mv[&"min"]), float(mv[&"top"]), t))
		BulletLifecycle.M_AIM:
			var from := system.get_position(id)
			var target: Node2D = ctx.get_world().get_nearest_enemy(from)
			if target != null:
				var vel := system.get_velocity(id)
				var cur := vel.normalized()
				if cur != Vector2.ZERO:
					var diff: Vector2 = target.global_position - from
					var dist: float = maxf(diff.length(), 1.0)
					var dw: float = 1.0 if float(mv[&"dist_weight"]) <= 0.0 else 1.0 + float(mv[&"dist_weight"]) / (dist + float(mv[&"dist_weight"]))
					var max_turn: float = float(mv[&"max_turn"]) * dw * dt
					var turn: float = clampf(cur.angle_to(diff / dist), -max_turn, max_turn)
					system.set_velocity(id, cur.rotated(turn) * vel.length())
		BulletLifecycle.M_ANCHOR:
			var anchor: Vector2 = ctx.get_player_position()
			if int(mv[&"anchor_id"]) != 0:
				var node: Object = instance_from_id(int(mv[&"anchor_id"]))
				if node is Node2D:
					anchor = (node as Node2D).global_position if bool(mv[&"use_global"]) else (node as Node2D).position
			anchor += Vector2(mv[&"offset"])
			var adir := Vector2(sin(float(mv[&"angle"])), -cos(float(mv[&"angle"])))
			st[&"drift"] = float(st[&"drift"]) + float(mv[&"drift"]) * dt
			system.set_position(id, anchor + adir * float(st[&"drift"]))
		_:
			push_warning("LifecycleBehavior: 未知 move '%s'" % mv[&"kind"])


func _check_until(system: BulletSystem, id: int, st: Dictionary, cond: Dictionary, ctx: BehaviorContext) -> bool:
	match cond[&"kind"]:
		BulletLifecycle.C_NEVER:
			return false
		BulletLifecycle.C_TIMEOUT:
			return float(st[&"elapsed"]) >= float(cond[&"t"])
		BulletLifecycle.C_TOP_EDGE:
			return system.get_position(id).y <= GameConfig.FIELD_TOP
		BulletLifecycle.C_TURNED:
			return float(st[&"turned"]) >= float(cond[&"limit"])
		BulletLifecycle.C_NEAR_PLAYER:
			return system.get_position(id).distance_to(ctx.get_player_position()) < float(cond[&"r"])
		BulletLifecycle.C_NEAR_BOSS:
			var boss = _boss()
			if not is_instance_valid(boss):
				return false
			return system.get_position(id).distance_to(boss.global_position) < float(cond[&"r"])
		BulletLifecycle.C_WALL_HIT:
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
				st[&"hit_pos"] = clamped
				return true
			return false
		_:
			return false


func _run_actions(system: BulletSystem, id: int, st: Dictionary, actions: Array, ctx: BehaviorContext) -> void:
	for act in actions:
		match act[&"kind"]:
			BulletLifecycle.A_SFX:
				if act[&"key"] != &"" and host != null and host.has_method("play_sfx"):
					host.play_sfx(act[&"key"], float(act[&"db"]))
			BulletLifecycle.A_EMIT:
				_do_emit(system, id, st, act)
			BulletLifecycle.A_DESPAWN:
				system.request_despawn(id)
			BulletLifecycle.A_SET_VEL:
				system.set_velocity(id, Vector2(act[&"dir"]).normalized() * float(act[&"speed"]))


func _do_emit(system: BulletSystem, id: int, st: Dictionary, act: Dictionary) -> void:
	var at: Variant = st[&"hit_pos"]
	var at_v: Vector2 = at if at != null else system.get_position(id)
	var speed: float = system.get_velocity(id).length()
	if float(act[&"speed"]) > 0.0:
		speed = float(act[&"speed"])
	var aim := Vector2.DOWN
	if bool(act[&"aim_boss"]):
		var boss = _boss()
		if is_instance_valid(boss):
			aim = (boss.global_position - at_v).normalized()
	var dir: Vector2 = aim.rotated(float(act[&"angle"]))
	var factory: Callable = act.get(&"factory", Callable())
	if factory.is_valid() and host != null and host.has_method("queue_spawn"):
		var b = factory.call()
		if b != null:
			b.velocity = Vector2(0, speed)
			host.queue_spawn(b, at_v, dir)


func _boss():
	return host.get_boss() if host != null and host.has_method("get_boss") else null
