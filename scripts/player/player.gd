# entities/player/player.gd
extends Area2D
class_name Player

@onready var _hit_point_display: HitPointDisplay = $HitPointDisplay
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

const FRONT_UP: float = GameConfig.FIELD_TOP
const FRONT_DOWN: float = GameConfig.FIELD_BOTTOM
const FRONT_LEFT: float = GameConfig.FIELD_LEFT
const FRONT_RIGHT: float = GameConfig.FIELD_RIGHT
const MIN_MARGIN: int = 8

## 关卡上下文（StageRuntime/game_scene 注入，系统操作走服务）
var ctx: StageContext
## 单局资源（Player 是 owner；消费者经 EntityRegistry 取同一实例）。
## 惰性创建：任何读取都保证非 null（无需 _ready 判空自建），也允许入树前预注入。
var _player_resources: PlayerResources
var resources: PlayerResources:
	get:
		if _player_resources == null:
			_player_resources = PlayerResources.new()
		return _player_resources
	set(v):
		_player_resources = v


const IDLE = &"idle"
const LEFTING = &"lefting"
const LEFT = &"left"
const RIGHTING = &"righting"
const RIGHT = &"right"
var anim_state: StringName = IDLE

var input_vector: Vector2 = Vector2.ZERO
var is_focused: bool = false
var is_invincible: bool = false
var _invincible_timer: float = 0.0
## 中弹后自机移动的**最终位置** = 复位点（默认 `MISS_RESPAWN_POS` = "正中偏下"）。
## 两步里的**第二步终点**；第一步是瞬移到 `MISS_RESPAWN_FROM`（框下正中）。
var _respawn_pos: Vector2 = MISS_RESPAWN_POS
## 中弹复位移动进行中 → 锁移动输入（tween 正在写 position，别跟输入抢）
var _is_respawning: bool = false

var hitbox_radius: float = 5.0
var graze_radius: float = 40.0  # 擦弹判定半径

## 玩家机体数据（速度、动画、武器等）
@export var player_data: PlayerData
var _player_shoot_script: PlayerShootScript

# 移动速度（像素/秒）
var focus_speed: int
var normal_speed: int
var current_speed: int

func _ready() -> void:
	z_index = LayerConfig.PLAYER
	# 连接 animation_finished 信号，用于检测一次性动画播完
	animation.animation_finished.connect(_on_animation_finished)
	# 击破入账（原全局状态处理，迁来）
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)

	setup_character(player_data)


func _exit_tree() -> void:
	if GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(score: int, _position: Vector2) -> void:
	resources.add_score(score)


## R4：离散动作（解放记忆 / 炸弹）走事件，不在物理帧轮询
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("memory_release"):
		_memory_release()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel&bomb"):
		_bomb()
		get_viewport().set_input_as_handled()

## 注入/切换机体：应用数值 + (重)装配射击。同数据且已装配 → 跳过（幂等，避免组合根重复初始化）。
func setup_character(data: PlayerData) -> void:
	if data == player_data and _player_shoot_script != null:
		return
	player_data = data
	apply_player_data()
	reinit_shoot()


# 应用机体数据
func apply_player_data() -> void:
	if player_data == null:
		push_error("Player: 未设置 PlayerData 资源！")
		return

	focus_speed = player_data.focus_speed
	normal_speed = player_data.normal_speed
	current_speed = normal_speed

	if animation and player_data.animation:
		animation.sprite_frames = player_data.animation
		animation.play(IDLE)

func _physics_process(delta):
	# 记忆值自动恢复（原全局状态 _process，迁来）
	resources.regen(delta)
	# 无敌倒计时（替代 await，不挂起调用链）
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false

	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	is_focused = Input.is_action_pressed("focus")

	update_hitbox_display()
	update_animation()
	update_move(delta)

func _init_shoot_script() -> void:
	if not player_data or not player_data.shoot_script:
		return
	_player_shoot_script = player_data.shoot_script.new()
	assert(_player_shoot_script is PlayerShootScript, "Player: shoot_script must be a PlayerShootScript")
	add_child(_player_shoot_script)
	var shoot_ctx := StageContext.new(_player_shoot_script)
	shoot_ctx.stage = ctx.stage if ctx else null   # 无 stage 的射击 ctx 显式绑定关卡
	_player_shoot_script.start_shooting(shoot_ctx)

## 切换角色时重新初始化射击
func reinit_shoot() -> void:
	if _player_shoot_script:
		_player_shoot_script.stop()
		_player_shoot_script.queue_free()
		_player_shoot_script = null
	_init_shoot_script()


## 绑定关卡上下文（组合根注入）：把 stage 一并转发给射击 ctx。
## StageContext 不再回退全局；自机射击 ctx 与关卡 ctx 共用同一 StageRuntime。
func bind_ctx(p_ctx: StageContext) -> void:
	ctx = p_ctx
	if _player_shoot_script != null and _player_shoot_script.ctx != null:
		_player_shoot_script.ctx.stage = p_ctx.stage if p_ctx != null else null

func update_hitbox_display() -> void:
	if is_focused:
		_hit_point_display.show_hitpoint()
	else:
		_hit_point_display.hide_hitpoint()

func update_move(delta: float) -> void:
	if _is_respawning:
		return  # 复位移动期间锁输入（位置由 tween 写）
	var move_input: Vector2 = input_vector
	# 归一化对角线速度，使斜向移动速度不增加
	if move_input.length() > 1.0: move_input = move_input.normalized()

	current_speed = focus_speed if is_focused else normal_speed

	position += move_input * current_speed * delta

	# 位置限制
	position.x = clamp(position.x, FRONT_LEFT + MIN_MARGIN * 3, FRONT_RIGHT - MIN_MARGIN * 3)
	position.y = clamp(position.y, FRONT_UP + MIN_MARGIN * 4, FRONT_DOWN - MIN_MARGIN * 4)

func update_animation() -> void:
	var is_pressing_left: bool = input_vector.x < -0.1
	var is_pressing_right: bool = input_vector.x > 0.1

	if (is_pressing_left and is_pressing_right) or (not is_pressing_left and not is_pressing_right):
		change_state(IDLE)
		return

	# 根据当前状态和输入，决定下一个状态
	match anim_state:
		IDLE:
			if		is_pressing_left and not is_pressing_right: change_state(LEFTING)
			elif	is_pressing_right and not is_pressing_left: change_state(RIGHTING)
		LEFTING:	if not is_pressing_left:  change_state(IDLE)
		LEFT:		if not is_pressing_left:  change_state(IDLE)
		RIGHT:		if not is_pressing_right: change_state(IDLE)
		RIGHTING:	if not is_pressing_right: change_state(IDLE)

func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return

	anim_state = new_state
	animation.play(anim_state)

func _on_animation_finished() -> void:
	# 一次性动画播完后，自动切换到对应的循环动画
	match anim_state:
		LEFTING:
			change_state(LEFT)
		RIGHTING:
			change_state(RIGHT)

# ═══ Bomb（X 键） ═══

## bomb 数据在 player_data.bomb（BombData）；编队/运动/爆炸全由它决定。
func _bomb() -> void:
	if is_invincible:
		return
	var bomb_data: BombData = player_data.bomb if player_data else null
	if bomb_data == null:
		push_warning("Player._bomb：player_data.bomb 未配置（BombData）")
		return
	if not resources.use_bomb():
		return
	_play_sfx(AssetRegistry.sounds["player_card"])
	GameEvents.player_bomb.emit(bomb_data.name)
	GameEvents.field_filter.emit(bomb_data.field_filter_color)
	# Bomb 期间短暂无敌
	is_invincible = true
	_invincible_timer = bomb_data.invincible_time
	var base_hue := RNG.randf()
	var tween := create_tween()
	for i in bomb_data.count:
		tween.tween_callback(_spawn_bomb_bullet.bind(i, base_hue))
		tween.tween_interval(bomb_data.interval)


func _spawn_bomb_bullet(i: int, base_hue: float) -> void:
	var bomb_data: BombData = player_data.bomb if player_data else null
	if bomb_data == null:
		return
	var count := maxi(bomb_data.count, 1)
	var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count))
	var tint := bomb_data.tint_for(i, base_hue)
	_play_sfx(AssetRegistry.sounds["shoot"])
	if ctx:
		ctx.bullets.shoot_bomb(bomb_data, global_position, dir, tint, float(i) * bomb_data.interval)


# ═══ 释放记忆（C 键） ═══

const MEM_RELEASE_RANGE := 400.0
const MEM_RELEASE_DURATION := 0.75

func _memory_release() -> void:
	if is_invincible or resources.memory_value < 50.0:
		return

	resources.reduce_memory(50.0)
	var pos := global_position

	# 视觉特效：反色圈（走服务）
	_miss_circle(pos, MEM_RELEASE_DURATION, MEM_RELEASE_RANGE, 30, 0.0, 0.25)
	_play_sfx(AssetRegistry.sounds["kira"])

	# 消弹 + 每颗弹原地掉道具（碎片有上限）
	var limits := {life = 0, bomb = 0}
	var on_clear := func(bullet_pos: Vector2):
		_spawn_one_item(bullet_pos, limits)

	# 场上已有道具全部飞向玩家
	_force_collect_all_items()

	_death_clear(pos, MEM_RELEASE_RANGE, MEM_RELEASE_DURATION, 30, on_clear)


func _force_collect_all_items() -> void:
	var pool: ItemPool = _find_item_pool()
	if not pool:
		return
	for child in pool.get_children():
		if child is Item and child.visible:
			child.force_collect()


## Miss 的"赔偿点"：在自机处撒 MISS_POWER_COUNT 个 P 点，绕自机**向上 180° 均匀弧形**
## （中轴 = 正上方，含两端点 → 10 个点相邻 20°），**左右夹在场地框内**（贴墙时靠墙一侧横向压扁、
## 纵向半径不变 → 连同随后竖直下落的轨迹都不会出框）。两段式：
## ① 沿弧向飞到目标点（`MISS_POWER_HANG` 秒，期间不被吸附）→
## ② 径向初速归零 → **竖直下落**（`Item.burst` 的语义）。走 `ctx.items` 服务；无 ctx（单测/无舞台）时安全跳过。
func _spawn_miss_power_fan(pos: Vector2) -> void:
	if ctx == null:
		return
	var targets := ItemService.fan_targets(MISS_POWER_COUNT, pos, Vector2.UP,
			MISS_POWER_SPREAD_DEG, MISS_POWER_RADIUS,
			FRONT_LEFT + MISS_POWER_MARGIN, FRONT_RIGHT - MISS_POWER_MARGIN)
	ctx.items.spawn_fan(Item.Type.POWER, pos, targets, MISS_POWER_HANG)


func _spawn_one_item(at: Vector2, limits: Dictionary) -> void:
	const MAX_LIFE := 2
	const MAX_BOMB := 2

	var pool: ItemPool = _find_item_pool()
	if not pool:
		return

	var roll := RNG.randf()
	var item_type: int

	# 碎片有上限，超限降级为跳过
	if roll < 0.05 and limits.life < MAX_LIFE:
		item_type = Item.Type.LIFE_FRAGMENT
		limits.life += 1
	elif roll < 0.1 and limits.bomb < MAX_BOMB:
		item_type = Item.Type.BOMB_FRAGMENT
		limits.bomb += 1
	elif roll < 0.4:
		item_type = Item.Type.POWER
	elif roll < 0.7:
		item_type = Item.Type.POINT
	else:
		return
	var item: Item = pool.spawn(at, item_type)
	if item:
		item.force_collect()


func _find_item_pool() -> ItemPool:
	if ctx == null or ctx.stage == null:
		return null
	return ctx.stage.item_pool


# ═══ Miss ═══

## Miss 撒出的 P 点数量（绕自机、向上均匀半圆）
const MISS_POWER_COUNT: int = 10
## 扇形总张角：180° = 向上半圆（含两端点 → 相邻 20°）
const MISS_POWER_SPREAD_DEG: float = 180.0
## 两段式的第一段：沿弧向飞 `MISS_POWER_HANG` 秒，飞到 `MISS_POWER_RADIUS` 处
const MISS_POWER_HANG: float = 0.45
## 弧半径（px）。**必须 > `Item.PROXIMITY_RANGE`(128)**：否则弧飞完那一刻就落进吸附圈被吸走，
## 第二段"竖直下落"根本看不到（`test_player` 有一条契约测试守着这个不等式）。
const MISS_POWER_RADIUS: float = 240.0
## 左右留白（px）：道具贴图 32×32，整张也要留在场地框内 → 目标点横坐标夹在 [框左+16, 框右−16]
const MISS_POWER_MARGIN: float = 16.0
## 中弹复位移动的**起点**（第一步瞬移到这里）：水平正中、**场地框下方之外**（船从框下升进场）。
const MISS_RESPAWN_FROM := Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_BOTTOM + 96.0)
## 中弹复位移动的**终点**默认值（第二步走到这里）= "正中偏下"（场地底部上方 88px、水平正中）
const MISS_RESPAWN_POS := Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_BOTTOM - 120.0)
## 复位移动时长（秒）
const MISS_RESPAWN_TIME: float = 1.0

func miss() -> void:
	if is_invincible:
		return

	_play_sfx(AssetRegistry.sounds["player_die"])
	var pos: Vector2 = global_position
	_miss_circle(pos, 2.5, 1280)
	_miss_circle(pos + Vector2(100, 0), 2.5, 1280)
	_miss_circle(pos + Vector2(-100, 0), 2.5, 1280)
	_miss_circle(pos + Vector2(0, 100), 2.5, 1280)
	_miss_circle(pos + Vector2(0, -100), 2.5, 1280)
	_miss_circle(pos, 1.0, 1280, 0.0, 1.5)

	_death_clear(pos, 2048, 3.0)

	# Miss 后记忆值增加 25%
	resources.add_memory(PlayerResources.MEMORY_MISS)

	# 火力惩罚（原作口径）：miss 削 50 火力（clamp 0..300）
	resources.on_miss_power_penalty()

	# 在自机处撒 10 个 P 点：绕自机、向上 180° 均匀弧形（宽限内不被吸走，先飞成弧）
	_spawn_miss_power_fan(pos)

	# 每次 miss 都通知（boss 判定 miss 后不收；player_death 只在残机 0 发，不能复用）
	GameEvents.player_missed.emit()

	# 残机扣除
	if resources.lose_life():
		# 无敌：倒计时 3 秒，_physics_process 自动倒数（不 await，不挂起调用链）
		is_invincible = true
		_invincible_timer = 3.0
	else:
		# 残机为 0 → Game Over，给短暂无敌防止每帧连续触发
		is_invincible = true
		_invincible_timer = 3.0
		GameEvents.player_death.emit()

	# ── 自机复位（**必须放在最后**）────────────────────────────────────────
	# 上面所有演出/撒点用的都是 `pos`（中弹那一刻的位置）——反色圈必须留在中弹处，
	# 所以移动自机这件事只能在最后做，否则圈会画到移动后的位置上。
	# ① 瞬移到**场地框下方之外**（水平正中）—— 让船从框下升进来
	global_position = MISS_RESPAWN_FROM
	# ② 从那里移动到 `_respawn_pos`（复位点 = 终点）
	_move_to_respawn()


## 中弹复位第二步：从 `MISS_RESPAWN_FROM`（框下正中）移动到 `_respawn_pos`（复位点），期间锁移动输入。
func _move_to_respawn() -> void:
	if _is_respawning:
		return
	_is_respawning = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", _respawn_pos, MISS_RESPAWN_TIME)
	tween.finished.connect(func() -> void: _is_respawning = false)


# ═══ 系统操作服务（统一走 ctx 服务；ctx 为 null 时跳过，不回退全局） ═══

func _miss_circle(world_pos: Vector2, duration: float, max_radius: float,
		start_radius: float = 0.0, start_delay: float = 0.0, fade_out: float = 0.0) -> void:
	if ctx:
		ctx.effects.add_miss_circle(world_pos, duration, max_radius, start_radius, start_delay, fade_out)


func _play_sfx(stream: AudioStream, volume_db: float = AudioManager.SFX_LEVEL_DB) -> void:
	if ctx:
		ctx.audio.play_sfx(stream, volume_db)


func _death_clear(pos: Vector2, max_radius: float, duration: float,
		start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	if ctx:
		ctx.bullets.death_clear(pos, max_radius, duration, start_radius, on_clear)
