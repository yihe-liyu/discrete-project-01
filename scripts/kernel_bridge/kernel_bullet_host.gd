## SpawnSpec → BulletType 的宿主适配器。
##
## 原生内核不认识 SpawnSpec；弹型由 [code]SpawnSpec.to_bullet_type()[/code] 在内容侧缓存。
## lifecycle 由 SpawnSpec 直接携带，按计划编译成原生 program。
## 渲染不在本类：纹理走 [code]texture_for_index()[/code]，由 BulletMultiMesh 消费。
class_name KernelBulletHost
extends Node

## 行为内 emit 出来的弹（含子代）落库后广播稳定 uid；正常 shoot 不发这个信号。
signal behavior_bullet_spawned(uid: int, lifecycle: BulletLifecycle)

const MARISA_LASER_FADE_SCRIPT = preload("res://scripts/kernel_bridge/marisa_laser_fade.gd")
const KERNEL_BOMB_SCRIPT = preload("res://scripts/kernel_bridge/kernel_bomb.gd")
const KERNEL_MIST_BOMB_SCRIPT = preload("res://scripts/kernel_bridge/kernel_mist_bomb.gd")
const KERNEL_BEHAVIOR_HOST_SCRIPT = preload("res://scripts/kernel_bridge/kernel_behavior_host.gd")

## 内核弹池（原生权威，必需）。
var system: KernelNativeSystem
## 实体注册表（自机 / 敌机 / Boss；BulletManager 注入）
var entity_registry: EntityRegistry
## 弹幕世界（BulletManager 注入）——bomb 宿主节点反查用
var bullet_manager: BulletManager
var _texture_by_index: Array[Texture2D] = []   # 纹理句柄表（render socket）：弹型下标 → 贴图

## 内核行为上下文（由 BulletManager 装配）。
var behavior_ctx: BehaviorContext
## 桥接行为的延后动作队列（re_fire / 分裂不能在内核行为循环中途做）。
var _behavior_host
## 魔理沙激光整批渐隐控制器。
var _laser_fade
## 宿主节点 bomb（不进内核池；内核 cull 无 per-type 宽限）。
var _bombs: Array[Node] = []


func _ready() -> void:
	_ensure_system()


## 当前自机的单局资源（经注册表取）；无自机 = null
func _player_res() -> PlayerResources:
	return entity_registry.get_player_resources() if entity_registry != null else null


## 重置内核注册表（回收 program / 弹型 / 纹理句柄表 / 端口探测）。清场后调用（工作台重开演）。
## 纹理句柄表与弹型表按下标对齐 —— 弹型清空则句柄表必须一起清，否则索引错位。
func reset_registries() -> void:
	_texture_by_index.clear()
	if system != null:
		system.reset_registries()


## 生成宿主节点 bomb（返回节点，供调用方忽略/持有）。data 是 BombData（炸弹走宿主节点，不进内核池）。
## 宿主实体由 data 的实际类型决定（MistBombData → KernelMistBomb；其余/基类 → KernelBomb）。
func spawn_bomb(data: BombData, pos: Vector2, direction: Vector2, tint: Color = Color.WHITE, spawn_delay: float = 0.0) -> Node:
	# 用 if/else 而非三元：两个分支是兄弟类（KernelMistBomb / KernelBomb），
	# 三元要求分支类型互相兼容，静态分析会报 INCOMPATIBLE_TERNARY。
	var bomb: BombEntity
	if data is MistBombData:
		bomb = KERNEL_MIST_BOMB_SCRIPT.new()
	else:
		bomb = KERNEL_BOMB_SCRIPT.new()
	bomb.entity_registry = entity_registry
	bomb.bullet_manager = bullet_manager
	bomb.fx_parent = bullet_manager.fx_parent if bullet_manager else null
	add_child(bomb)
	_bombs.append(bomb)
	bomb.setup(data, pos, direction, tint, spawn_delay)
	return bomb


## 行为 emit_laser 的落地点：平移骨架后交给 BulletManager 的 LaserEngine。
func spawn_behavior_laser(skeleton: LaserSkeleton, color: Color,
		opts: Dictionary, offset: Vector2, direction: Vector2 = Vector2.ZERO) -> LaserBeam:
	if bullet_manager == null or skeleton == null:
		return null
	var points := skeleton.points
	if direction != Vector2.ZERO and points.size() >= 2:
		var base := points[points.size() - 1] - points[0]
		if base.length_squared() > 0.0001:
			var angle := base.angle_to(direction)
			var rotated := PackedVector2Array()
			for point in points:
				rotated.append(point.rotated(angle))
			points = rotated
	if offset != Vector2.ZERO:
		var shifted := PackedVector2Array()
		for point in points:
			shifted.append(point + offset)
		points = shifted
	var final_skeleton := skeleton
	if points != skeleton.points:
		final_skeleton = LaserSkeleton.new()
		final_skeleton.from_points(points)
	return bullet_manager.spawn_laser(final_skeleton, color, opts)


## 清掉所有 LASER 类子弹（魔理沙非 focus 激光段；供子机重建 / 熄火时清锚点）。
## 倒序：system.despawn 是 swap-with-last。
func clear_laser_bullets() -> void:
	if system == null:
		return
	for i in range(system.get_active_count() - 1, -1, -1):
		var bt := system.get_type(i)
		if bt != null and bt.kind == BulletType.Kind.LASER:
			system.despawn(i)


## 清掉所有宿主 bomb（换关/重开）。
func clear_bombs() -> void:
	for b in _bombs:
		if is_instance_valid(b):
			b.queue_free()
	_bombs.clear()


## 懒建内核弹池（幂等）：不强依赖节点已在树中。
func _ensure_system() -> void:
	if system != null:
		return
	system = KernelNativeSystem.new()
	system.name = "KernelBulletSystem"
	if not system.is_native_ready():
		push_error("[KernelBulletHost] 原生扩展未加载：本项目已要求 GDExtension（见 docs/archive/N2_NATIVE_INTEGRATION_PLAN.md §63）")
	add_child(system)
	system.emit_spawner = Callable(self, "_spawn_emit_template")
	system.laser_spawner = Callable(self, "_spawn_laser_template")


## 行为循环结束后统一执行延后的 re_fire / 分裂（内核契约：循环中途禁止增删行）。
func _physics_process(delta: float) -> void:
	flush_behavior_host()
	if _laser_fade != null:
		_laser_fade.process(delta)


## 执行延后动作队列（幂等：队列空则 no-op）。BulletManager 也会调一次作兜底。
func flush_behavior_host() -> void:
	if _behavior_host != null:
		_behavior_host.flush()


## KernelNativeSystem 的 behavior 激光回调。
func _spawn_laser_template(template: LaserTemplate, pos: Vector2, direction: Vector2) -> void:
	if template == null or template.skeleton == null:
		push_error("[KernelBulletHost] LaserTemplate 无效")
		return
	var offset := template.offset
	if template.at_current:
		offset += pos
	spawn_behavior_laser(template.skeleton, template.color, template.opts, offset, direction)


## KernelNativeSystem 的 behavior emit 回调：模板 → 实际 spawn。
func _spawn_emit_template(template: EmitTemplate, pos: Vector2, vel: Vector2, color: Color) -> void:
	if template == null:
		push_error("[KernelBulletHost] emit template 无效")
		return
	var spec := template.spawn_spec
	if spec == null:
		push_error("[KernelBulletHost] emit template 没有 spawn_spec")
		return
	spec.velocity = vel
	if color != Color.WHITE:
		spec.color(color)
	if template.behavior != null:
		spec.behavior_spec = template.behavior
	var dir := vel.normalized() if vel.length_squared() > 0.000001 else Vector2.DOWN
	spawn_prepared(prepare_spec(spec, pos, dir))


## 解析一次 SpawnSpec 发射所需的 per-shot 状态（类型 / 速度 / 行为 / 染色），不写内核池。
func prepare_spec(spec: SpawnSpec, pos: Vector2, direction: Vector2) -> Dictionary:
	if spec == null:
		return {}
	_ensure_system()
	var type := spec.to_bullet_type()
	var speed: float = spec.velocity.length()
	var vel: Vector2 = direction.normalized() * speed if direction != Vector2.ZERO else spec.velocity
	var move: StringName = &""
	var params: Variant = null
	if spec.lifecycle != null:
		move = LifecycleCatalog.MOVE_LIFECYCLE
		params = {&"lifecycle": spec.lifecycle, &"anchor": spec.lifecycle_anchor}
	if spec.kind == BulletType.Kind.LASER and _laser_fade != null:
		_laser_fade.on_laser_spawned()
	var tint: Color = spec.tint
	if spec.faction == SpawnSpec.Faction.PLAYER:
		var res := _player_res()
		if res != null and res.memory_value < 50.0:
			tint = tint.lerp(Color.RED, remap(res.memory_value, 0.0, 50.0, 1.0, 0.0) * 0.5)
	return {type = type, pos = pos, vel = vel, tint = tint, move = move, params = params,
		texture = spec.texture, behavior = spec.behavior_spec}


func shoot_spec(spec: SpawnSpec, pos: Vector2, direction: Vector2) -> int:
	return spawn_prepared(prepare_spec(spec, pos, direction))


## 把 prepare_spec 的快照写入内核池（延后队列 flush 用；也可直接调）。
func spawn_prepared(spec: Dictionary) -> int:
	if spec.is_empty():
		return -1
	var id: int = system.spawn(spec.type, spec.pos, spec.vel, spec.tint, spec.move, spec.params)
	if id >= 0:
		var behavior: BehaviorSpec = spec.get("behavior")
		if behavior != null:
			var bid: int = system.get_behavior_id(String(behavior.id))
			if bid < 0:
				push_error("[KernelBulletHost] 未注册的 native behavior：%s" % behavior.id)
			elif not system.set_behavior(id, bid, behavior.params):
				push_error("[KernelBulletHost] set_behavior 失败：%s" % behavior.id)
	_sync_host_tables(id, spec.texture)
	return id


## 行为队列 flush 后通知：把 emit 子代接到 uid / lifecycle（路径跟踪用）。
func notify_behavior_spawned(id: int, spec: Dictionary) -> void:
	if id < 0 or system == null:
		return
	var uid: int = system.get_uid(id)
	if uid <= 0:
		return
	var params: Variant = spec.get("params")
	if params is Dictionary:
		var lifecycle: BulletLifecycle = params.get(&"lifecycle")
		if lifecycle != null:
			behavior_bullet_spawned.emit(uid, lifecycle)


## 纹理句柄 → 贴图（渲染插座；未映射/越界 = null）。
func texture_for_index(index: int) -> Texture2D:
	if index < 0 or index >= _texture_by_index.size():
		return null
	return _texture_by_index[index]


## 特效下标 → 贴图（渲染插座；出生雾/消弹共用同一特效表）。
func fx_texture_for_index(index: int) -> Texture2D:
	var fx: Array[EffectType] = system.get_fx_registry() if system != null else []
	if index < 0 or index >= fx.size():
		return null
	return fx[index].texture


## 装配内核行为管道（幂等；可重复调以刷新自机引用）。
## 优先级：内核积分 -10 → 行为 -5 → 宿主碰撞 0（靠显式 process_physics_priority 定序）。
func setup_behaviors(player: Node2D, enemy_provider: Callable) -> void:
	_ensure_system()
	if behavior_ctx == null:
		behavior_ctx = BehaviorContext.new()
		behavior_ctx.setup(player, WorldQuery.new())
	if enemy_provider.is_valid():
		behavior_ctx.get_world().setup(enemy_provider)   # 可重复注入（测试 / 换关）
	behavior_ctx.setup(player, behavior_ctx.get_world())   # 刷新自机
	if system.enable_native_behaviors:
		return
	process_physics_priority = -4   # 延后动作 flush：行为之后、宿主碰撞(0) 之前
	_behavior_host = KERNEL_BEHAVIOR_HOST_SCRIPT.new()
	_behavior_host.setup(self)
	_laser_fade = MARISA_LASER_FADE_SCRIPT.new()
	_laser_fade.setup(self)
	# 行为全程原生（behavior_tick）；宿主回调（emit/call）经 behavior_host。
	system.enable_native_behaviors = true
	system.behavior_ctx = behavior_ctx
	system.behavior_host = _behavior_host
	system.boss_getter = func(): return _behavior_host.get_boss()


func _sync_host_tables(id: int, texture: Texture2D) -> void:
	var ti: int = system.get_type_index(id)
	if _texture_by_index.size() <= ti:
		_texture_by_index.resize(ti + 1)
	_texture_by_index[ti] = texture
