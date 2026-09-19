## KernelBomb —— 宿主节点版 bomb（不走内核池）。
## 为什么不用内核行：bomb 需要 out_grace（轨道越界不被剔除），而 A 方案下内核 cull 是统一的，
## 没有 per-type grace；且 bomb 只有个位数、还要做清弹/伤害/视觉等宿主动作 → 宿主节点最干净。
## **本类只做机制**：所有数值来自 RingBombData（内容数据，.tres 可调）。
extends BombEntity

## 从 data 拷来的运行值
var orbit_speed: float = 0.0
var radius_growth: float = 0.0
var max_radius: float = 0.0
var hold_time: float = 0.0
var homing_speed: float = 0.0
var explode_damage: float = 0.0
var explode_radius: float = 0.0
var explode_duration: float = 0.0
var explode_start_radius: float = 0.0
var clear_radius: float = 0.0
var spawn_delay: float = 0.0
var _hitbox_radius: float = 45.0

enum Phase { GROW, HOLD, FLY }
var _phase: int = Phase.GROW
var _angle: float = 0.0
var _radius: float = 0.0
var _hold_timer: float = 0.0
var _fly_dir: Vector2 = Vector2.ZERO
var _is_initialized: bool = false
var _sprite: Sprite2D
var _init_dir: Vector2 = Vector2.DOWN
## Node2D 没有 velocity（旧 Bullet 才有）；bomb 飞行阶段用它。
var velocity: Vector2 = Vector2.ZERO


func setup(p_data: BombData, pos: Vector2, direction: Vector2, tint: Color = Color.WHITE, p_spawn_delay: float = 0.0) -> void:
	global_position = pos
	_init_dir = direction if direction != Vector2.ZERO else Vector2.DOWN
	var d := p_data as RingBombData
	if d == null:
		push_error("[KernelBomb] setup 需要 RingBombData")
		return
	data = d
	_hold_shake_sustain()
	spawn_delay = p_spawn_delay
	_hitbox_radius = d.hitbox_radius
	orbit_speed = deg_to_rad(d.orbit_speed_deg)
	radius_growth = d.radius_growth
	max_radius = d.max_radius
	hold_time = d.hold_time
	homing_speed = d.homing_speed
	explode_damage = d.explode_damage
	explode_radius = d.explode_radius
	explode_duration = d.explode_duration
	explode_start_radius = d.explode_start_radius
	clear_radius = d.clear_radius
	_sprite = Sprite2D.new()
	_sprite.texture = d.texture
	_sprite.modulate = tint
	add_child(_sprite)
	z_index = d.z_index


func _physics_process(delta: float) -> void:
	var p = entity_registry.player if entity_registry else null
	var player: Player = p if is_instance_valid(p) else null
	if not is_instance_valid(player):
		return
	if not _is_initialized:
		_is_initialized = true
		_angle = _init_dir.angle() + orbit_speed * spawn_delay
		_fly_dir = _init_dir.normalized()
	match _phase:
		Phase.GROW:
			_angle += orbit_speed * delta
			_radius += radius_growth * delta
			if _radius >= max_radius:
				_radius = max_radius
				_hold_timer = 0.0
				_phase = Phase.HOLD
		Phase.HOLD:
			_angle += orbit_speed * delta
			_hold_timer += delta
			if _hold_timer >= hold_time:
				_phase = Phase.FLY
				_fly_dir = Vector2.RIGHT.rotated(_angle)
		Phase.FLY:
			var enemy := _find_nearest_enemy()
			if enemy:
				_fly_dir = (enemy.global_position - global_position).normalized()
			velocity = _fly_dir * homing_speed
	if _phase == Phase.FLY:
		global_position += velocity * delta
		rotation = velocity.angle()
	else:
		global_position = player.global_position + Vector2.RIGHT.rotated(_angle) * _radius
		rotation = _angle
	# 持续清弹：始终清掉自己周围半径内的敌弹（每帧，不节流）
	if bullet_manager:
		bullet_manager.clear_enemy_bullets_in_circle(global_position, clear_radius)
	if _phase == Phase.FLY:
		var enemy := _find_nearest_enemy()
		if enemy and global_position.distance_to(enemy.global_position) <= _hitbox_radius + enemy.hitbox_radius:
			_explode()
			return
		if _is_outside_field(global_position):
			_explode()


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in (entity_registry.enemies if entity_registry else []):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy is Boss:
			var phase: PhaseData = (enemy as Boss).current_phase()
			if not phase or phase.is_timeout_only:
				continue
		var dist: float = global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


func _is_outside_field(pos: Vector2) -> bool:
	return pos.x < GameConfig.FIELD_LEFT or pos.x > GameConfig.FIELD_RIGHT \
		or pos.y < GameConfig.FIELD_TOP or pos.y > GameConfig.FIELD_BOTTOM


func _explode() -> void:
	# 击中/引爆：一次性冲击震屏（灵梦 bomb）
	if data != null and data.shake_impulse > 0.0:
		GameEvents.screen_shake.emit(data.shake_impulse)
	var pos := global_position
	AudioManager.play_sfx(AssetRegistry.sounds["shoot"], -6.0)
	_spawn_explosion_visual(pos)
	if bullet_manager:
		bullet_manager.start_death_clear(pos, explode_radius, explode_duration, explode_start_radius)
	for enemy in (entity_registry.get_active_enemies() if entity_registry else []):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(pos) <= explode_radius + enemy.hitbox_radius:
			enemy.take_damage(explode_damage)
	queue_free()


func _spawn_explosion_visual(pos: Vector2) -> void:
	var parent: Node = fx_parent
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var spr := Sprite2D.new()
	if _sprite != null:
		spr.texture = _sprite.texture
		spr.modulate = _sprite.modulate
	spr.global_position = pos
	spr.z_index = LayerConfig.EFFECT
	parent.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", Vector2(4, 4), explode_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, explode_duration)
	tw.tween_callback(spr.queue_free)
