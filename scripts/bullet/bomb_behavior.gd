extends CoroutineScript
## Bomb 弹幕行为：
##   1. 绕自机旋转并逐渐扩大旋转半径
##   2. 半径到上限后继续旋转一段时间
##   3. 有敌人 → 追踪最近敌人，命中后爆炸消失
##   4. 无敌人 → 沿当前方向直线飞向游戏边框，出界后爆炸消失

const EXPLODE_RADIUS := 140.0
const EXPLODE_DURATION := 0.4
const EXPLODE_START_RADIUS := 20.0

## 可调参数（可通过 BulletData.params 覆盖）
var orbit_speed: float = deg_to_rad(300.0)   ## 绕自机旋转角速度
var radius_growth: float = 200.0             ## 扩张半径速度（px/s）
var max_radius: float = 200.0                ## 最大旋转半径
var hold_time: float = 1.8                   ## 到达最大半径后继续旋转时间（秒）
var homing_speed: float = 1500.0              ## 追踪/直线飞行速度
var explode_damage: float = 150.0             ## 爆炸对敌人的伤害
var spawn_delay: float = 0.0                 ## 相对第一颗的生成延迟（秒），用于让后生成的弹直接出现在当前圆半径上

enum Phase { GROW, HOLD, FLY }

var _phase: int = Phase.GROW
var _angle: float = 0.0
var _radius: float = 0.0
var _hold_timer: float = 0.0
var _fly_dir: Vector2 = Vector2.ZERO
var _initialized: bool = false


func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target) or not target is Bullet:
		return false
	var bullet: Bullet = target
	var dt := get_dt()

	# 首次：记录起始角度（沿用发射方向）
	if not _initialized:
		_initialized = true
		# 预补偿生成延迟：后生成的弹虽然晚出发，但初始角度多转一段，最终仍均匀分布在圆上
		_angle = bullet.velocity.angle() + orbit_speed * spawn_delay
		_fly_dir = bullet.velocity.normalized()
		# 每颗都从自机位置开始扩张；角度由上面预补偿，保持角度间隔均匀

	var player: Player = GameState.player
	if not is_instance_valid(player):
		return true

	match _phase:
		Phase.GROW:
			_angle += orbit_speed * dt
			_radius += radius_growth * dt
			if _radius >= max_radius:
				_radius = max_radius
				_hold_timer = 0.0
				_phase = Phase.HOLD
		Phase.HOLD:
			_angle += orbit_speed * dt
			_hold_timer += dt
			if _hold_timer >= hold_time:
				_phase = Phase.FLY
				_fly_dir = Vector2.RIGHT.rotated(_angle)
		Phase.FLY:
			var enemy := _find_nearest_enemy()
			if enemy:
				_fly_dir = (enemy.global_position - bullet.global_position).normalized()
			bullet.velocity = _fly_dir * homing_speed

	# 轨道/飞行位置更新
	if _phase == Phase.FLY:
		bullet.global_position += bullet.velocity * dt
		bullet.rotation = bullet.velocity.angle()
	else:
		var center: Vector2 = player.global_position
		bullet.global_position = center + Vector2.RIGHT.rotated(_angle) * _radius
		bullet.rotation = _angle

	# 追踪/直线阶段碰到敌人 → 爆炸消失（旋转阶段不爆炸）
	if _phase == Phase.FLY:
		var enemy := _find_nearest_enemy()
		if enemy and bullet.global_position.distance_to(enemy.global_position) <= bullet.hitbox_radius + enemy.hitbox_radius:
			_explode(bullet, _ctx)
			return false

	# 无敌人时直线出界 → 爆炸消失
	if _phase == Phase.FLY and _is_outside_field(bullet.global_position):
		_explode(bullet, _ctx)
		return false

	return true


func _spawn_explosion_visual(bullet: Bullet, pos: Vector2) -> void:
	var scene := BulletManager.get_tree().current_scene
	if not scene:
		return
	var parent: Node = scene.get_node_or_null("World") if scene.has_node("World") else scene
	var spr := Sprite2D.new()
	spr.texture = bullet.sprite.texture
	spr.modulate = bullet.sprite.modulate
	spr.global_position = pos
	spr.z_index = LayerConfig.EFFECT
	parent.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", Vector2(4, 4), EXPLODE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, EXPLODE_DURATION)
	tw.tween_callback(spr.queue_free)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy: Node2D in GameState.active_enemies:
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


func _is_outside_field(pos: Vector2) -> bool:
	return pos.x < GameConfig.FIELD_LEFT or \
		pos.x > GameConfig.FIELD_RIGHT or \
		pos.y < GameConfig.FIELD_TOP or \
		pos.y > GameConfig.FIELD_BOTTOM


func _explode(bullet: Bullet, _ctx: StageContext) -> void:
	var pos := bullet.global_position
	AudioManager.play_sfx(AssetRegistry.sounds["shoot"], -6.0)
	# 视觉：贴图放大 + 渐隐（不复用 Miss 反色圈）
	_spawn_explosion_visual(bullet, pos)
	# 爆炸消弹
	if ctx:
		ctx.bullets.death_clear(pos, EXPLODE_RADIUS, EXPLODE_DURATION, EXPLODE_START_RADIUS)
	# 爆炸伤害
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(pos) <= EXPLODE_RADIUS + enemy.hitbox_radius:
			enemy.take_damage(explode_damage)
	BulletManager.return_bullet(bullet)
