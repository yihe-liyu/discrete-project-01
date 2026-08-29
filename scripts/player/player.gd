# entities/player/player.gd
extends Area2D
class_name Player

const FRONT_UP: float = GameConfig.FIELD_TOP
const FRONT_DOWN: float = GameConfig.FIELD_BOTTOM
const FRONT_LEFT: float = GameConfig.FIELD_LEFT
const FRONT_RIGHT: float = GameConfig.FIELD_RIGHT
const MIN_MARGIN: int = 8

## 关卡上下文（StageManager/game_scene 注入，系统操作走服务）
var ctx: StageContext

const IDLE = "idle"
const LEFTING = "lefting"
const LEFT = "left"
const RIGHTING = "righting"
const RIGHT = "right"
var anim_state: String = IDLE

var input_vector: Vector2 = Vector2.ZERO
var is_focused: bool = false
var is_invincible: bool = false
var _invincible_timer: float = 0.0

var hitbox_radius: float = 5.0
var graze_radius: float = 40.0  # 擦弹判定半径

@onready var hitpoint_display: HitPointDisplay = $HitPointDisplay
@onready var muzzle: Marker2D = $Muzzle

## 玩家机体数据（速度、动画、武器等）
@export var player_data: PlayerData
var _shoot_script: PlayerShootScript
var _cached_item_pool: Node = null

# 移动速度（像素/秒）
var focus_speed: int
var normal_speed: int
var current_speed: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = LayerConfig.PLAYER
	# 连接 animation_finished 信号，用于检测一次性动画播完
	sprite.animation_finished.connect(_on_animation_finished)

	_apply_player_data()
	_init_shoot_script()

# 应用机体数据
func _apply_player_data() -> void:
	if player_data == null:
		push_error("Player: 未设置 PlayerData 资源！")
		return

	focus_speed = player_data.focus_speed
	normal_speed = player_data.normal_speed
	current_speed = normal_speed

	if sprite and player_data.animation:
		sprite.sprite_frames = player_data.animation
		sprite.play("idle")

	GameState.player = self

func _physics_process(delta):
	# 无敌倒计时（替代 await，不挂起调用链）
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
	
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	is_focused = Input.is_action_pressed("focus")
	
	if Input.is_action_just_pressed("memory_release"):
		_memory_release()
	if Input.is_action_just_pressed("cancel&bomb"):
		_bomb()

	update_hitbox_display()
	update_animation()
	update_move(delta)

func _init_shoot_script() -> void:
	if not player_data or not player_data.shoot_script:
		return
	_shoot_script = player_data.shoot_script.new()
	assert(_shoot_script is PlayerShootScript, "Player: shoot_script must be a PlayerShootScript")
	add_child(_shoot_script)
	var shoot_ctx := StageContext.new(_shoot_script)
	_shoot_script.start_shooting(shoot_ctx)

## 切换角色时重新初始化射击
func _reinit_shoot() -> void:
	if _shoot_script:
		_shoot_script.stop()
		_shoot_script.queue_free()
		_shoot_script = null
	_init_shoot_script()

func update_hitbox_display() -> void:
	if is_focused:
		hitpoint_display.show_hitpoint()
	else:
		hitpoint_display.hide_hitpoint()

func update_move(delta: float) -> void:
	var move_input: Vector2 = input_vector
	# 归一化对角线速度，使斜向移动速度不增加
	if move_input.length() > 1.0: move_input = move_input.normalized()

	current_speed = focus_speed if is_focused else normal_speed

	position += move_input * current_speed * delta

	# 位置限制
	position.x = clamp(position.x, FRONT_LEFT + MIN_MARGIN * 3, FRONT_RIGHT - MIN_MARGIN * 3)
	position.y = clamp(position.y, FRONT_UP + MIN_MARGIN * 4, FRONT_DOWN - MIN_MARGIN * 4)

func update_animation() -> void:
	var pressing_left: bool = input_vector.x < -0.1
	var pressing_right: bool = input_vector.x > 0.1

	if (pressing_left and pressing_right) or (not pressing_left and not pressing_right):
		change_state(IDLE)
		return

	# 根据当前状态和输入，决定下一个状态
	match anim_state:
		IDLE:
			if		pressing_left and not pressing_right: change_state(LEFTING)
			elif	pressing_right and not pressing_left: change_state(RIGHTING)
		LEFTING:	if not pressing_left:  change_state(IDLE)
		LEFT:		if not pressing_left:  change_state(IDLE)
		RIGHT:		if not pressing_right: change_state(IDLE)
		RIGHTING:	if not pressing_right: change_state(IDLE)

func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return

	anim_state = new_state
	sprite.play(anim_state)

func _on_animation_finished() -> void:
	# 一次性动画播完后，自动切换到对应的循环动画
	match anim_state:
		LEFTING:
			change_state(LEFT)
		RIGHTING:
			change_state(RIGHT)

# ═══ Bomb（X 键） ═══

const BOMB_SPAWN_COUNT: int = 8
const BOMB_SPAWN_INTERVAL: float = 0.1
const BOMB_SPEED: float = 220.0
const BOMB_DAMAGE: float = 50.0
const BOMB_RADIUS: float = 45.0
const BOMB_INVINCIBLE_TIME: float = 4.0
const BOMB_BEHAVIOR = preload("res://scripts/bullet/bomb_behavior.gd")

func _bomb() -> void:
	if is_invincible:
		return
	if not GameState.use_bomb():
		return
	_play_sfx(AssetRegistry.sounds["card"], -6.0)
	# Bomb 期间短暂无敌
	is_invincible = true
	_invincible_timer = BOMB_INVINCIBLE_TIME
	var base_hue := RNG.randf()
	var tw := create_tween()
	for i in BOMB_SPAWN_COUNT:
		tw.tween_callback(_spawn_bomb_bullet.bind(i, base_hue))
		tw.tween_interval(BOMB_SPAWN_INTERVAL)


func _spawn_bomb_bullet(i: int, base_hue: float) -> void:
	var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(BOMB_SPAWN_COUNT))
	# 随机一个起始色相，后续按等间隔均匀增加，铺满整个色环
	var hue := fmod(base_hue + float(i) / float(BOMB_SPAWN_COUNT), 1.0)
	var color := Color.from_hsv(hue, 1.0, 1.0)
	var data := BulletData.new().tex("bomb01_white").bomb().behavior(BOMB_BEHAVIOR).color(color).dir(dir.x * BOMB_SPEED, dir.y * BOMB_SPEED)
	data.params = {"spawn_delay": float(i) * BOMB_SPAWN_INTERVAL}
	_play_sfx(AssetRegistry.sounds["shoot"], -6.0)
	BulletManager.shoot_bomb_bullet(data, global_position, dir)


# ═══ 释放记忆（C 键） ═══

const MEM_RELEASE_RANGE := 400.0
const MEM_RELEASE_DURATION := 0.75

func _memory_release() -> void:
	if is_invincible or GameState.memory_value < 50.0:
		return
	
	GameState.reduce_memory(50.0)
	var pos := global_position
	
	# 视觉特效：反色圈（走服务）
	_miss_circle(pos, MEM_RELEASE_DURATION, MEM_RELEASE_RANGE, 30, 0.0, 0.25)
	_play_sfx(AssetRegistry.sounds["kira"], -6.0)
	
	# 消弹 + 每颗弹原地掉道具（碎片有上限）
	var limits := {life = 0, bomb = 0}
	var on_clear := func(bullet_pos: Vector2):
		_spawn_one_item(bullet_pos, limits)
	
	# 场上已有道具全部飞向玩家
	_force_collect_all_items()
	
	_death_clear(pos, MEM_RELEASE_RANGE, MEM_RELEASE_DURATION, 30, on_clear)


func _force_collect_all_items() -> void:
	var pool := _find_item_pool()
	if not pool:
		return
	for child in pool.get_children():
		if child is Item and child.visible:
			child.force_collect()


func _spawn_one_item(at: Vector2, limits: Dictionary) -> void:
	const MAX_LIFE := 2
	const MAX_BOMB := 2
	
	var pool := _find_item_pool()
	if not pool:
		return
	
	var r := RNG.randf()
	var item_type: int
	
	# 碎片有上限，超限降级为跳过
	if r < 0.05 and limits.life < MAX_LIFE:
		item_type = Item.Type.LIFE_FRAGMENT
		limits.life += 1
	elif r < 0.1 and limits.bomb < MAX_BOMB:
		item_type = Item.Type.BOMB_FRAGMENT
		limits.bomb += 1
	elif r < 0.4:
		item_type = Item.Type.POWER
	elif r < 0.7:
		item_type = Item.Type.POINT
	else:
		return
	var item: Item = pool.spawn(at, item_type)
	if item:
		item.force_collect()


func _find_item_pool() -> Node:
	if _cached_item_pool:
		return _cached_item_pool
	var scene := get_tree().current_scene
	if not scene: return null
	var world := scene.get_node_or_null("World")
	if not world: return null
	_cached_item_pool = world.get_node_or_null("ItemPool")
	return _cached_item_pool


# ═══ Miss ═══

func miss() -> void:
	if is_invincible:
		return
	
	_play_sfx(AssetRegistry.sounds["player_die"], -6.0)
	var pos: Vector2 = global_position
	_miss_circle(pos, 2.5, 1280)
	_miss_circle(pos + Vector2(100, 0), 2.5, 1280)
	_miss_circle(pos + Vector2(-100, 0), 2.5, 1280)
	_miss_circle(pos + Vector2(0, 100), 2.5, 1280)
	_miss_circle(pos + Vector2(0, -100), 2.5, 1280)
	_miss_circle(pos, 1.0, 1280, 0.0, 1.5)
	
	_death_clear(pos, 2048, 3.0)
	
	# Miss 后记忆值增加 25%
	GameState.add_memory(GameState.MEMORY_MISS)
	
	# 每次 miss 都通知（boss 判定 miss 后不收；player_death 只在残机 0 发，不能复用）
	GameEvents.player_missed.emit()
	
	# 残机扣除
	if GameState.lose_life():
		# 无敌：倒计时 3 秒，_physics_process 自动倒数（不 await，不挂起调用链）
		is_invincible = true
		_invincible_timer = 3.0
	else:
		# 残机为 0 → Game Over，给短暂无敌防止每帧连续触发
		is_invincible = true
		_invincible_timer = 3.0
		GameEvents.player_death.emit()


# ═══ 系统操作服务（统一走 ctx 服务；ctx 为 null 时跳过，不回退全局） ═══

func _miss_circle(world_pos: Vector2, duration: float, max_radius: float,
		start_radius: float = 0.0, start_delay: float = 0.0, fade_out: float = 0.0) -> void:
	if ctx:
		ctx.effects.add_miss_circle(world_pos, duration, max_radius, start_radius, start_delay, fade_out)


func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if ctx:
		ctx.audio.play_sfx(stream, volume_db)


func _death_clear(pos: Vector2, max_radius: float, duration: float,
		start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	if ctx:
		ctx.bullets.death_clear(pos, max_radius, duration, start_radius, on_clear)
