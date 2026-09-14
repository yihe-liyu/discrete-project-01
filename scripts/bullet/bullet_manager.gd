## 弹幕 / 激光世界（由组合根创建并注入，不再是 autoload）。
## 单实例由组合根持有；跨切面（切场 / 工作台 / 调试）经 `current`（R8 static）。
class_name BulletManager
extends Node2D

## 当前弹幕世界（组合根 `_ready` 登记）。
## **仅供测试 / 调试 / 工作台** 使用；游戏运行时路径一律走组合根注入，不读本静态。
static var current: BulletManager

# ═══ 子模块 ───
const LaserEngineClass = preload("res://scripts/laser/laser_engine.gd")
const DeathClearClass = preload("res://scripts/bullet/death_clear.gd")
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

var _laser_engine: LaserEngine
var _death_clear: DeathClear
var _multi_mesh: Node2D
var _processing_paused: bool = false

## 内核弹幕后端（唯一后端）
var _kernel_bullet_backend: KernelBulletBackend
var _kernel_bullet_physics: KernelBulletPhysics

## 组合根注入的特效层（空则静默）。**只读** —— 唯一写入口是 `inject_fx_pool()`。
var _fx_pool: FxPool
var fx_pool: FxPool:
	get:
		return _fx_pool

## 组合根注入的视觉父节点（World）——炸弹爆炸贴图挂此（不再全树找 scene/World）
var fx_parent: Node2D

## 组合根注入的实体注册表（自机 / 敌机 / Boss）。**只读** —— 唯一写入口是 `inject_entity_registry()`。
## 不再回退 EntityRegistry.current；未注入 = null（碰撞/行为数据源为空）。
var _entity_registry: EntityRegistry
var entity_registry: EntityRegistry:
	get:
		return _entity_registry

# 共享子弹上下文
var _coroutine_runner: CoroutineRunner
var _stage_context: StageContext


## 当前活跃弹数（统计/断言用）
func active_count() -> int:
	return _kernel_bullet_backend.system.get_active_count() if _kernel_bullet_backend != null else 0


## 子弹协程共享 ctx
func get_bullet_ctx() -> StageContext:
	return _stage_context


## 组合根注入特效层（唯一写入口），转发给内核碰撞/清弹模块
func inject_fx_pool(fx: FxPool) -> void:
	_fx_pool = fx
	if _kernel_bullet_physics:
		_kernel_bullet_physics.fx = fx


func _ready():
	BulletManager.current = self
	_coroutine_runner = CoroutineRunner.new()
	_coroutine_runner.name = "WorldClock"
	add_child(_coroutine_runner)
	_coroutine_runner.run(func() -> bool: return true)
	_stage_context = StageContext.new(_coroutine_runner)
	RNG.seed_changed.connect(_on_rng_seed_changed)   # RNG 是唯一随机真源，内核 RNG 跟随同 seed
	_laser_engine = LaserEngineClass.new()
	_laser_engine.setup(self, Callable(self, "_on_laser_graze"))
	_death_clear = DeathClearClass.new()
	_death_clear.setup(_laser_engine, Callable(self, "_sweep_death_clear"))
	_multi_mesh = BulletMultiMeshClass.new()
	_multi_mesh.enabled = true
	add_child(_multi_mesh)
	_enable_kernel()


func _exit_tree() -> void:
	if RNG.seed_changed.is_connected(_on_rng_seed_changed):
		RNG.seed_changed.disconnect(_on_rng_seed_changed)
	if BulletManager.current == self:
		BulletManager.current = null


func _physics_process(_delta: float) -> void:
	if _processing_paused:
		return
	var dt := get_physics_process_delta_time()
	_death_clear.process(dt)
	_laser_engine.step(dt)
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.process()


# ═══ 子弹 API（内核后端）═══

## 发射一颗弹。阵营由 `data.faction` 决定（自机弹 / 敌弹同一条路）；返回内核行 id（data 为空 = -1）。
func shoot_bullet(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	return _kernel_bullet_backend.shoot(data, pos, direction)

## 炸弹：返回宿主节点（KernelBomb，不进内核池）。
func shoot_bomb_bullet(data: BulletData, pos: Vector2, direction: Vector2) -> Node:
	return _kernel_bullet_backend.spawn_bomb(data, pos, direction)


# ═══ 激光 API ═══

func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	return _laser_engine.spawn(skeleton, color, opts)

func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_curve(curve, color, {"grow": true, "grow_speed": speed, "tail": tail, "lifetime": lifetime, "tex": tex})

func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_line(a, b, color, {"grow": false, "lifetime": lifetime, "tex": tex})

func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 10.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_curve(curve, color, {"grow": false, "lifetime": lifetime, "tex": tex})

func clear_all_lasers() -> void:
	_laser_engine.clear()


# ═══ 圆内清敌弹（炸弹持续清弹）═══

func clear_enemy_bullets_in_circle(center: Vector2, radius: float) -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.sweep_enemy_bullets(center, radius, Callable())


# ═══ 死亡清弹 ═══

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius, on_clear)


func _sweep_death_clear(center: Vector2, radius: float, on_clear: Callable) -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.sweep_enemy_bullets(center, radius, on_clear)


func _on_laser_graze() -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.on_graze()


# ═══ 全局清理 ═══

func clear_all():
	if _kernel_bullet_backend != null:
		_kernel_bullet_backend.system.clear()
		_kernel_bullet_backend.clear_bombs()
	_laser_engine.clear()
	_death_clear.clear_all()
	if fx_pool:
		fx_pool.clear_pool()
	if _multi_mesh:
		_multi_mesh.clear()

func clear_bullets():
	if _kernel_bullet_backend != null:
		_kernel_bullet_backend.system.clear()
		_kernel_bullet_backend.clear_bombs()

func pause_processing() -> void:
	_processing_paused = true
	if _kernel_bullet_backend != null:
		_kernel_bullet_backend.system.set_physics_process(false)

func resume_processing() -> void:
	_processing_paused = false
	if _kernel_bullet_backend != null:
		_kernel_bullet_backend.system.set_physics_process(true)


# ═══ 内核后端装配 ═══

## 注入本次关卡的实体注册表（自机 / 敌机 / Boss）；组合根装配后调用（唯一写入口）
func inject_entity_registry(p_entity_registry: EntityRegistry) -> void:
	_entity_registry = p_entity_registry
	_enable_kernel()


## 注入本次关卡的 StageRuntime —— 让共享子弹 ctx 显式拿到 stage（不再回退全局）。
func inject_stage_runtime(stage: StageRuntime) -> void:
	if _stage_context != null:
		_stage_context.stage = stage


## 宿主 RNG 是唯一随机真源；任一处 set_seed/randomize 都同步内核 RNG 的 seed。
func _on_rng_seed_changed(seed_value: int) -> void:
	if _kernel_bullet_backend != null and _kernel_bullet_backend.system != null:
		_kernel_bullet_backend.system.set_seed(seed_value)


## 当前内核弹池（未装配 = null）
func kernel_system() -> KernelNativeSystem:
	return _kernel_bullet_backend.system if _kernel_bullet_backend != null else null


## 建内核后端（幂等）：帧序 / 剔除范围 / 渲染数据源 / 行为管道
func _enable_kernel() -> void:
	if _kernel_bullet_backend == null:
		_kernel_bullet_backend = KernelBulletBackend.new()
		_kernel_bullet_backend.name = "KernelBulletBackend"
		add_child(_kernel_bullet_backend)
		_kernel_bullet_physics = KernelBulletPhysics.new()
		_kernel_bullet_physics.setup(_kernel_bullet_backend)
		_kernel_bullet_physics.fx = fx_pool
		_kernel_bullet_backend.system.process_physics_priority = -10
		_kernel_bullet_backend.system.cull_rect = Rect2(
			GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
		_kernel_bullet_backend.system.cull_margin = 90.0
		_kernel_bullet_backend.system.set_seed(RNG.get_seed())   # 内核 RNG 从宿主 seed 派生
	# 只认注入，不回退 EntityRegistry.current
	if _kernel_bullet_backend != null:
		_kernel_bullet_backend.entity_registry = entity_registry
		_kernel_bullet_backend.bullet_manager = self
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.entity_registry = entity_registry
	if _laser_engine != null:
		_laser_engine.entity_registry = entity_registry
	var p: Node2D = null
	var enemy_provider := Callable()
	if entity_registry != null:
		if is_instance_valid(entity_registry.player):
			p = entity_registry.player
		enemy_provider = Callable(entity_registry, "get_active_enemies")
	_kernel_bullet_backend.setup_behaviors(p, enemy_provider)
	if _multi_mesh != null:
		_multi_mesh.set_backend(_kernel_bullet_backend)
