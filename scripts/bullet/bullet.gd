# Bullet.gd
extends Node2D
class_name Bullet

const FACTION_PLAYER: int = 0
const FACTION_ENEMY: int = 1
const FACTION_BOMB: int = 2

# 基础属性
var damage: float = 10.0
var velocity: Vector2 = Vector2.UP
var accel: Vector2 = Vector2.ZERO  # 加速度（世界方向，px/s²）
var faction: int = FACTION_PLAYER
var can_be_canceled: bool = false
var hit_effect: PackedScene

# 判定区域
var hitbox_shape: int = BulletData.HitboxShape.CIRCLE
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_radius: float = 4.0
var hitbox_size: Vector2 = Vector2(8, 8)
var hitbox_rotation: float = 0.0

# 运行时状态
var coroutine_script: CoroutineScript
var out_grace: float = 0.0    ## 出界宽限（秒）：出界后仍存活；0 = 立即回收
var _out_time: float = 0.0    ## 当前连续出界时长（内部状态，界内重置）

var is_ready: bool = false

# 额外变量
var extra: Dictionary = {}
var _grazed: bool = false
var tint_mode: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var fog: BulletFog = $Fog


## 彻底重置所有运行时状态（池回收 + bind 复用时调用）
func _reset_state() -> void:
	is_ready = false
	_grazed = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	# 停旧协程
	if coroutine_script and is_instance_valid(coroutine_script):
		coroutine_script.stop()
		coroutine_script.queue_free()
		coroutine_script = null
	for child in get_children():
		if child is CoroutineScript:
			child.stop()
			child.queue_free()
	# 清雾
	fog.visible = false
	fog.texture = null
	if fog.fog_finished.is_connected(_on_fog_ready):
		fog.fog_finished.disconnect(_on_fog_ready)


func bind(data: BulletData, direction: Vector2):
	is_ready = false
	_grazed = false
	out_grace = data.out_grace
	_out_time = 0.0
	# 清理上次残留的协程（无节点模式：不再 add_child，直接停引用）
	if coroutine_script and is_instance_valid(coroutine_script):
		coroutine_script.stop()
		coroutine_script.queue_free()
		coroutine_script = null
	# 清理旧方案遗留的子节点协程（兼容）
	for child in get_children():
		if child is CoroutineScript:
			child.stop()
			remove_child(child)
			child.queue_free()
	match data.faction:
		FACTION_ENEMY:
			z_index = LayerConfig.ENEMY_BULLET
		FACTION_BOMB:
			z_index = LayerConfig.BOMB
		FACTION_PLAYER:
			z_index = LayerConfig.PLAYER_BULLET
		_:
			z_index = LayerConfig.ENEMY_BULLET

	sprite.texture = data.texture
	faction = data.faction
	tint_mode = data.tint_mode
	damage = data.damage
	extra["hit_sfx"] = data.hit_sfx  # 命中音效 key（空 = 默认）
	
	# 自机弹 2 倍大，敌弹 1 倍
	scale = Vector2.ONE
	
	# 自机子弹：记忆值越低越红
	sprite.modulate = data.tint
	if faction == FACTION_PLAYER:
		var mem: float = GameState.memory_value
		if mem < 50.0:
			var red := remap(mem, 0.0, 50.0, 1.0, 0.0)
			sprite.modulate = sprite.modulate.lerp(Color.RED, red * 0.5)
	can_be_canceled = data.can_be_canceled
	hit_effect = data.hit_effect

	hitbox_shape = data.hitbox_shape
	hitbox_offset = data.hitbox_offset
	hitbox_radius = data.hitbox_radius
	hitbox_size = data.hitbox_size
	hitbox_rotation = data.hitbox_rotation

	velocity = direction.normalized() * data.velocity.length()
	accel = data.accel  # 加速度世界方向（发射方向无关）
	self.rotation = direction.angle()

	if data.spawn_fog:
		sprite.visible = false  # 雾消失前隐藏子弹
		if fog.fog_finished.is_connected(_on_fog_ready):
			fog.fog_finished.disconnect(_on_fog_ready)
		fog.fog_finished.connect(_on_fog_ready, CONNECT_ONE_SHOT)
		fog.play(data.fog_texture, data.tint)
	else:
		fog.visible = false
		is_ready = true
		sprite.visible = not _uses_batch()  # 批量渲染时 Sprite 只作数据源（防双份叠加渲染）

	# 挂载移动协程：只有自定义脚本才走协程
	if data.coroutine_script:
		_start_coroutine(data)
	# 纯直线弹：只用 _physics_process
	
	# 确保可以移动
	process_mode = Node.PROCESS_MODE_INHERIT
	is_ready = true

func _on_fog_ready():
	sprite.visible = not _uses_batch()  # 雾结束：批量模式仍隐藏（数据源）
	is_ready = true


## 是否批量渲染（Sprite 隐藏；Modulate/纹理仍被 MultiMesh 读取）
func _uses_batch() -> bool:
	return BulletManager.use_multi_mesh

func _physics_process(_delta):
	if not is_ready:
		return
	var dt := get_physics_process_delta_time()
	if coroutine_script:
		# 快速路径：直接调 _tick（无节点 + 无调度器）
		if not coroutine_script.tick_fast(dt):
			# 协程结束：释放孤儿节点 + 清引用
			# 注意：_tick 内部可能已 return_bullet（_return_to_pool 已停并清空
			# coroutine_script）→ 此处先取局部再判空，避免 stop() 打在 Nil 上
			var cs := coroutine_script
			coroutine_script = null
			if cs:
				cs.stop()
				cs.queue_free()
		return
	# 匀加速：velocity += accel * dt（世界方向）
	velocity += accel * dt
	self.global_position += velocity * dt

func _start_coroutine(data: BulletData):
	coroutine_script = data.coroutine_script.new()
	assert(coroutine_script is CoroutineScript, "Bullet: coroutine must be a CoroutineScript")
	# 注入弹幕参数（与 EnemyData.params → 敌人行为脚本同一模式）
	for k in data.params:
		coroutine_script.set(k, data.params[k])
	# 无节点 + 快速路径 + 共享 ctx（不再每弹 new StageContext）
	# 由本子弹 _physics_process 直接调 _tick
	coroutine_script.start_fast(BulletManager.get_bullet_ctx(), self)

func batch_texture() -> Texture2D:
	return sprite.texture
