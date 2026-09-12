# BulletPhysics — 碰撞检测、分流、擦弹、击中特效
class_name BulletPhysics
extends RefCounted

const _CLEAR_EFFECT = preload("res://scenes/effect/enemy_bullet_clear.tscn")

## 命中音效音量表（key → dB；未列出的默认 -14）：专属音效可单独调
const HIT_SFX_VOLUME := {
	"marisa_damage": -10.0,
}

var _pool: BulletPool
var _enemy_hash: SpatialHash = SpatialHash.new()  # 敌人登记（玩家弹查询）
var _bullet_hash: SpatialHash = SpatialHash.new() # 敌弹登记（自机查询）
## W2：组合根注入的特效层（空则静默，便于测试/无场景）
var fx: FxLayer


func setup(p_pool) -> void:
	_pool = p_pool



func process_collisions() -> void:
	# 空间哈希（P-10）：每帧重建敌人 + 敌弹网格
	_enemy_hash.clear()
	for enemy in GameState.get_active_enemies():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			_enemy_hash.insert(enemy)
	_bullet_hash.clear()
	for bullet in _pool.active_bullets:
		if is_instance_valid(bullet) and not bullet.is_queued_for_deletion() and bullet.is_ready and bullet.faction == Bullet.FACTION_ENEMY:
			_bullet_hash.insert(bullet)
	# 玩家弹 vs 敌人（倒序，命中回收安全）
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		var bullet: Bullet = _pool.active_bullets[i]
		if bullet.is_ready and bullet.faction == Bullet.FACTION_PLAYER:
			_player_vs_enemies(bullet)
	# 敌弹 vs 自机（自机为中心查哈希，一次 query）
	_resolve_enemy_bullets_near_player()
	# Bomb 弹 vs 敌弹（碰到即消）
	# 先收集快照：_bomb_vs_enemy_bullets 会 return_bullet 修改 active_bullets，不能边遍历边删
	var bomb_bullets: Array[Bullet] = []
	for bullet in _pool.active_bullets:
		if bullet.is_ready and bullet.faction == Bullet.FACTION_BOMB:
			bomb_bullets.append(bullet)
	for bullet in bomb_bullets:
		_bomb_vs_enemy_bullets(bullet)
	# Bomb 弹 vs 敌人
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		var bullet: Bullet = _pool.active_bullets[i]
		if bullet.is_ready and bullet.faction == Bullet.FACTION_BOMB:
			_bomb_vs_enemies(bullet)


## 敌弹 vs 自机：查询自机周围格子内的敌弹（擦弹/命中判定）
func _resolve_enemy_bullets_near_player() -> void:
	var player: Player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	# query 半径覆盖命中半径（~11px）与擦弹半径（~46px）
	var candidates: Array = _bullet_hash.query(player.global_position, player.graze_radius + 8.0)
	for bullet in candidates:
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			continue
		if not bullet.is_ready:
			continue
		if _hit_target(bullet, player):
			player.miss()
			_pool.return_bullet(bullet)
		elif not bullet._grazed and _grazes_player(bullet, player):
			bullet._grazed = true
			on_graze()
			if GameState.memory_value >= 50.0:
				var chance := remap(GameState.memory_value, 50.0, 100.0, 0.05, 0.30)
				if RNG.randf() < chance:
					_play_clear(bullet.global_position, bullet.sprite.modulate)
					_pool.return_bullet(bullet)


func _player_vs_enemies(bullet: Bullet) -> void:
	var bonus := 1.0
	if bullet.faction == Bullet.FACTION_PLAYER and GameState.memory_value < 50.0:
		bonus = 1.0 + remap(GameState.memory_value, 0.0, 50.0, 0.15, 0.05)
	
	# 空间哈希：只检查附近格子内的敌人（最大目标半径 36 = Boss 默认）
	var candidates: Array = _enemy_hash.query(bullet.global_position, bullet.hitbox_radius + 36.0)
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		# 时符阶段 / 没开战：Boss 不可被击中，子弹穿过
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if not phase or phase.is_timeout_only:
				continue
		if _hit_target(bullet, enemy):
			enemy.take_damage(bullet.damage * bonus)  # float 伤害，Enemy 内部累积
			GameState.add_memory(GameState.MEMORY_HIT_BY_BULLET)
			# 命中音效规则：
			# - 专属音效（hit_sfx 非空，如 marisa_damage）：任何敌人命中都播（保持现状）
			# - 默认 normal_damage：仅 Boss 残血（<30%）时播，作为残血警报；普通敌人命中静音
			var sfx_key: String = bullet.extra.get("hit_sfx", "")
			if sfx_key == "":
				if enemy is Boss and (enemy as Boss).is_low_hp():
					AudioManager.play_sfx(AssetRegistry.sounds["normal_damage"], -14.0, 0.05)
			else:
				var sfx: AudioStream = AssetRegistry.sounds.get(sfx_key, null)
				if sfx == null:
					push_warning("BulletPhysics: 未知命中音效 key '%s'（回退 normal_damage）" % sfx_key)
					sfx = AssetRegistry.sounds["normal_damage"]
				var vol: float = HIT_SFX_VOLUME.get(sfx_key, -14.0)
				AudioManager.play_sfx(sfx, vol, 0.05)  # 间隔 50ms：高频命中音防挤兑
			_spawn_effect(bullet.hit_effect, bullet.global_position, bullet.velocity, bullet.sprite.modulate)
			_pool.return_bullet(bullet)
			return


## Bomb 弹 vs 敌弹：碰撞到就把敌弹消除（Bomb 弹本身不消失，持续飞行可连续消弹）
func _bomb_vs_enemy_bullets(bullet: Bullet) -> void:
	var candidates: Array = _bullet_hash.query(bullet.global_position, bullet.hitbox_radius + 12.0)
	for enemy_bullet in candidates:
		if not is_instance_valid(enemy_bullet) or enemy_bullet.is_queued_for_deletion():
			continue
		if not enemy_bullet.is_ready:
			continue
		if _hit_target(bullet, enemy_bullet):
			_play_clear(enemy_bullet.global_position, enemy_bullet.sprite.modulate)
			_pool.return_bullet(enemy_bullet)


func _bomb_vs_enemies(bullet: Bullet) -> void:
	var candidates: Array = _enemy_hash.query(bullet.global_position, bullet.hitbox_radius + 36.0)
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if phase and phase.is_timeout_only:
				continue
		if _hit_target(bullet, enemy):
			# A 方案：同一颗 Bomb 弹对同一个敌人只造成一次伤害（防帧伤）
			var hit_map: Dictionary = bullet.extra.get("bomb_hit", {})
			var enemy_id: int = enemy.get_instance_id()
			if hit_map.has(enemy_id):
				continue
			hit_map[enemy_id] = true
			bullet.extra["bomb_hit"] = hit_map
			enemy.take_damage(bullet.damage)
			_spawn_effect(bullet.hit_effect, bullet.global_position)


# ── 命中检测 ──

func _hit_target(bullet: Bullet, target: Node2D) -> bool:
	match bullet.hitbox_shape:
		BulletData.HitboxShape.CIRCLE:
			return _check_circle(bullet, target)
		BulletData.HitboxShape.RECTANGLE:
			return _check_rect(bullet, target)
	return false


func _check_circle(bullet: Bullet, target: Node2D) -> bool:
	var center: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var target_center: Vector2 = target.global_position
	# 类型化访问（性能：target.get()/in 动态调用每次 ~2us，高频路径禁用）
	var target_radius: float = target.hitbox_radius
	var total_radius: float = bullet.hitbox_radius + target_radius
	return center.distance_squared_to(target_center) < total_radius * total_radius


func _check_rect(bullet: Bullet, target: Node2D) -> bool:
	var box_center: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var half: Vector2 = bullet.hitbox_size / 2.0
	var angle: float = bullet.rotation + deg_to_rad(bullet.hitbox_rotation)
	var target_center: Vector2 = target.global_position
	# 类型化访问（性能）
	var target_radius: float = target.hitbox_radius
	var local_target: Vector2 = (target_center - box_center).rotated(-angle)
	var closest: Vector2 = Vector2(
		clamp(local_target.x, -half.x, half.x),
		clamp(local_target.y, -half.y, half.y)
	)
	return closest.distance_squared_to(local_target) < target_radius * target_radius


# ── 擦弹 ──

func _grazes_player(bullet: Bullet, player: Player) -> bool:
	var center: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var total_radius: float = bullet.hitbox_radius + player.graze_radius
	return center.distance_squared_to(player.global_position) < total_radius * total_radius


func on_graze() -> void:
	GameState.graze_count += 1
	GameState.add_score(10)
	GameState.add_memory(GameState.MEMORY_GRAZE)
	AudioManager.play_sfx(AssetRegistry.sounds["graze"], -2.0, 0.03)  # 间隔 30ms：高频擦弹音防挤兑


# ── 击中特效 ──

func _spawn_effect(effect_scene: PackedScene, pos: Vector2, velocity: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	if effect_scene == null or fx == null:
		return  # 无特效的子弹（测试构造/漏配置）/ 未注入特效层：跳过，防崩
	fx.play(effect_scene, pos, velocity, tint)


## 消弹特效（同色）：未注入特效层时静默。
func _play_clear(pos: Vector2, tint: Color) -> void:
	if fx:
		fx.play(_CLEAR_EFFECT, pos, Vector2.ZERO, tint)
