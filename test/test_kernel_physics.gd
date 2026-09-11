extends GutTest
## S3b：KernelBulletPhysics —— 敌弹 ↔ 自机（命中 + 擦弹），规则与旧 BulletPhysics 1:1。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const REIMU_DATA = preload("res://data/player_data/reimu_data.tres")

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
