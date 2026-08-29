extends GutTest
## 命中音效规则测试：normal_damage 仅 Boss 残血（<30%）播放；专属音效（marisa_damage）保持现状

const PhysicsClass = preload("res://scripts/autoload/bullet/bullet_physics.gd")


func _make_phys() -> BulletPhysics:
	var phys: BulletPhysics = PhysicsClass.new()
	phys._pool = BulletManager._pool
	return phys


func _shoot_player_bullet(pos: Vector2, hit_sfx: String = "") -> Bullet:
	var data := BulletData.new()
	data.damage = 10.0
	data.velocity = Vector2.UP
	data.faction = Bullet.FACTION_PLAYER
	data.hit_sfx = hit_sfx
	return BulletManager.shoot_player_bullet(data, pos, Vector2.UP)


func _make_enemy(pos: Vector2) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemy.tscn").instantiate()
	add_child_autofree(enemy)
	enemy.enemy_data = EnemyData.new()
	enemy._apply_enemy_data(enemy.enemy_data)
	enemy.max_hp = 100
	enemy.hp = 100
	enemy.global_position = pos
	enemy.hitbox_radius = 30.0
	return enemy


func _make_boss(pos: Vector2, phase_hp: int) -> Boss:
	var boss: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	var phase := PhaseData.new()
	phase.hp = phase_hp
	phase.time_limit = 10.0
	boss.start_phase(phase)
	boss._invincible = false
	boss.global_position = pos
	boss._hitbox_radius = 30.0
	return boss


func _played_now(stream: AudioStream) -> bool:
	return stream in AudioManager._played_this_frame


func test_normal_damage_not_played_for_normal_enemy():
	var phys := _make_phys()
	var enemy := _make_enemy(Vector2(400, 300))
	phys._enemy_hash.insert(enemy)
	var bullet := _shoot_player_bullet(Vector2(400, 300))
	phys._player_vs_enemies(bullet)
	assert_false(_played_now(AssetRegistry.sounds["normal_damage"]), "普通敌人命中不应播 normal_damage")


func test_normal_damage_not_played_for_full_hp_boss():
	var phys := _make_phys()
	var boss := _make_boss(Vector2(400, 300), 100)
	boss._hp = 80
	phys._enemy_hash.insert(boss)
	var bullet := _shoot_player_bullet(Vector2(400, 300))
	phys._player_vs_enemies(bullet)
	assert_false(_played_now(AssetRegistry.sounds["normal_damage"]), "Boss 血量充足命中不应播")


func test_normal_damage_played_for_low_hp_boss():
	var phys := _make_phys()
	var boss := _make_boss(Vector2(400, 300), 100)
	boss._hp = 20  # 20% < 30%
	phys._enemy_hash.insert(boss)
	var bullet := _shoot_player_bullet(Vector2(400, 300))
	phys._player_vs_enemies(bullet)
	assert_true(_played_now(AssetRegistry.sounds["normal_damage"]), "Boss 残血命中应播 normal_damage")


func test_marisa_damage_keeps_playing_for_normal_enemy():
	var phys := _make_phys()
	var enemy := _make_enemy(Vector2(400, 300))
	phys._enemy_hash.insert(enemy)
	var bullet := _shoot_player_bullet(Vector2(400, 300), "marisa_damage")
	phys._player_vs_enemies(bullet)
	assert_true(_played_now(AssetRegistry.sounds["marisa_damage"]), "专属音效对普通敌人仍应播")


func test_boss_is_low_hp_bounds():
	var boss: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	var phase := PhaseData.new()
	phase.hp = 100
	phase.time_limit = 10.0
	boss.start_phase(phase)
	boss._invincible = false
	boss._hp = 100
	assert_false(boss.is_low_hp(), "满血不残")
	boss._hp = 45
	assert_false(boss.is_low_hp(), "恰好 45% 不算残血")
	boss._hp = 44
	assert_true(boss.is_low_hp(), "44% 算残血")
	# 时符阶段不判定
	var tp := PhaseData.new()
	tp.hp = 100
	tp.time_limit = 10.0
	tp.is_timeout_only = true
	boss.start_phase(tp)
	boss._invincible = false
	boss._hp = 5
	assert_false(boss.is_low_hp(), "时符不判定残血")
