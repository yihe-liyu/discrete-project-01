## MarisaLaserBehavior（Track A / S4c-4）—— 魔理沙非 focus 激光段的锚定漂移。
## 与内核 LaserFollowBehavior 的唯一差别：原项目子机是**玩家的兄弟节点**
## （player_shoot_script._sync_options：`leader.get_parent().add_child(opt)`），其 `position` 相对 World，
## 不是相对玩家的 → 必须用 `global_position`（与旧 marisa_laser_follow 一致）。
## 子机无效 → 回退「自机 + offset」。
## params：anchor_id | anchor_offset | drift_speed | angle | initial_drift
extends Behavior


func process(system: BulletSystem, bullet_id: int, ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var st: Variant = system.get_behavior_state(bullet_id)
	var fresh := false
	if not (st is Dictionary):
		st = {&"drift": params.get(&"initial_drift", 0.0)}
		system.set_behavior_state(bullet_id, st)
		fresh = true
	var anchor_id: int = params.get(&"anchor_id", 0)
	var anchor: Vector2 = Vector2.ZERO
	var found := false
	if anchor_id != 0:
		var node: Object = instance_from_id(anchor_id)
		if node is Node2D:
			anchor = (node as Node2D).global_position
			found = true
	if not found:
		anchor = ctx.get_player_position()
	anchor += params.get(&"anchor_offset", Vector2.ZERO)
	var angle: float = params.get(&"angle", 0.0)
	var dir := Vector2(sin(angle), -cos(angle))
	if not fresh:
		st[&"drift"] += params.get(&"drift_speed", 2000.0) * system.get_delta()
	system.set_position(bullet_id, anchor + dir * st[&"drift"])
	# 贴图朝向 = 漂移方向（渲染桥按 velocity 旋转；旧 marisa_laser_follow 同款 target.velocity = dir）
	system.set_velocity(bullet_id, dir)
