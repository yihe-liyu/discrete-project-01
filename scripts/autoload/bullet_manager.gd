# BulletManager.gd (Autoload) — 子弹/激光系统的门面
extends Node2D

# ═══ 子模块 ───
const PoolClass = preload("res://scripts/autoload/bullet/bullet_pool.gd")
const PhysicsClass = preload("res://scripts/autoload/bullet/bullet_physics.gd")
const LaserEngineClass = preload("res://scripts/laser/laser_engine.gd")
const DeathClearClass = preload("res://scripts/autoload/bullet/death_clear.gd")

var _pool: BulletPool
var _physics: BulletPhysics
var _lasers: LaserEngine
var _death_clear: DeathClear

## 暴露给 bullet_multi_mesh 等需要直接遍历子弹的地方
var active_bullets: Array:
	get: return _pool.active_bullets if _pool else []

var use_multi_mesh: bool = true
var _multi_mesh: Node2D
var _processing_paused: bool = false
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

# 共享子弹上下文：所有子弹协程共用一个 ctx（服务全部无状态）
# 省掉每弹 new StageContext + 服务对象（REFACTORING P-0 债务）
var _world_clock: CoroutineRunner
var _bullet_ctx: StageContext



## 子弹协程共享 ctx（active() = 世界时钟恒 true；子弹靠 target 失效停止）
func get_bullet_ctx() -> StageContext:
	return _bullet_ctx


func _ready():
	# 世界时钟：永久任务 → is_running 恒 true（子弹协程的 active() 语义 = 世界活跃）
	_world_clock = CoroutineRunner.new()
	_world_clock.name = "WorldClock"
	add_child(_world_clock)
	_world_clock.run(func() -> bool: return true)
	_bullet_ctx = StageContext.new(_world_clock)

	_pool = PoolClass.new()
	_pool.setup(self)
	_physics = PhysicsClass.new()
	_physics.setup(_pool)
	_lasers = LaserEngineClass.new()
	_lasers.setup(self, _physics)
	_death_clear = DeathClearClass.new()
	_death_clear.setup(_pool, _lasers)
	
	_pool.init_pool()
	
	if use_multi_mesh:
		_multi_mesh = BulletMultiMeshClass.new()
		_multi_mesh.enabled = true
		add_child(_multi_mesh)


# ═══ 每帧 ═══

func _physics_process(_delta: float) -> void:
	if _processing_paused:
		return
	# 统一用引擎时钟：time_scale 生效（工作台快进时激光/清弹同步加速）
	var dt := get_physics_process_delta_time()
	
	# 死亡清弹
	_death_clear.process(dt)
	
	# 激光步进 & 碰撞
	_lasers.step(dt)
	
	# 子弹碰撞
	_physics.process_collisions()
	
	# 出屏回收（out_grace：出界宽限内不回收——探测弹等飞出界仍可继续表现/往返）
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		var b: Bullet = _pool.active_bullets[i]
		if _pool.is_offscreen(b.global_position):
			if b.out_grace > 0.0:
				b._out_time += dt
				if b._out_time < b.out_grace:
					continue  # 宽限内：出界不回收（继续跑行为）
			_pool.return_bullet(b)
		else:
			b._out_time = 0.0  # 回到界内重置计时
	# 出屏回收（完）


# ═══ 子弹 API（委托给 pool）═══

func shoot_bullet(data, pos: Vector2, direction: Vector2):
	return _pool.shoot(data, pos, direction)

func shoot_player_bullet(data, pos: Vector2, direction: Vector2):
	return _pool.shoot(data, pos, direction)

func shoot_enemy_bullet(data, pos: Vector2, direction: Vector2):
	return _pool.shoot(data, pos, direction)

func shoot_bomb_bullet(data, pos: Vector2, direction: Vector2):
	return _pool.shoot(data, pos, direction)

func return_bullet(bullet):
	_pool.return_bullet(bullet)


## 原地重新发射：复用现有子弹（重配置），替代"回收旧弹 + 新建新弹"的拆/建开销。
## 用于"旧弹变成新弹"这一类（NON01 反弹→直线、radial 撞边→向下等）。
## 注意：会 stop 掉旧行为协程、重放雾；bullet 仍在 active_bullets 中，不回收不新建。
func re_fire(bullet: Bullet, data: BulletData, dir: Vector2, at: Vector2) -> void:
	bullet.bind(data, dir)
	bullet.global_position = at


# ═══ 激光 API（新引擎 Laser 2.0）═══
# 返回 LaserBeam（可配置 core_width / hitbox_width / graze_width 等）

## 骨架级生成（配合 LaserPresets 预设）—— 最灵活的入口
func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	return _lasers.spawn(skeleton, color, opts)

## 生长型曲线激光（沿 Curve2D 头部生长，尾部跟随）
func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_curve(curve, color, {"grow": true, "grow_speed": speed, "tail": tail, "lifetime": lifetime, "tex": tex})

## 直线激光（瞬间全开）
func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_line(a, b, color, {"grow": false, "lifetime": lifetime, "tex": tex})

## 固定曲线激光（瞬间全开沿曲线）
func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 10.0, tex: Texture2D = null) -> LaserBeam:
	return _lasers.spawn_curve(curve, color, {"grow": false, "lifetime": lifetime, "tex": tex})

func clear_all_lasers() -> void:
	_lasers.clear()


# ═══ 死亡清弹（委托给 death_clear）═══

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius, on_clear)


# ═══ 全局清理 ═══

func clear_all():
	_pool.clear()
	_lasers.clear()
	_death_clear.clear_all()
	HitEffectPool.clear_all_pool()
	if _multi_mesh:
		_multi_mesh.clear()

func clear_bullets():
	_pool.clear()

func pause_processing() -> void:
	_processing_paused = true

func resume_processing() -> void:
	_processing_paused = false
