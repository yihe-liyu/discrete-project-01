# DeathClear — 死亡清弹圈（子弹清除 + 激光淡出）
## W4a-2：内核唯一后端——逐帧扩张的圆交给注入的内核扫掠清除敌弹（不再持有旧池）。
class_name DeathClear
extends RefCounted

var _death_clears: Array[Dictionary] = []
var _laser_system: LaserEngine
## 内核扫掠：(center, radius, on_clear) -> void；由 BulletManager 注入。
var _sweep: Callable = Callable()


func setup(p_laser_sys, p_sweep: Callable) -> void:
	_laser_system = p_laser_sys
	_sweep = p_sweep


func start(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clears.append({
		pos = pos,
		age = 0.0,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
		on_clear = on_clear,
	})


func clear_all() -> void:
	_death_clears.clear()


func process(delta: float) -> void:
	for i in range(_death_clears.size() - 1, -1, -1):
		var circle: Dictionary = _death_clears[i]
		circle.age += delta
		if circle.age >= circle.duration:
			_death_clears.remove_at(i)
			continue
		if circle.duration <= 0:
			continue
		var progress: float = circle.age / circle.duration
		var radius: float = lerpf(circle.start_r, circle.max_r, progress)
		var center: Vector2 = circle.pos
		var radius_sq: float = radius * radius

		# 清除圆内的敌弹（内核扫掠，逐弹播消散特效 + on_clear）
		if _sweep.is_valid():
			_sweep.call(center, radius, circle.on_clear)

		# 生长型激光头部碰到消弹圈时：头部停止前进，尾部追上后消失
		for beam in _laser_system.get_active():
			if beam.phase != LaserBeam.Phase.GROW:
				continue
			var head_pos: Vector2 = beam.skeleton.sample_at(beam.head_dist)
			if head_pos.distance_squared_to(center) <= radius_sq:
				beam.cut_head()
