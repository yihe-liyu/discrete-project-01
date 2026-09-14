## KernelBulletBackend——宿主侧适配：BulletData → BulletType。
##
## 边界：内核不认识 BulletData；弹型由 `BulletData.to_bullet_type()` 在
## **内容侧**产出并缓存（内容须复用 BulletData 实例；每发 new 会让内核弹型表每发长一个）。
##
## `coroutine_script` 走 duck-typed `kernel_port()` 端口映射到内核行为（可选覆盖）；
## `BulletData.accel` 走桥接 `world_accel`。未映射（无端口）仍按直线发射并计入 unmapped。
## 渲染不在本类：纹理走**渲染插座**（纹理句柄表 `texture_for_index`，M3 ③），喂给原项目 BulletMultiMesh。
class_name KernelBulletBackend
extends Node

const MarisaLaserFadeClass = preload("res://scripts/kernel_bridge/marisa_laser_fade.gd")
const KernelBombClass = preload("res://scripts/kernel_bridge/kernel_bomb.gd")
const KernelMistBombClass = preload("res://scripts/kernel_bridge/kernel_mist_bomb.gd")
const KernelBehaviorHostClass = preload("res://scripts/kernel_bridge/kernel_behavior_host.gd")
const _MOVE_WORLD_ACCEL := &"world_accel"
const _MOVE_LASER := &"marisa_laser"

## 内核弹池（原生权威；L3.5-4f 起扩展为必需）。
var system: KernelNativeSystem
## 实体注册表（自机 / 敌机 / Boss；BulletManager 注入）
var entity_registry: EntityRegistry
## 弹幕世界（BulletManager 注入）——bomb 宿主节点反查用
var bullet_manager: BulletManager
## 未映射行为（有 coroutine_script 或 accel）的发射次数——前用来看覆盖面。
var unmapped_behavior_count: int = 0

var _texture_by_index: Array[Texture2D] = []   # 纹理句柄表（render socket）：弹型下标 → 贴图；M3 ③ 判定为设计 seam，N4 换原生实例缓冲

## 内核行为上下文（由 BulletManager 装配）。
var behavior_ctx: BehaviorContext
## 内容签名 → 端口（{move, params} / 预留 {program}）；按 Script×params 缓存，不每发 instantiate。
var _port_by_sig: Dictionary = {}
## 端口探测实例：端口的 params 里可能带 Callable（工厂）→ 必须保活，否则回调失效。
var _port_probes: Array[Node] = []
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


func _exit_tree() -> void:
	for p in _port_probes:
		if is_instance_valid(p):
			p.free()
	_port_probes.clear()


## 生成宿主节点 bomb（返回节点，供调用方忽略/持有）。data 是 BombData（不是弹幕的 BulletData）。
## 宿主实体由 data 的**实际类型**决定（MistBombData → KernelMistBomb；其余/基类 → KernelBomb）。
func spawn_bomb(data: BombData, pos: Vector2, direction: Vector2, tint: Color = Color.WHITE, spawn_delay: float = 0.0) -> Node:
	# 用 if/else 而非三元：两个分支是**兄弟类**（KernelMistBomb / KernelBomb），
	# 三元要求分支类型互相兼容，静态分析会报 INCOMPATIBLE_TERNARY。
	var bomb: BombEntity
	if data is MistBombData:
		bomb = KernelMistBombClass.new()
	else:
		bomb = KernelBombClass.new()
	bomb.entity_registry = entity_registry
	bomb.bullet_manager = bullet_manager
	bomb.fx_parent = bullet_manager.fx_parent if bullet_manager else null
	add_child(bomb)
	_bombs.append(bomb)
	bomb.setup(data, pos, direction, tint, spawn_delay)
	return bomb


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
		push_error("[KernelBulletBackend] 原生扩展未加载：本项目已要求 GDExtension（见 docs/N2_NATIVE_INTEGRATION_PLAN.md §63）")
	add_child(system)


## 行为循环结束后统一执行延后的 re_fire / 分裂（内核契约：循环中途禁止增删行）。
func _physics_process(delta: float) -> void:
	flush_behavior_host()
	if _laser_fade != null:
		_laser_fade.process(delta)


## 执行延后动作队列（幂等：队列空则 no-op）。BulletManager 也会调一次作兜底。
func flush_behavior_host() -> void:
	if _behavior_host != null:
		_behavior_host.flush()


## 解析一次发射所需的 **per-shot 状态**（类型 / 速度 / 行为 / 染色），不写内核池。
## 延后队列在**入队瞬间**调它做快照：内容复用同一 BulletData 模板改速度再入队（M2 正常写法），
## 若拖到 flush 才读实例，所有入队项会被最后一次写入覆盖（non_mid01 红弹速度梯度消失即此因）。
func prepare_shot(data: BulletData, pos: Vector2, direction: Vector2) -> Dictionary:
	if data == null:
		return {}
	_ensure_system()
	var type := data.to_bullet_type()
	var speed: float = data.velocity.length()
	var vel: Vector2 = direction.normalized() * speed if direction != Vector2.ZERO else data.velocity
	var move: StringName = &""
	var params: Variant = null
	if data.coroutine_script != null:
		var port: Dictionary = _port_for(data)
		if port.has("lifecycle"):
			# 预拼描述符入口：内容自己拼 BulletLifecycle（builder sugar），不经过命名 move。
			move = LifecycleCatalog.MOVE_LIFECYCLE
			params = {&"lifecycle": port.get("lifecycle"), &"anchor": port.get("anchor")}
		elif port.has("program"):
			unmapped_behavior_count += 1   # 预留：VM 未实现，先直线
		elif port.has("move"):
			move = port.get("move")
			params = port.get("params", null)
		else:
			unmapped_behavior_count += 1   # 无端口：按直线发射
	elif data.accel != Vector2.ZERO:
		move = _MOVE_WORLD_ACCEL
		params = {&"world_accel": data.accel}
	if move == _MOVE_LASER:
		type.kind = BulletType.Kind.LASER   # 供渲染桥整批淡出
		if _laser_fade != null:
			_laser_fade.on_laser_spawned()
	var tint: Color = data.tint
	if data.faction == BulletData.Faction.PLAYER:
		# 旧 Bullet.bind：自机弹在记忆 <50 时往红 lerp（spawn 时定一次）
		var res := _player_res()
		if res != null and res.memory_value < 50.0:
			tint = tint.lerp(Color.RED, remap(res.memory_value, 0.0, 50.0, 1.0, 0.0) * 0.5)
	return {type = type, pos = pos, vel = vel, tint = tint, move = move, params = params, texture = data.texture}


## 把 prepare_shot 的快照写入内核池（延后队列 flush 用；也可直接调）。
func spawn_prepared(spec: Dictionary) -> int:
	if spec.is_empty():
		return -1
	var id: int = system.spawn(spec.type, spec.pos, spec.vel, spec.tint, spec.move, spec.params)
	_sync_host_tables(id, spec.texture)
	return id


## 发射一颗弹（立即）。语义对齐原项目 `Bullet.bind`：`direction` 定方向，`data.velocity` 只取速度大小。
func shoot(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	return spawn_prepared(prepare_shot(data, pos, direction))


## 纹理句柄 → 贴图（渲染插座；未映射/越界 = null）。
func texture_for_index(index: int) -> Texture2D:
	if index < 0 or index >= _texture_by_index.size():
		return null
	return _texture_by_index[index]


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
	if system.native_behaviors:
		return
	process_physics_priority = -4   # 延后动作 flush：行为之后、宿主碰撞(0) 之前
	_behavior_host = KernelBehaviorHostClass.new()
	_behavior_host.setup(self)
	_laser_fade = MarisaLaserFadeClass.new()
	_laser_fade.setup(self)
	# 行为全程原生（behavior_tick）；宿主回调（emit/call）经 behavior_host。
	system.native_behaviors = true
	system.behavior_ctx = behavior_ctx
	system.behavior_host = _behavior_host
	system.boss_getter = func(): return _behavior_host.get_boss()


## 取内容脚本的内核端口（duck-typed `kernel_port()`），按内容签名缓存。
## 脚本先用 `data.params` 覆盖自身变量再问端口，故端口能反映发射参数。
func _port_for(data: BulletData) -> Dictionary:
	var sig: int = hash(data.coroutine_script)
	sig = sig * 31 + hash(data.params)
	if _port_by_sig.has(sig):
		return _port_by_sig[sig]
	var port: Dictionary = {}
	var probe: Object = data.coroutine_script.new()
	if probe != null:
		for k in data.params:
			probe.set(k, data.params[k])
		if probe.has_method(&"kernel_port"):
			var raw: Variant = probe.kernel_port()
			if raw is Dictionary:
				port = raw
		if probe is Node:
			if port.is_empty():
				(probe as Node).free()   # 无端口：探测完即弃
			else:
				_port_probes.append(probe)   # 端口可能带 Callable 工厂：保活
	_port_by_sig[sig] = port
	return port


func _sync_host_tables(id: int, texture: Texture2D) -> void:
	var indices: PackedInt32Array = system.get_type_indices()
	var ti: int = indices[id]
	if _texture_by_index.size() <= ti:
		_texture_by_index.resize(ti + 1)
	_texture_by_index[ti] = texture
