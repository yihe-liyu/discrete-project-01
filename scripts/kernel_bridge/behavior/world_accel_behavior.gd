## WorldAccelBehavior（Track A / S4a）—— 世界方向匀加速（承接旧 BulletData.accel 与 gravity_bullet）。
##
## 边界：本文件是宿主桥接层；内核无 world-accel 行为，故放这里（内核保持零改动）。
## params（发射时传）：&"world_accel": Vector2（px/s²；零 = 匀速）。
## 只改 velocity，位置由 BulletSystem 下帧积分——**别自己 += position，否则双倍**。
extends Behavior


func process(system: BulletSystem, bullet_id: int, _ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var accel: Vector2 = params.get(&"world_accel", Vector2.ZERO)
	if accel == Vector2.ZERO:
		return
	var delta: float = system.get_delta()
	if delta <= 0.0:
		return
	system.set_velocity(bullet_id, system.get_velocity(bullet_id) + accel * delta)
