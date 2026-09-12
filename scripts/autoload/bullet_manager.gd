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

## ═══ Track A / S3a：内核弹幕后端（Strangler 开关）═══
## true = 弹幕走内核 SoA 池（scripts/kernel/）+ 内核渲染数据源；false = 旧 Bullet 节点池（默认）。
## 切换：游戏内按 **F2**（运行时热键，见 _unhandled_input），或 set_use_kernel()（测试）。
## **碰撞规则不在本步**，见 docs/NEW_KERNEL_REFACTOR_PLAN.md §16。
var use_kernel: bool = false
var _kernel: KernelBulletBackend
var _kernel_physics: KernelBulletPhysics

# 共享子弹上下文：所有子弹协程共用一个 ctx（服务全部无状态）
# 省掉每弹 new StageContext + 服务对象（REFACTORING P-0 债务）
var _world_clock: CoroutineRunner
var _bullet_ctx: StageContext



## 子弹协程共享 ctx（active() = 世界时钟恒 true；子弹靠 target 失效停止）
func get_bullet_ctx() -> StageContext:
	return _bullet_ctx


## 试玩 A/B 热键：F2 在「旧 Bullet 节点池」与「内核 SoA 池」之间切换（默认旧池，零源码改动）。
func _ensure_kernel_toggle_action() -> void:
	if InputMap.has_action(&"kernel_toggle"):
		return
	InputMap.add_action(&"kernel_toggle")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F2
	InputMap.action_add_event(&"kernel_toggle", ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"kernel_toggle"):
		set_use_kernel(not use_kernel)
		print("[BulletManager] use_kernel = %s" % use_kernel)


func _ready():
	_ensure_kernel_toggle_action()
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
	_death_clear.setup(_pool, _lasers, Callable(self, "_kernel_sweep_death_clear"))
	
	_pool.init_pool()
	
	if use_multi_mesh:
		_multi_mesh = BulletMultiMeshClass.new()
		_multi_mesh.enabled = true
		add_child(_multi_mesh)
	
	if use_kernel:
		_enable_kernel()


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
	
	if not use_kernel:
		# ── 旧路径（Bullet 节点池）──
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
	else:
		# 内核路径：积分 / 剔除由 BulletSystem._physics_process（priority -10）先跑；
		# 宿主（priority 0）在此做碰撞派发。S3b = 敌弹 ↔ 自机；S3c 再补自机弹↔敌人 / bomb / 死亡清弹。
		if _kernel_physics != null:
			_kernel_physics.process()


# ═══ 子弹 API（委托给 pool）═══

func shoot_bullet(data, pos: Vector2, direction: Vector2):
	if use_kernel and _kernel != null:
		return _kernel.shoot(data, pos, direction)
	return _pool.shoot(data, pos, direction)

func shoot_player_bullet(data, pos: Vector2, direction: Vector2):
	if use_kernel and _kernel != null:
		return _kernel.shoot(data, pos, direction)
	return _pool.shoot(data, pos, direction)

func shoot_enemy_bullet(data, pos: Vector2, direction: Vector2):
	if use_kernel and _kernel != null:
		return _kernel.shoot(data, pos, direction)
	return _pool.shoot(data, pos, direction)

func shoot_bomb_bullet(data, pos: Vector2, direction: Vector2):
	if use_kernel and _kernel != null:
		return _kernel.spawn_bomb(data, pos, direction)   # S4d：bomb 走宿主节点（out_grace 缘由）
	return _pool.shoot(data, pos, direction)

func return_bullet(bullet):
	# 内核路径：内容是 int id（Track A / S3）；旧池：Bullet 节点。
	if use_kernel and _kernel != null and typeof(bullet) == TYPE_INT:
		_kernel.system.despawn(bullet)
		return
	_pool.return_bullet(bullet)


## 原地重新发射：复用现有子弹（重配置），替代"回收旧弹 + 新建新弹"的拆/建开销。
## 用于"旧弹变成新弹"这一类（NON01 反弹→直线、radial 撞边→向下等）。
## 注意：会 stop 掉旧行为协程、重放雾；bullet 仍在 active_bullets 中，不回收不新建。
func re_fire(bullet, data: BulletData, dir: Vector2, at: Vector2) -> void:
	# 内核路径：内容是 int id → 近似实现为「回收旧行 + 按新配置重发」（行为差异见方案 §19）。
	if use_kernel and _kernel != null and typeof(bullet) == TYPE_INT:
		_kernel.system.despawn(bullet)
		_kernel.shoot(data, at, dir)
		return
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


# ═══ 圆内清敌弹（炸弹持续清弹 / 圆清除；双后端）═══

const _CLEAR_EFFECT = preload("res://scenes/effect/enemy_bullet_clear.tscn")

## 清掉 center/radius 内的敌弹（不扩张、立即），逐弹播消散特效。返回清除数（内核路径暂返回 0）。
func clear_enemy_bullets_in_circle(center: Vector2, radius: float) -> int:
	if use_kernel and _kernel != null:
		if _kernel_physics != null:
			_kernel_physics.sweep_enemy_bullets(center, radius, Callable())
		return 0
	var cleared: int = 0
	var r2: float = radius * radius
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		var b: Bullet = _pool.active_bullets[i]
		if not is_instance_valid(b) or b.is_queued_for_deletion() or b.faction != Bullet.FACTION_ENEMY or not b.is_ready:
			continue
		if b.global_position.distance_squared_to(center) <= r2:
			HitEffectPool.play(_CLEAR_EFFECT, b.global_position, Vector2.ZERO, b.sprite.modulate)
			_pool.return_bullet(b)
			cleared += 1
	return cleared


# ═══ 死亡清弹（委托给 death_clear）═══

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius, on_clear)


## 死亡清弹的双后端扫掠（DeathClear 每帧回调）：内核路径返回 true（已清完），
## 旧池路径返回 false（交回 DeathClear 原逐弹循环）。Track A / S3d。
func _kernel_sweep_death_clear(center: Vector2, radius: float, on_clear: Callable) -> bool:
	if not use_kernel or _kernel == null or _kernel_physics == null:
		return false
	_kernel_physics.sweep_enemy_bullets(center, radius, on_clear)
	return true


# ═══ 全局清理 ═══

func clear_all():
	_pool.clear()
	if _kernel != null:
		_kernel.system.clear()
		_kernel.clear_bombs()
	_lasers.clear()
	_death_clear.clear_all()
	HitEffectPool.clear_all_pool()
	if _multi_mesh:
		_multi_mesh.clear()

func clear_bullets():
	_pool.clear()
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


# ═══ Track A / S3a：内核后端装配与切换 ═══

## 当前内核弹池（未装配 = null）；供工具 / 测试读快照。
func kernel_system() -> BulletSystem:
	return _kernel.system if _kernel != null else null


## 切换弹幕后端（Strangler）。切到内核会先清空旧池，避免两套并存。
func set_use_kernel(v: bool) -> void:
	if v == use_kernel:
		return
	use_kernel = v
	if v:
		_pool.clear()          # 避免旧弹残留在两条路之间
		_enable_kernel()
	else:
		if _kernel != null:
			_kernel.system.clear()
		if _multi_mesh != null:
			_multi_mesh.set_backend(null)


## 建内核后端（幂等）：设帧序 / 剔除范围 / 渲染数据源。
func _enable_kernel() -> void:
	if _kernel == null:
		_kernel = KernelBulletBackend.new()
		_kernel.name = "KernelBulletBackend"
		add_child(_kernel)
		_kernel_physics = KernelBulletPhysics.new()   # S3b：宿主侧碰撞规则（敌弹↔自机）
		_kernel_physics.setup(_kernel)
		# 帧序：内核积分必须在宿主 _physics_process（priority 0）之前执行（§16.3；原项目暂无 FrameOrder）。
		_kernel.system.process_physics_priority = -10
		# 剔除范围 = 东方框；margin 对齐旧 is_offscreen 的 90px。
		_kernel.system.cull_rect = Rect2(
			GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
		_kernel.system.cull_margin = 90.0
	# S4a：行为管道（幂等）——每次都刷新自机引用（player 可能刚生成 / 已换 / 测试里已释放）。
	var p: Node2D = null
	if is_instance_valid(GameState.player):
		p = GameState.player
	_kernel.setup_behaviors(p, Callable(GameState, "get_active_enemies"))
	if _multi_mesh != null:
		_multi_mesh.set_backend(_kernel)
