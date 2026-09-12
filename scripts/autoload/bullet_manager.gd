# BulletManager.gd (Autoload) — 子弹/激光系统的门面（W4a-2：内核唯一后端）
extends Node2D

# ═══ 子模块 ───
const LaserEngineClass = preload("res://scripts/laser/laser_engine.gd")
const DeathClearClass = preload("res://scripts/autoload/bullet/death_clear.gd")
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

var _lasers: LaserEngine
var _death_clear: DeathClear
var _multi_mesh: Node2D
var _processing_paused: bool = false

## 内核弹幕后端（W4a-2 起唯一后端）
var _kernel: KernelBulletBackend
var _kernel_physics: KernelBulletPhysics

## W2：组合根注入的特效层（空则静默）
var fx_layer: FxLayer

# 共享子弹上下文
var _world_clock: CoroutineRunner
var _bullet_ctx: StageContext


## 当前活跃弹数（统计/断言用）
func active_count() -> int:
	return _kernel.system.get_active_count() if _kernel != null else 0


## 子弹协程共享 ctx
func get_bullet_ctx() -> StageContext:
	return _bullet_ctx


## W2：组合根注入特效层，转发给内核碰撞/清弹模块
func inject_fx_layer(fx: FxLayer) -> void:
	fx_layer = fx
	if _kernel_physics:
		_kernel_physics.fx = fx


func _ready():
	_world_clock = CoroutineRunner.new()
	_world_clock.name = "WorldClock"
	add_child(_world_clock)
	_world_clock.run(func() -> bool: return true)
	_bullet_ctx = StageContext.new(_world_clock)
	_lasers = LaserEngineClass.new()
	_lasers.setup(self, Callable(self, "_on_laser_graze"))
	_death_clear = DeathClearClass.new()
	_death_clear.setup(_lasers, Callable(self, "_sweep_death_clear"))
	_multi_mesh = BulletMultiMeshClass.new()
	_multi_mesh.enabled = true
	add_child(_multi_mesh)
	_enable_kernel()
	inject_fx_layer(fx_layer)


func _physics_process(_delta: float) -> void:
	if _processing_paused:
		return
	var dt := get_physics_process_delta_time()
	_death_clear.process(dt)
	_lasers.step(dt)
	if _kernel_physics != null:
		_kernel_physics.process()


# ═══ 子弹 API（内核后端）═══

func shoot_bullet(data, pos: Vector2, direction: Vector2):
	return _kernel.shoot(data, pos, direction)

func shoot_player_bullet(data, pos: Vector2, direction: Vector2):
	return _kernel.shoot(data, pos, direction)

func shoot_enemy_bullet(data, pos: Vector2, direction: Vector2):
	return _kernel.shoot(data, pos, direction)

func shoot_bomb_bullet(data, pos: Vector2, direction: Vector2):
	return _kernel.spawn_bomb(data, pos, direction)


## 回收一颗弹（内容是内核行 id）
func return_bullet(bullet) -> void:
	if typeof(bullet) == TYPE_INT:
		_kernel.system.despawn(bullet)


## 原地重新发射：回收旧行 + 按新配置重发
func re_fire(bullet, data: BulletData, dir: Vector2, at: Vector2) -> void:
	if typeof(bullet) == TYPE_INT:
		_kernel.system.despawn(bullet)
	_kernel.shoot(data, at, dir)


# ═══ 激光 API ═══

func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	return _lasers.spawn(skeleton, color, opts)

func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_curve(curve, color, {"grow": true, "grow_speed": speed, "tail": tail, "lifetime": lifetime, "tex": tex})

func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_line(a, b, color, {"grow": false, "lifetime": lifetime, "tex": tex})

func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 10.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_curve(curve, color, {"grow": false, "lifetime": lifetime, "tex": tex})

func clear_all_lasers() -> void:
	_lasers.clear()


# ═══ 圆内清敌弹（炸弹持续清弹）═══

func clear_enemy_bullets_in_circle(center: Vector2, radius: float) -> int:
	if _kernel_physics != null:
		_kernel_physics.sweep_enemy_bullets(center, radius, Callable())
	return 0


# ═══ 死亡清弹 ═══

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius, on_clear)


func _sweep_death_clear(center: Vector2, radius: float, on_clear: Callable) -> void:
	if _kernel_physics != null:
		_kernel_physics.sweep_enemy_bullets(center, radius, on_clear)


func _on_laser_graze() -> void:
	if _kernel_physics != null:
		_kernel_physics.on_graze()


# ═══ 全局清理 ═══

func clear_all():
	if _kernel != null:
		_kernel.system.clear()
		_kernel.clear_bombs()
	_lasers.clear()
	_death_clear.clear_all()
	if fx_layer:
		fx_layer.clear_pool()
	if _multi_mesh:
		_multi_mesh.clear()

func clear_bullets():
	if _kernel != null:
		_kernel.system.clear()
		_kernel.clear_bombs()

func pause_processing() -> void:
	_processing_paused = true
	if _kernel != null:
		_kernel.system.set_physics_process(false)

func resume_processing() -> void:
	_processing_paused = false
	if _kernel != null:
		_kernel.system.set_physics_process(true)


# ═══ 内核后端装配 ═══

## 组合根在自机就绪后调用：刷新行为管道的自机引用
func refresh_kernel_player() -> void:
	if _kernel != null:
		_enable_kernel()


## 当前内核弹池（未装配 = null）
func kernel_system() -> BulletSystem:
	return _kernel.system if _kernel != null else null


## 建内核后端（幂等）：帧序 / 剔除范围 / 渲染数据源 / 行为管道
func _enable_kernel() -> void:
	if _kernel == null:
		_kernel = KernelBulletBackend.new()
		_kernel.name = "KernelBulletBackend"
		add_child(_kernel)
		_kernel_physics = KernelBulletPhysics.new()
		_kernel_physics.setup(_kernel)
		_kernel_physics.fx = fx_layer
		_kernel.system.process_physics_priority = -10
		_kernel.system.cull_rect = Rect2(
			GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
		_kernel.system.cull_margin = 90.0
	var p: Node2D = null
	if is_instance_valid(GameState.player):
		p = GameState.player
	_kernel.setup_behaviors(p, Callable(GameState, "get_active_enemies"))
	if _multi_mesh != null:
		_multi_mesh.set_backend(_kernel)
