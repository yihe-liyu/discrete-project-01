## 弹幕 / 激光世界（W4c：由组合根创建并注入，不再是 autoload）。
## 单实例由组合根持有；跨切面（切场 / 工作台 / 调试）经 `current`（R8 static）。
class_name BulletManager
extends Node2D

## 当前弹幕世界（组合根 `_ready` 登记；工具/切场回退用）
static var current: BulletManager

# ═══ 子模块 ───
const LaserEngineClass = preload("res://scripts/laser/laser_engine.gd")
const DeathClearClass = preload("res://scripts/bullet/death_clear.gd")
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

var _lasers: LaserEngine
var _death_clear: DeathClear
var _multi_mesh: Node2D
var _processing_paused: bool = false

## 内核弹幕后端（W4a-2 起唯一后端）
var _kernel: KernelBulletBackend
var _kernel_physics: KernelBulletPhysics

## W2：组合根注入的特效层（空则静默）
var fx_pool: FxPool

## K4：组合根注入的视觉父节点（World）——炸弹爆炸贴图挂此（不再全树找 scene/World）
var fx_parent: Node2D

## W4b-3b：组合根注入的实体注册表（自机 / 敌机 / Boss）；空则回退当前世界
var world_refs: EntityRegistry

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
func inject_fx_pool(fx: FxPool) -> void:
	fx_pool = fx
	if _kernel_physics:
		_kernel_physics.fx = fx


func _ready():
	BulletManager.current = self
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
	inject_fx_pool(fx_pool)


func _exit_tree() -> void:
	if BulletManager.current == self:
		BulletManager.current = null


func _physics_process(_delta: float) -> void:
	if _processing_paused:
		return
	var dt := get_physics_process_delta_time()
	_death_clear.process(dt)
	_lasers.step(dt)
	if _kernel_physics != null:
		_kernel_physics.process()


# ═══ 子弹 API（内核后端）═══

## 发射一颗弹。阵营由 `data.faction` 决定（自机弹 / 敌弹同一条路）；返回内核行 id（data 为空 = -1）。
func shoot_bullet(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	return _kernel.shoot(data, pos, direction)

## 炸弹：返回宿主节点（KernelBomb，不进内核池）。
func shoot_bomb_bullet(data: BulletData, pos: Vector2, direction: Vector2) -> Node:
	return _kernel.spawn_bomb(data, pos, direction)


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

func clear_enemy_bullets_in_circle(center: Vector2, radius: float) -> void:
	if _kernel_physics != null:
		_kernel_physics.sweep_enemy_bullets(center, radius, Callable())


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
	if fx_pool:
		fx_pool.clear_pool()
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

## 注入本次关卡的实体注册表（自机 / 敌机 / Boss）；组合根装配后调用
func inject_world_refs(refs: EntityRegistry) -> void:
	world_refs = refs
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
		_kernel_physics.fx = fx_pool
		_kernel.system.process_physics_priority = -10
		_kernel.system.cull_rect = Rect2(
			GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
		_kernel.system.cull_margin = 90.0
	var refs := world_refs if world_refs != null else EntityRegistry.current
	if _kernel != null:
		_kernel.refs = refs
		_kernel.world = self
	if _kernel_physics != null:
		_kernel_physics.refs = refs
	if _lasers != null:
		_lasers.refs = refs
	var p: Node2D = null
	var enemy_provider := Callable()
	if refs != null:
		if is_instance_valid(refs.player):
			p = refs.player
		enemy_provider = Callable(refs, "get_active_enemies")
	_kernel.setup_behaviors(p, enemy_provider)
	if _multi_mesh != null:
		_multi_mesh.set_backend(_kernel)
