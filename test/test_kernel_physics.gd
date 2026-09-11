extends GutTest
## S3b：KernelBulletPhysics —— 敌弹 ↔ 自机（命中 + 擦弹），规则与旧 BulletPhysics 1:1。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const REIMU_DATA = preload("res://data/player_data/reimu_data.tres")


## 轻量假敌人：只实现本层用到的字段/方法（免依赖完整 Enemy/Boss 场景）。
class FakeEnemy extends Node2D:
	var hitbox_radius: float = 20.0
	var damage_taken: float = 0.0

	func take_damage(d: float) -> void:
		damage_taken += d

var _backend: KernelBulletBackend
var _physics: KernelBulletPhysics
var _player: Player
var _prev_player: Player
var _prev_memory: float
var _prev_graze: int
var _prev_lives: int


func before_each() -> void:
	_backend = KernelBulletBackend.new()
	add_child_autofree(_backend)
	_physics = KernelBulletPhysics.new()
	_physics.setup(_backend)
	_player = PLAYER_SCENE.instantiate()
	_player.player_data = REIMU_DATA
	add_child_autofree(_player)
	_player.global_position = Vector2(448, 640)
	_player.is_invincible = false
	_prev_player = GameState.player
	GameState.player = _player
	_prev_memory = GameState.memory_value
	_prev_graze = GameState.graze_count
	_prev_lives = GameState.lives
	GameState.memory_value = 0.0    # 关闭擦弹随机清弹（>=50 才触发）
	GameState.graze_count = 0


func after_each() -> void:
	GameState.player = _prev_player
	GameState.memory_value = _prev_memory
	GameState.graze_count = _prev_graze
	GameState.lives = _prev_lives


func _enemy_bullet_at(pos: Vector2) -> int:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return _backend.shoot(d, pos, Vector2.RIGHT)


func test_bullet_on_player_is_hit() -> void:
	_enemy_bullet_at(_player.global_position)
	_physics.process()
	assert_eq(_backend.system.get_active_count(), 0, "命中后该弹应被回收")
	assert_true(_player.is_invincible, "miss() 应进入无敌")


func test_bullet_within_graze_is_grazed() -> void:
	# 命中阈值 = 自机 5 + 弹 6 = 11；擦弹阈值 = 40 + 6 = 46 → 放在 30 处只擦不中
	var id := _enemy_bullet_at(_player.global_position + Vector2(30, 0))
	_physics.process()
	assert_eq(GameState.graze_count, 1, "应计 1 次擦弹")
	assert_eq(_backend.system.get_active_count(), 1, "擦弹不回收该弹（随机清弹已关）")
	assert_true(_backend.system.is_grazed(id), "应标记为已擦弹")


func test_graze_not_counted_twice() -> void:
	_enemy_bullet_at(_player.global_position + Vector2(30, 0))
	_physics.process()
	_physics.process()
	assert_eq(GameState.graze_count, 1, "同一弹不应重复计擦弹")


func test_invincible_player_ignores_bullets() -> void:
	_player.is_invincible = true
	_enemy_bullet_at(_player.global_position)
	_physics.process()
	assert_eq(_backend.system.get_active_count(), 1, "无敌时弹应穿过")


func test_player_bullet_damages_enemy_via_damage_side_table() -> void:
	var fake := FakeEnemy.new()
	fake.global_position = Vector2(200, 200)
	add_child_autofree(fake)
	GameState.active_enemies.append(fake)
	GameState.memory_value = 100.0   # 关掉记忆加成（<50 才生效）
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 100.0
	d.damage = 10.0
	_backend.shoot(d, Vector2(200, 200), Vector2.UP)
	_physics.process()
	assert_almost_eq(fake.damage_taken, 10.0, 0.01, "伤害应来自后端 damage 侧表（内核无 damage）")
	assert_eq(_backend.system.get_active_count(), 0, "命中后应回收该弹")
	GameState.active_enemies.erase(fake)


## S3d：死亡清弹扫掠只清圆内敌弹（与旧 DeathClear 逐弹循环 1:1）。
func test_sweep_enemy_bullets_clears_only_in_radius() -> void:
	_enemy_bullet_at(Vector2(200, 200))
	_enemy_bullet_at(Vector2(900, 900))
	_physics.sweep_enemy_bullets(Vector2(200, 200), 100.0)
	assert_eq(_backend.system.get_active_count(), 1, "死亡清弹应只清圆内的敌弹")
	assert_eq(_backend.system.get_position(0), Vector2(900, 900), "圆外弹应保留（swap-with-last 后落 0 槽）")


## S3d：死亡清弹不应误伤自机弹。
func test_sweep_enemy_bullets_spares_player_bullets() -> void:
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 100.0
	_backend.shoot(d, Vector2(200, 200), Vector2.UP)
	_enemy_bullet_at(Vector2(200, 200))
	_physics.sweep_enemy_bullets(Vector2(200, 200), 100.0)
	assert_eq(_backend.system.get_active_count(), 1, "死亡清弹不应清自机弹")
	assert_eq(_backend.system.get_type(0).faction, BulletType.Faction.PLAYER, "留下的应是自机弹")
