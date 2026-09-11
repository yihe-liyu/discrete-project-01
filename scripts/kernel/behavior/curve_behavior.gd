## 弹幕移动：每颗弹按自己的角速度弯曲，转满 curve_limit 弧度后停（之后直线）。
## 发射方：move=&"curve" + behavior_params={&"curve": w}（弧度/秒）；可选 &"curve_limit"（<=0 = 一直弯）。
## params 只读、state 存每弹累计转角；参数表保持扁平（debug 下 params 会被冻结）。
extends Behavior
class_name CurveBehavior


func process(system: BulletSystem, bullet_id: int, _ctx: BehaviorContext) -> void:
	var st: Variant = system.get_behavior_state(bullet_id)
	if st == null:
		var params: Variant = system.get_behavior_params(bullet_id)   # 只读，不会被 state 顶掉
		var w: float = params.get(&"curve", 0.0) if params is Dictionary else 0.0
		if w == 0.0:
			return   # 无角速度 = 直线，不建 state
		st = {&"w": w, &"limit": params.get(&"curve_limit", 0.0), &"turned": 0.0}
		system.set_behavior_state(bullet_id, st)
	var step: float = st[&"w"] * system.get_delta()
	if st[&"limit"] > 0.0:
		var remain: float = st[&"limit"] - st[&"turned"]
		if remain <= 0.0:
			return   # 转满，之后走直线
		step = clampf(step, -remain, remain)
	st[&"turned"] += absf(step)
	system.set_velocity(bullet_id, system.get_velocity(bullet_id).rotated(step))
