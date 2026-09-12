## KernelBomb（Track A / S4d-2）—— 宿主节点版 bomb（不走内核池）。
## 为什么不用内核行：bomb 需要 out_grace（轨道越界不被剔除），而 A 方案下内核 cull 是统一的，
## 没有 per-type grace；且 bomb 只有 8 颗、还要做清弹/伤害/视觉等宿主动作 → 宿主节点最干净。
## 逻辑 1:1 移植 scripts/bullet/bomb_behavior.gd。
extends Node2D

const EXPLODE_RADIUS: float = 140.0
const EXPLODE_DURATION: float = 0.4
const EXPLODE_START_RADIUS: float = 20.0

## 可调参数（可用 BulletData.params 覆盖；默认值与 bomb_behavior.gd 同源）
var orbit_speed: float = deg_to_rad(300.0)
var radius_growth: float = 200.0
var max_radius: float = 200.0
var hold_time: float = 1.8
var homing_speed: float = 1500.0
var explode_damage: float = 150.0
var spawn_delay: float = 0.0
var clear_radius: float = 90.0   ## 持续清弹半径（围绕本弹自己，每帧）

enum Phase { GROW, HOLD, FLY }
var _phase: int = Phase.GROW
var _angle: float = 0.0
var _radius: float = 0.0
var _hold_timer: float = 0.0
var _fly_dir: Vector2 = Vector2.ZERO
var _initialized: bool = false
var _hitbox_radius: float = 45.0
var _sprite: Sprite2D
var _init_dir: Vector2 = Vector2.DOWN
## Node2D 没有 velocity（旧 Bullet 才有）；bomb 飞行阶段用它。
var velocity: Vector2 = Vector2.ZERO
## W4b-3b：实体注册表（自机 / 敌机 / Boss；KernelBulletBackend 注入）
var refs: EntityRegistry
## W4c：弹幕世界（KernelBulletBackend 注入）——持续清弹 / 爆炸清弹用
var world: BulletManager
## K4：爆炸贴图父节点（KernelBulletBackend 注入 World；空则挂自身父级）
var fx_parent: Node2D


func setup(data: BulletData, pos: Vector2, direction: Vector2) -> void:
	global_position = pos
	_init_dir = direction if direction != Vector2.ZERO else Vector2.DOWN
	if data != null:
		_hitbox_radius = data.hitbox_radius
		if data.params is Dictionary:
			orbit_speed = data.params.get("orbit_speed", orbit_speed)
			radius_growth = data.params.get("radius_growth", radius_growth)
			max_radius = data.params.get("max_radius", max_radius)
			hold_time = data.params.get("hold_time", hold_time)
			homing_speed = data.params.get("homing_speed", homing_speed)
			explode_damage = data.params.get("explode_damage", explode_damage)
			spawn_delay = data.params.get("spawn_delay", spawn_delay)
		clear_radius = data.params.get("clear_radius", clear_radius)
		_sprite = Sprite2D.new()
		_sprite.texture = data.texture
		_sprite.modulate = data.tint
		add_child(_sprite)
	z_index = LayerConfig.BOMB


func _physics_process(delta: float) -> void:
	var p = refs.player if refs else null
	var player: Player = p if is_instance_valid(p) else null
	if not is_instance_valid(player):
		return
	if not _initialized:
		_initialized = true
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
	if world:
		world.clear_enemy_bullets_in_circle(global_position, clear_radius)
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
	for enemy in (refs.enemies if refs else []):
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
	var pos := global_position
	AudioManager.play_sfx(AssetRegistry.sounds["shoot"], -6.0)
	_spawn_explosion_visual(pos)
	if world:
		world.start_death_clear(pos, EXPLODE_RADIUS, EXPLODE_DURATION, EXPLODE_START_RADIUS)
	for enemy in (refs.get_active_enemies() if refs else []):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.distance_to(pos) <= EXPLODE_RADIUS + enemy.hitbox_radius:
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
	tw.tween_property(spr, "scale", Vector2(4, 4), EXPLODE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, EXPLODE_DURATION)
	tw.tween_callback(spr.queue_free)
