## 锚定漂移行为（魔理沙非 focus 激光段）：每帧把子弹绝对定位到「锚点 + 漂移方向 × 累计距离」。
## 激光 = **分段流水**：每段贴在发射口（自机 / 子机）上、沿发射角匀速漂走；
## 段的生成间距 = 漂移速度 × 生成间隔 → 任何速度都无缝，看起来是一条连续激光。
## 位置用 set_position 绝对控制（不是速度积分）；速度只留给渲染朝向（段的长边才竖起来）。
## params（每次发射传）：anchor_id(锚点实例 id，0=自机) | anchor_offset | drift_speed | angle(弧度,0=上)
class_name LaserFollowBehavior
extends Behavior


func process(sys: BulletSystem, id: int, ctx: BehaviorContext) -> void:
	var params: Variant = sys.get_behavior_params(id)
	if not (params is Dictionary):
		return
	var st: Variant = sys.get_behavior_state(id)
	var fresh := false
	if not (st is Dictionary):
		st = {&"drift": params.get(&"initial_drift", 0.0)}   # 帧量化余量，保证与上一段严格等距
		sys.set_behavior_state(id, st)
		fresh = true
	# 世界位置 = 自机位置 + 发射口局部偏移。子机是自机子节点时读它的**局部 position**（含跟随 lerp，逐帧跟住）；
	# **不读 global_position**——父级移动后子节点 global 会滞后一帧，会让「刚生成的段」比整条线偏一个 v·dt。
	var anchor: Vector2 = ctx.get_player_position()
	var anchor_id: int = params.get(&"anchor_id", 0)
	if anchor_id != 0:
		var node: Object = instance_from_id(anchor_id)
		if node is Node2D:
			anchor += (node as Node2D).position
	else:
		anchor += params.get(&"anchor_offset", Vector2.ZERO)
	var angle: float = params.get(&"angle", 0.0)
	var dir := Vector2(sin(angle), -cos(angle))
	if not fresh:   # 刚生成这帧不推进（年龄 0），否则根部会多叠一段
		st[&"drift"] += params.get(&"drift_speed", 2000.0) * sys.get_delta()
	sys.set_position(id, anchor + dir * st[&"drift"])
