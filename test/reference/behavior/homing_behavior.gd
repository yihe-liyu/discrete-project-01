## HomingBehavior—— 自机弹追杀最近敌人（移植旧 move_homing.gd）。
##
## 边界：桥接层（引用宿主 Boss / PhaseData 做"时符 / 未开战跳过"）；内核零改动。
## 语义 1:1：每帧 转向限制 + 速度爬升 + 持续时长；**只 set_velocity**，位置由系统积分。
## 注：旧实现里的 speed_mult/alignment 在随后的 normalize 里被丢弃（死代码），这里不复刻。
## params：homing_angle_per_sec / accel_time / min_speed / max_speed / homing_duration / proximity_boost
extends Behavior


func process(system: BulletSystem, bullet_id: int, ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var delta: float = system.get_delta()
	if delta <= 0.0:
		return
	var behavior_state: Variant = system.get_behavior_state(bullet_id)
	if not (behavior_state is Dictionary):
		var base_speed: float = system.get_velocity(bullet_id).length()
		var max_speed: float = params.get(&"max_speed", 0.0)
		behavior_state = {
			&"elapsed": 0.0,
			&"base_speed": base_speed,
			&"top_speed": max_speed if max_speed > 0.0 else base_speed,
		}
		system.set_behavior_state(bullet_id, behavior_state)
	behavior_state[&"elapsed"] += delta
	var accel_time: float = params.get(&"accel_time", 0.0)
	var turn_factor: float = 1.0 if accel_time <= 0.0 else clampf(behavior_state[&"elapsed"] / accel_time, 0.0, 1.0)
	var current_speed: float = lerpf(params.get(&"min_speed", 500.0), behavior_state[&"top_speed"], turn_factor)
	var current_dir: Vector2 = system.get_velocity(bullet_id).normalized()
	var homing_duration: float = params.get(&"homing_duration", 0.0)
	if current_dir != Vector2.ZERO and (homing_duration <= 0.0 or behavior_state[&"elapsed"] <= homing_duration):
		var target: Node2D = _nearest_enemy(ctx, system.get_position(bullet_id))
		if target != null:
			var from: Vector2 = system.get_position(bullet_id)
			var diff: Vector2 = target.global_position - from
			var dist: float = maxf(diff.length(), 1.0)
			var desired_dir: Vector2 = diff / dist
			var proximity_boost: float = params.get(&"proximity_boost", 150.0)
			var dist_weight: float = 1.0 + proximity_boost / (dist + proximity_boost)
			var max_turn: float = params.get(&"homing_angle_per_sec", deg_to_rad(720.0)) * turn_factor * dist_weight * delta
			var actual_turn: float = clampf(current_dir.angle_to(desired_dir), -max_turn, max_turn)
			current_dir = current_dir.rotated(actual_turn)
	if current_dir != Vector2.ZERO:
		system.set_velocity(bullet_id, current_dir * current_speed)


## 最近的可命中敌人（跳过时符 / 未开战 Boss）——与旧 move_homing._find_nearest_enemy 1:1。
func _nearest_enemy(ctx: BehaviorContext, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	for enemy: Node2D in ctx.get_world().get_enemies():
		if enemy is Boss:
			var phase: PhaseData = (enemy as Boss).current_phase()
			if not phase or phase.is_timeout_only:
				continue
		var d2: float = from.distance_squared_to(enemy.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = enemy
	return best
