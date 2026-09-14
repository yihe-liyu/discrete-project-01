## 弹幕移动：沿飞行方向加速。发射方设 move=&"accel" + behavior_params={&"accel": a}（负=减速）。
extends Behavior
class_name AccelBehavior


## 只改 velocity，位置由系统下帧积分。
func process(system: BulletSystem, bullet_id: int, _ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)   # 发射时参数（共享只读）
	var accel: float = params.get(&"accel", 0.0) if params is Dictionary else 0.0
	if accel == 0.0:
		return
	var delta: float = system.get_delta()   # 本帧 dt
	if delta <= 0.0:
		return
	var v := system.get_velocity(bullet_id)
	var dir := v.normalized()
	if dir == Vector2.ZERO:
		return
	system.set_velocity(bullet_id, v + dir * accel * delta)
