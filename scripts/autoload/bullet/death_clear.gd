# DeathClear — 死亡清弹圈（子弹清除 + 激光淡出）
class_name DeathClear
extends RefCounted

const _CLEAR_EFFECT = preload("res://scenes/effect/enemy_bullet_clear.tscn")

var _death_clears: Array[Dictionary] = []
var _pool: BulletPool
var _laser_system: LaserEngine
## 内核后端扫掠（Track A）：(center, radius, on_clear) -> bool。
## 返回 true = 本帧圆内敌弹已由内核清完，跳过旧池循环；未注入 / 旧池路径返回 false。
var _kernel_sweep: Callable = Callable()
## W2：组合根注入的特效层（空则静默）
var fx: FxLayer


func setup(p_pool, p_laser_sys, p_kernel_sweep: Callable = Callable()) -> void:
	_pool = p_pool
	_laser_system = p_laser_sys
	_kernel_sweep = p_kernel_sweep


## 消弹特效（同色）：未注入特效层时静默。
func _play_clear(pos: Vector2, tint: Color) -> void:
	if fx:
		fx.play(_CLEAR_EFFECT, pos, Vector2.ZERO, tint)


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
		
		# 清除圆内的敌弹（Track A：内核路径由注入扫掠接管；旧池路径保持原逐弹循环）
		var handled: bool = false
		if _kernel_sweep.is_valid():
			handled = _kernel_sweep.call(center, radius, circle.on_clear)
		if not handled:
			for j in range(_pool.active_bullets.size() - 1, -1, -1):
				var bullet: Bullet = _pool.active_bullets[j]
				if not is_instance_valid(bullet) or bullet.is_queued_for_deletion() or bullet.faction != 1 or not bullet.is_ready:
					continue
				if bullet.global_position.distance_squared_to(center) <= radius_sq:
					if circle.on_clear.is_valid():
						circle.on_clear.call(bullet.global_position)
					_play_clear(bullet.global_position, bullet.sprite.modulate)
					_pool.return_bullet(bullet)

		# 生长型激光头部碰到消弹圈时：头部停止前进，尾部追上后消失
		for beam in _laser_system.get_active():
			if beam.phase != LaserBeam.Phase.GROW:
				continue
			var head_pos: Vector2 = beam.skeleton.sample_at(beam.head_dist)
			if head_pos.distance_squared_to(center) <= radius_sq:
				beam.cut_head()

		
