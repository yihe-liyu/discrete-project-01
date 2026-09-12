extends CoroutineScript
class_name MoveHoming

## 诱导角度每秒（弧度）
var homing_angle_per_sec: float = deg_to_rad(720)
## 从当前速度加速到最高速所需时间（秒），0 表示瞬间满速
var accel_time: float = 2.0
## 最低速度（诱导开始时）
var min_speed: float = 500.0
## 最高速度（0 表示保持初始速度）
var max_speed: float = 2000.0
## 诱导持续多久（秒），0 表示直到离开场景
var homing_duration: float = 2.0
## 距离越近转弯越激进——值越大，远距离诱导越强
var proximity_boost: float = 150.0

var _elapsed: float = 0.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_elapsed = 0.0

	var tl := start_timeline()
	var base_speed: float = target.velocity.length() if target else 500.0
	var top_speed: float = max_speed if max_speed > 0.0 else base_speed

	# 每帧：加速 + 转向目标方向 + 推进
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false

		var dt := get_dt()
		_elapsed += dt
		var turn_factor := _calc_turn_factor()
		var current_speed := lerpf(min_speed, top_speed, turn_factor)

		if _is_still_homing():
			_apply_homing(turn_factor, dt)

		target.velocity = target.velocity.normalized() * current_speed
		target.global_position += target.velocity * dt
		target.rotation = target.velocity.angle()
	)

	super.start(ctx, target)


## 加速进度 [0, 1]
func _calc_turn_factor() -> float:
	if accel_time <= 0.0:
		return 1.0
	return clampf(_elapsed / accel_time, 0.0, 1.0)


## 诱导是否仍然生效
func _is_still_homing() -> bool:
	return homing_duration <= 0.0 or _elapsed <= homing_duration


## 根据敌人位置调整弹幕速度方向
func _apply_homing(turn_factor: float, dt: float):
	var nearest := _find_nearest_enemy()
	if not nearest:
		return

	var diff := nearest.global_position - target.global_position
	var dist: float = maxf(diff.length(), 1.0)
	var desired_dir := diff / dist
	var current_dir: Vector2 = target.velocity.normalized()

	# 距离越近转弯越激进（平滑衰减，不是硬性截断）
	var dist_weight: float = 1.0 + proximity_boost / (dist + proximity_boost)
	var max_turn := homing_angle_per_sec * turn_factor * dist_weight * dt
	var angle_diff := current_dir.angle_to(desired_dir)
	var actual_turn := clampf(angle_diff, -max_turn, max_turn)

	# 方向和目标差太远时减速，防止转大弯时冲过头
	var alignment: float = (current_dir.dot(desired_dir) + 1.0) * 0.4
	var speed_mult: float = lerpf(0.5, 1.0, alignment)

	target.velocity = current_dir.rotated(actual_turn) * speed_mult


## 找最近的、可被命中的敌人（跳过时符阶段的 Boss）
func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	var enemies: Array = ctx.refs.get_active_enemies() if ctx and ctx.refs else []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy is Boss:
			var phase := (enemy as Boss).current_phase()
			if not phase or phase.is_timeout_only:
				continue
		var dist := target.global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


## 内核端口（Track A / S4b）：参数交给桥接 HomingBehavior（语义 1:1）。
func kernel_port() -> Dictionary:
	return {
		"move": &"homing",
		"params": {
			&"homing_angle_per_sec": homing_angle_per_sec,
			&"accel_time": accel_time,
			&"min_speed": min_speed,
			&"max_speed": max_speed,
			&"homing_duration": homing_duration,
			&"proximity_boost": proximity_boost,
		},
	}
