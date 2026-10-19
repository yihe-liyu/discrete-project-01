## BossService —— ctx.boss（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 关卡 Boss 查询服务 —— ctx.boss 下的"现在场上有没有 Boss / 取哪个"动词。
## 内容只问"有没有/取哪个"，内部查 StageContext.entity_registry（机制）。
## 注意：不叫 get() —— 会遮蔽 Object.get(property)，故用 current()/exists()。

var ctx: StageContext


## 当前场上的 Boss（无 → null）
func current() -> Boss:
	return ctx.entity_registry.get_boss() if ctx and ctx.entity_registry else null


## 当前场上是否有 Boss
func exists() -> bool:
	return current() != null


## 让 Boss 在 duration 秒内移动到 dest（物理时钟；内容不自己 create_tween）。
## 返回 Tween（便于调试/追加）；参数非法/时长为 0 时返回 null（时长为 0 则瞬移）。
func move_to(boss: Node2D, dest: Vector2, duration: float,
		ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_QUAD) -> Tween:
	if boss == null or not is_instance_valid(boss):
		push_error("BossService.move_to(): 传入空 / 已释放的对象 —— 移动空跑")
		return null
	if duration <= 0.0:
		boss.global_position = dest
		return null
	var tween := boss.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_ease(ease_type).set_trans(trans_type)
	tween.tween_property(boss, "global_position", dest, duration)
	return tween


## 多段移动（同一 Tween；points / durations 一一对应，eases 可省略）。
## hold_between > 0 时每段之间停一下 —— 用于「快→慢→快」的 pre_move 走位。
func move_path(boss: Node2D, points: Array, durations: Array, eases: Array = [],
		hold_between: float = 0.0, trans_type: int = Tween.TRANS_QUAD) -> Tween:
	if boss == null or not is_instance_valid(boss):
		push_error("BossService.move_path(): 传入空 / 已释放的对象 —— 移动空跑")
		return null
	if points.is_empty() or points.size() != durations.size():
		push_error("BossService.move_path(): points / durations 必须非空且等长")
		return null
	var tween := boss.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(trans_type)
	for i in points.size():
		if not (points[i] is Vector2):
			push_error("BossService.move_path(): points[%d] 不是 Vector2" % i)
			tween.kill()
			return null
		var dest: Vector2 = points[i] as Vector2
		var duration: float = float(durations[i])
		if duration <= 0.0:
			boss.global_position = dest
		else:
			var ease_type: int = int(eases[i]) if i < eases.size() else Tween.EASE_IN_OUT
			tween.tween_property(boss, "global_position", dest, duration).set_ease(ease_type)
		if hold_between > 0.0 and i < points.size() - 1:
			tween.tween_interval(hold_between)
	return tween