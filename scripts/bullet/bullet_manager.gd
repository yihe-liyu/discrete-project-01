## 弹幕世界：持有内核弹池、碰撞/行为管道、激光引擎、死亡清弹与 MultiMesh 渲染。
##
## [b]模型[/b][br]
## 由组合根创建并注入（不是 autoload）：
## [codeblock]
## BulletManager (Node2D)
##  ├─ CoroutineRunner "WorldClock"  → 共享 StageContext
##  ├─ KernelBulletHost             → 内核弹池 + 行为管道
##  ├─ KernelBulletPhysics          → 碰撞 / 擦弹 / 清弹
##  ├─ LaserEngine                  → 激光
##  ├─ DeathClear                   → 死亡清弹圈
##  └─ BulletMultiMesh              → 渲染
## [/codeblock]
## 游戏运行时一律走组合根注入；[member current] 只给测试 / 调试 / 工作台。
## [br]
## [b]边界[/b][br]
## - 唯一后端是内核（[KernelBulletHost]），没有旧池回退。[br]
## - 发射不区分自机 / 敌弹，阵营由 [code]BulletData.faction[/code] 决定。[br]
## - 清场分裸清（[method clear_bullets]）与带消散特效（[method clear_enemy_bullets_with_fx]），不要混用。[br]
## - [method reset_world] 只给工具 / 工作台；正常游戏换 scene 重建 Manager 天然重置。
class_name BulletManager
extends Node2D

## 当前弹幕世界（组合根 _ready 登记）。
## 只给测试 / 调试 / 工作台；游戏运行时走组合根注入，不读本静态。
static var current: BulletManager

## 敌弹出生雾（阵营默认；按弹型 is_spawn_fog 开关）。
const ENEMY_SPAWN_FX: EffectType = preload("res://data/fx/enemy_spawn_fx.tres")

# ═══ 子模块 ───

var _laser_engine: LaserEngine
var _death_clear: DeathClear
var _multi_mesh: Node2D
var _is_processing_paused: bool = false

## 内核弹幕后端（唯一后端）
var _kernel_bullet_host: KernelBulletHost
var _kernel_bullet_physics: KernelBulletPhysics

# 组合根注入的特效层（空则静默）
var _fx_pool: FxPool
## 组合根注入的特效层；空则静默。只读，唯一写入口是 [method inject_fx_pool]。
var fx_pool: FxPool:
	get:
		return _fx_pool

## 组合根注入的视觉父节点（World）——炸弹爆炸贴图挂此（不再全树找 scene/World）
var fx_parent: Node2D

# 组合根注入的实体注册表（自机 / 敌机 / Boss）；未注入 = null
var _entity_registry: EntityRegistry
## 组合根注入的实体注册表（自机 / 敌机 / Boss）；未注入 = null。只读，唯一写入口是 [method inject_entity_registry]。
var entity_registry: EntityRegistry:
	get:
		return _entity_registry

# 共享子弹上下文
var _coroutine_runner: CoroutineRunner
var _stage_context: StageContext


## 内核活跃行数（含纯特效行，不等于弹数；统计/断言用）。
func active_count() -> int:
	return _kernel_bullet_host.system.get_active_count() if _kernel_bullet_host != null else 0


## 子弹协程共享 ctx（由 WorldClock 驱动，宿主绑定的 stage 经 [method inject_stage_runtime] 注入）。
func get_bullet_ctx() -> StageContext:
	return _stage_context


## 组合根注入特效层（唯一写入口），转发给内核碰撞/清弹模块
func inject_fx_pool(pool: FxPool) -> void:
	_fx_pool = pool
	if _kernel_bullet_physics:
		_kernel_bullet_physics.fx_pool = pool


func _ready():
	BulletManager.current = self
	_coroutine_runner = CoroutineRunner.new()
	_coroutine_runner.name = "WorldClock"
	add_child(_coroutine_runner)
	_coroutine_runner.run(func() -> bool: return true)
	_stage_context = StageContext.new(_coroutine_runner)
	RNG.seed_changed.connect(_on_rng_seed_changed)   # RNG 是唯一随机真源，内核 RNG 跟随同 seed
	_laser_engine = LaserEngine.new()
	_laser_engine.setup(self, Callable(self, "_on_laser_graze"))
	_death_clear = DeathClear.new()
	_death_clear.setup(_laser_engine, Callable(self, "_sweep_death_clear"))
	_multi_mesh = BulletMultiMesh.new()
	_multi_mesh.is_enabled = true
	add_child(_multi_mesh)
	_enable_kernel()


func _exit_tree() -> void:
	if RNG.seed_changed.is_connected(_on_rng_seed_changed):
		RNG.seed_changed.disconnect(_on_rng_seed_changed)
	if BulletManager.current == self:
		BulletManager.current = null


func _physics_process(_delta: float) -> void:
	if _is_processing_paused:
		return
	var dt := get_physics_process_delta_time()
	_death_clear.process(dt)
	_laser_engine.step(dt)
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.process()


# ═══ 子弹 API（内核后端）═══

## 发射一颗弹，返回内核行 id（data 为空 = -1）。阵营由 [code]BulletData.faction[/code] 决定。
## direction 只定方向（零向量 = 用 data.velocity 的方向）；速度大小取 data.velocity 的长度。
func shoot_bullet(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	return _kernel_bullet_host.shoot(data, pos, direction)

## 按内核行 id 取当前 lifecycle phase（无效 / 后端未初始化 → -1）。
func bullet_phase(id: int) -> int:
	if _kernel_bullet_host == null or _kernel_bullet_host.system == null:
		return -1
	return _kernel_bullet_host.system.get_phase(id)


## 按内核行 id 取速度（无效 / 后端未初始化 → ZERO）。
func bullet_velocity(id: int) -> Vector2:
	if _kernel_bullet_host == null or _kernel_bullet_host.system == null:
		return Vector2.ZERO
	return _kernel_bullet_host.system.get_velocity(id)


## 按内核行 id 取全局位置（id 越界/已回收 → Vector2.ZERO）。
## 热路径不查它；调试/测试（“这颗弹出生在哪”）用，免得外面去摸内核宿主的私有存储。
func bullet_global_position(id: int) -> Vector2:
	if _kernel_bullet_host == null or id < 0:
		return Vector2.ZERO
	if id >= _kernel_bullet_host.system.get_active_count():
		return Vector2.ZERO
	return global_position + _kernel_bullet_host.system.get_position(id)


## 炸弹：返回宿主节点（不进内核弹池）。data 是 BombData；MistBombData → KernelMistBomb，其余 → KernelBomb。
## tint / spawn_delay 逐颗透传给炸弹实体。
func shoot_bomb_bullet(data: BombData, pos: Vector2, direction: Vector2, tint: Color = Color.WHITE, spawn_delay: float = 0.0) -> Node:
	return _kernel_bullet_host.spawn_bomb(data, pos, direction, tint, spawn_delay)


# ═══ 激光 API ═══

## 统一激光生成入口：骨架 + 颜色 + opts（grow / grow_speed / tail / lifetime / core_width / hitbox_width / graze_width / tex）。
## 返回池中的 LaserBeam；池未初始化时可能为 null。
func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	return _laser_engine.spawn(skeleton, color, opts)

## 生长型曲线激光：头部按 speed（px/s）前进，尾距 tail，lifetime 秒后消失。
func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_curve(curve, color, {"grow": true, "grow_speed": speed, "tail": tail, "lifetime": lifetime, "tex": tex})

## 固定直线激光（a → b），lifetime 秒后消失。
func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_line(a, b, color, {"grow": false, "lifetime": lifetime, "tex": tex})

## 固定曲线激光，lifetime 秒后消失。
func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 10.0, tex: Texture2D = null) -> LaserBeam:
	return _laser_engine.spawn_curve(curve, color, {"grow": false, "lifetime": lifetime, "tex": tex})

## 清空所有激光（含生长中的），全部回池。
func clear_all_lasers() -> void:
	_laser_engine.clear()


# ═══ 形状内清敌弹（炸弹持续清弹）═══

## 圆内清敌弹（逐颗播消散特效）。
func clear_enemy_bullets_in_circle(center: Vector2, radius: float) -> void:
	clear_enemy_bullets_in_shape(center, radius, Callable())


## 外接圆 (center, radius) 内 + inside(pos) 判定清敌弹（炸弹椭圆等非圆形状走这里）。
## inside 为空 = 整个圆；只清 ENEMY 阵营，逐颗播消散特效。
func clear_enemy_bullets_in_shape(center: Vector2, radius: float, inside: Callable) -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.sweep_enemy_bullets(center, radius, Callable(), inside)


# ═══ 死亡清弹 ═══

## 起一个死亡清弹圈：半径从 start_radius 扩到 max_radius，持续 duration 秒。
## 每帧清掉圆内敌弹（逐颗消散特效 + on_clear 回调），并切掉碰到圈的生长激光头。
func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius, on_clear)


func _sweep_death_clear(center: Vector2, radius: float, on_clear: Callable) -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.sweep_enemy_bullets(center, radius, on_clear)


func _on_laser_graze() -> void:
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.on_graze()


# ═══ 全局清理 ═══

## 全清：内核弹池 + 炸弹 + 激光 + 死亡清弹圈 + 特效池 + MultiMesh。
## 裸清，不逐颗播消散；要消散特效用 [method clear_enemy_bullets_with_fx]。
func clear_all():
	if _kernel_bullet_host != null:
		_kernel_bullet_host.system.clear()
		_kernel_bullet_host.clear_bombs()
	_laser_engine.clear()
	_death_clear.clear_all()
	if fx_pool:
		fx_pool.clear_pool()
	if _multi_mesh:
		_multi_mesh.clear()

## 清掉魔理沙非 focus 激光段（LASER kind）；子机重建/熄火时调用。
func clear_laser_bullets() -> void:
	if _kernel_bullet_host != null:
		_kernel_bullet_host.clear_laser_bullets()


## 裸清弹 + 炸弹；不动激光 / 死亡清弹圈 / 特效。关卡收尾用。
## 内容“清屏”要看消散特效时走 [method clear_enemy_bullets_with_fx]。
func clear_bullets():
	if _kernel_bullet_host != null:
		_kernel_bullet_host.system.clear()
		_kernel_bullet_host.clear_bombs()


## 全屏清敌弹并逐颗播消散特效（即时、无动画）。
## 与 [method clear_bullets] 的分工：那个是裸清（无特效），关卡收尾用；本方法给内容“清屏”要看得见时用
## （[code]ctx.bullets.clear_enemy_bullets()[/code]）。半径取场地对角线（约 1600），比 cull 范围只大不小。
## 只清 ENEMY 阵营；先收集再统一 despawn + 播消散特效。
func clear_enemy_bullets_with_fx() -> void:
	var r: float = Vector2(GameConfig.VIEW_WIDTH, GameConfig.VIEW_HEIGHT).length()
	clear_enemy_bullets_in_circle(GameConfig.SCREEN_CENTER, r)


## 清场 + 回收内核注册表（program / 弹型 / 纹理句柄）。只给工具 / 工作台：
## 原生 program 表只增不减，反复重建内容脚本（新 BulletData）会积累；正常游戏换 scene 重建 Manager 天然重置。
func reset_world() -> void:
	clear_all()
	if _kernel_bullet_host != null:
		_kernel_bullet_host.reset_registries()

## 暂停弹幕推进（死亡清弹 / 激光 / 内核物理）；与 [method resume_processing] 成对。
func pause_processing() -> void:
	_is_processing_paused = true
	if _kernel_bullet_host != null:
		_kernel_bullet_host.system.set_physics_process(false)

## 恢复弹幕推进。
func resume_processing() -> void:
	_is_processing_paused = false
	if _kernel_bullet_host != null:
		_kernel_bullet_host.system.set_physics_process(true)


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
	if _kernel_bullet_host != null and _kernel_bullet_host.system != null:
		_kernel_bullet_host.system.set_seed(seed_value)


## 当前内核弹池（未装配 = null）
func kernel_system() -> KernelNativeSystem:
	return _kernel_bullet_host.system if _kernel_bullet_host != null else null


## 建内核后端（幂等）：帧序 / 剔除范围 / 渲染数据源 / 行为管道
func _enable_kernel() -> void:
	if _kernel_bullet_host == null:
		_kernel_bullet_host = KernelBulletHost.new()
		_kernel_bullet_host.name = "KernelBulletHost"
		add_child(_kernel_bullet_host)
		_kernel_bullet_physics = KernelBulletPhysics.new()
		_kernel_bullet_physics.setup(_kernel_bullet_host)
		_kernel_bullet_physics.fx_pool = fx_pool
		_kernel_bullet_host.system.process_physics_priority = -10
		_kernel_bullet_host.system.cull_rect = Rect2(
			GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
		_kernel_bullet_host.system.cull_margin = 90.0
		_kernel_bullet_host.system.set_seed(RNG.get_seed())   # 内核 RNG 从宿主 seed 派生
		_kernel_bullet_host.system.set_spawn_fx(BulletType.Faction.ENEMY, ENEMY_SPAWN_FX)
	# 只认注入，不回退全局
	if _kernel_bullet_host != null:
		_kernel_bullet_host.entity_registry = entity_registry
		_kernel_bullet_host.bullet_manager = self
	if _kernel_bullet_physics != null:
		_kernel_bullet_physics.entity_registry = entity_registry
	if _laser_engine != null:
		_laser_engine.entity_registry = entity_registry
	var p: Node2D = null
	var enemy_provider := Callable()
	if entity_registry != null:
		if is_instance_valid(entity_registry.player):
			p = entity_registry.player
		enemy_provider = Callable(entity_registry, "get_targetable_enemies")   # 只喂可选目标（未开战 Boss 不算）
	_kernel_bullet_host.setup_behaviors(p, enemy_provider)
	if _multi_mesh != null:
		_multi_mesh.set_backend(_kernel_bullet_host)
