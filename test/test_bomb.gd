extends GutTest
## Bomb 系统测试：Bomb 弹幕碰到敌弹时消除敌弹、对敌人造成伤害

var _pool: BulletPool
var _physics: BulletPhysics
var _holder: Node


func before_each():
	# 池子弹挂在独立 holder 上（add_child_autofree 随测试结束释放），
	# 否则 4000+ 池子弹一直挂在测试脚本下，脚本结束时报 unfreed children
	_holder = Node.new()
	add_child_autofree(_holder)
	_pool = BulletPool.new()
	_pool.setup(_holder)
	_physics = BulletPhysics.new()
	_physics.setup(_pool)
	GameState.memory_value = 0.0
	GameState.active_enemies.clear()
	GameState.player = null


func after_each():
	_pool.clear()
	GameState.active_enemies.clear()
	GameState.player = null
	# W2：BulletPhysics 未注入 fx（FxLayer）→ 命中/消弹特效静默，无孤儿实例需清理


func _enemy_bullet_data() -> BulletData:
	var d := BulletData.new()
	d.faction = BulletData.Faction.ENEMY
	d.hitbox_shape = BulletData.HitboxShape.CIRCLE
	d.hitbox_radius = 4.0
	d.spawn_fog = false
	return d


func test_bomb_bullet_clears_enemy_bullet_on_contact():
	var enemy: Bullet = _pool.shoot(_enemy_bullet_data(), Vector2(448, 500), Vector2.ZERO)
	var bomb_data := BulletData.new().tex("bomb01").bomb()
	var bomb: Bullet = _pool.shoot(bomb_data, Vector2(448, 500), Vector2.ZERO)
	assert_not_null(enemy, "敌弹应生成")
	assert_not_null(bomb, "Bomb 弹应生成")

	_physics.process_collisions()

	assert_false(_pool.active_bullets.has(enemy), "敌弹被 Bomb 弹碰到后应被消除")
	assert_true(_pool.active_bullets.has(bomb), "Bomb 弹本身应保留（持续飞行可连续消弹）")


func test_bomb_bullet_damages_enemy():
	var enemy: Enemy = load("res://scenes/enemy.tscn").instantiate()
	enemy.enemy_data = EnemyData.new().with_script(preload("res://data/stages/stage01/enemy/enemy01.gd")).hp(100)
	autofree(enemy)
	add_child(enemy)
	enemy.global_position = Vector2(448, 500)
	var before_hp: int = enemy.hp

	var bomb_data := BulletData.new().tex("bomb01").bomb()
	var bomb: Bullet = _pool.shoot(bomb_data, Vector2(448, 500), Vector2.ZERO)
	_physics.process_collisions()

	assert_lt(enemy.hp, before_hp, "Bomb 弹碰到敌人应造成伤害")


func test_bomb_bullet_hits_enemy_only_once():
	var enemy: Enemy = load("res://scenes/enemy.tscn").instantiate()
	enemy.enemy_data = EnemyData.new().with_script(preload("res://data/stages/stage01/enemy/enemy01.gd")).hp(100)
	autofree(enemy)
	add_child(enemy)
	enemy.global_position = Vector2(448, 500)
	var bomb_data := BulletData.new().tex("bomb01_white").bomb()
	var bomb: Bullet = _pool.shoot(bomb_data, Vector2(448, 500), Vector2.ZERO)
	_physics.process_collisions()
	_physics.process_collisions()
	assert_eq(enemy.hp, 50, "同一颗 Bomb 弹对同一敌人只应造成一次伤害（防帧伤）")
