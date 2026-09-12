## KernelBulletBackend（Track A / S1）——宿主侧适配：BulletData（原项目）→ BulletType（内核）。
##
## 边界（见 scripts/kernel/README.md）：内核不认识 BulletData；映射只发生在**本文件**（宿主桥接层）。
## 缓存按**内容签名**而非实例——原项目两种用法并存：enemy01 复用同一实例并改速度，
## cs_reimu / non01_shoot 每发 `BulletData.new()`；按实例缓存会让内核弹型表每发长一个。
##
## S4a 起：`coroutine_script` 走 duck-typed `kernel_port()` 端口映射到内核行为；
## `BulletData.accel` 走桥接 `world_accel`。未映射（无端口）仍按直线发射并计入 unmapped。
## 渲染不在本类：纹理走**旁表**（`texture_for_index`），S2 把它喂给原项目 BulletMultiMesh。
class_name KernelBulletBackend
extends Node

const WorldAccelBehaviorClass = preload("res://scripts/kernel_bridge/behavior/world_accel_behavior.gd")
const HomingBehaviorClass = preload("res://scripts/kernel_bridge/behavior/homing_behavior.gd")
const RadialAccelBehaviorClass = preload("res://scripts/kernel_bridge/behavior/radial_accel_behavior.gd")
const BounceBehaviorClass = preload("res://scripts/kernel_bridge/behavior/bounce_behavior.gd")
const NonMidFleeBehaviorClass = preload("res://scripts/kernel_bridge/behavior/non_mid_flee_behavior.gd")
const MarisaLaserFadeClass = preload("res://scripts/kernel_bridge/marisa_laser_fade.gd")
const MarisaLaserBehaviorClass = preload("res://scripts/kernel_bridge/behavior/marisa_laser_behavior.gd")
const KernelBombClass = preload("res://scripts/kernel_bridge/kernel_bomb.gd")
const KernelBehaviorHostClass = preload("res://scripts/kernel_bridge/kernel_behavior_host.gd")
const _MOVE_WORLD_ACCEL := &"world_accel"
const _MOVE_LASER := &"marisa_laser"

## 内核弹池。默认本机新建；S3 交由 BulletManager 注入/接管。
var system: BulletSystem
## W4b-3b：实体注册表（自机 / 敌机 / Boss；BulletManager 注入）
var refs: EntityRegistry
## 未映射行为（有 coroutine_script 或 accel）的发射次数——S4 前用来看覆盖面。
var unmapped_behavior_count: int = 0

var _type_by_sig: Dictionary = {}              # 内容签名(int) → BulletType
var _texture_by_index: Array[Texture2D] = []   # 内核弹型下标 → 贴图（渲染旁表）
var _damage_by_index := PackedFloat32Array()   # 宿主专有：伤害（内核 BulletType 无 damage，见 §16.1）
var _hit_sfx_by_index: Array[String] = []      # 宿主专有：命中音效 key

## S4a：内核行为注册表 + 上下文（由 BulletManager 装配；见 docs §21.4）。
var behavior: BehaviorProcessor
var behavior_ctx: BehaviorContext
## 内容签名 → 端口（{move, params} / 预留 {program}）；按 Script×params 缓存，不每发 instantiate。
var _port_by_sig: Dictionary = {}
## 端口探测实例：端口的 params 里可能带 Callable（工厂）→ 必须保活，否则回调失效。
var _port_probes: Array[Node] = []
## S4c：桥接行为的延后动作队列（re_fire / 分裂不能在内核行为循环中途做）。
var _behavior_host
## S4c-4：魔理沙激光整批渐隐控制器。
var _laser_fade
## S4d：宿主节点 bomb（不进内核池；out_grace 缘由见 docs §21.17）。
var _bombs: Array[Node] = []


func _ready() -> void:
	_ensure_system()


## 当前自机的单局资源（经注册表取）；无自机 = null
func _player_res() -> PlayerResources:
	return refs.get_player_resources() if refs != null else null


func _exit_tree() -> void:
	for p in _port_probes:
		if is_instance_valid(p):
			p.free()
	_port_probes.clear()


## S4d：生成宿主节点 bomb（返回节点，供调用方忽略/持有）。
func spawn_bomb(data: BulletData, pos: Vector2, direction: Vector2) -> Node:
	var bomb: Node2D = KernelBombClass.new()
	bomb.refs = refs
	add_child(bomb)
	_bombs.append(bomb)
	bomb.setup(data, pos, direction)
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
	system = BulletSystem.new()
	system.name = "KernelBulletSystem"
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


## 发射一颗弹。语义对齐原项目 `Bullet.bind`：`direction` 定方向，`data.velocity` 只取速度大小。
func shoot(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	if data == null:
		return -1
	_ensure_system()
	var type := type_for(data)
	var speed: float = data.velocity.length()
	var vel: Vector2 = direction.normalized() * speed if direction != Vector2.ZERO else data.velocity
	var move: StringName = &""
	var params: Variant = null
	if data.coroutine_script != null:
		var port: Dictionary = _port_for(data)
		if port.has("program"):
			unmapped_behavior_count += 1   # S4 预留：VM 未实现，先直线
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
	var id: int = system.spawn(type, pos, vel, tint, move, params)
	_sync_host_tables(id, data)
	return id


## 取（或按内容签名新建）内核弹型：同内容 → 同实例（内核弹型表不随发射膨胀）。
func type_for(data: BulletData) -> BulletType:
	var sig: int = signature_of(data)
	var cached: BulletType = _type_by_sig.get(sig)
	if cached != null:
		return cached
	var bt := _make_type(data)
	_type_by_sig[sig] = bt
	return bt


## 内核弹型下标 → 贴图（S2 渲染旁表；未映射/越界 = null）。
func texture_for_index(index: int) -> Texture2D:
	if index < 0 or index >= _texture_by_index.size():
		return null
	return _texture_by_index[index]


## 宿主专有：该弹型伤害（内核 BulletType 无 damage；越界回退 10.0 = BulletData 默认）。
func damage_for_index(index: int) -> float:
	if index < 0 or index >= _damage_by_index.size():
		return 10.0
	return _damage_by_index[index]


## 宿主专有：该弹型命中音效 key（"" = 默认规则）。
func hit_sfx_for_index(index: int) -> String:
	if index < 0 or index >= _hit_sfx_by_index.size():
		return ""
	return _hit_sfx_by_index[index]


## 内容签名：只含决定 BulletType 的字段（**不含** velocity / tint——它们随每次发射传入）。
func signature_of(data: BulletData) -> int:
	var h: int = hash(data.texture)
	h = h * 31 + int(data.faction)
	h = h * 31 + int(data.tint_mode)
	h = h * 31 + int(data.hitbox_shape)
	h = h * 31 + hash(data.hitbox_radius)
	h = h * 31 + hash(data.hitbox_size)
	h = h * 31 + hash(data.hitbox_offset)
	h = h * 31 + hash(data.hitbox_rotation)
	h = h * 31 + hash(data.hit_effect)
	return h


func _make_type(data: BulletData) -> BulletType:
	var bt := BulletType.new()
	bt.faction = _map_faction(data.faction)
	bt.tint_mode = BulletType.TintMode.BLEND if data.tint_mode == BulletData.TintMode.BLEND \
			else BulletType.TintMode.MULTIPLY
	bt.hitbox_radius = data.hitbox_radius
	bt.hitbox_offset = data.hitbox_offset
	# 内核语义：非零 hitbox_size = 矩形；原项目默认 size(8,8) 但 shape=CIRCLE，必须归零。
	bt.hitbox_size = data.hitbox_size if data.hitbox_shape == BulletData.HitboxShape.RECTANGLE \
			else Vector2.ZERO
	bt.follow_dir = true
	bt.hit_fx = data.hit_effect
	return bt


func _map_faction(f: int) -> BulletType.Faction:
	match f:
		BulletData.Faction.ENEMY:
			return BulletType.Faction.ENEMY
		BulletData.Faction.PLAYER:
			return BulletType.Faction.PLAYER
		_:
			return BulletType.Faction.NONE   # BOMB：原项目靠协程自爆，S4 再接


## 装配内核行为管道（幂等；可重复调以刷新自机引用）。
## 优先级：内核积分 -10 → 行为 -5 → 宿主碰撞 0（原项目无 FrameOrder，见 docs §21.4）。
func setup_behaviors(player: Node2D, enemy_provider: Callable) -> void:
	_ensure_system()
	if behavior_ctx == null:
		behavior_ctx = BehaviorContext.new()
		behavior_ctx.setup(player, WorldQuery.new())
	if enemy_provider.is_valid():
		behavior_ctx.get_world().setup(enemy_provider)   # 可重复注入（测试 / 换关）
	behavior_ctx.setup(player, behavior_ctx.get_world())   # 刷新自机
	if behavior != null:
		return
	process_physics_priority = -4   # 延后动作 flush：行为(-5) 之后、宿主碰撞(0) 之前
	_behavior_host = KernelBehaviorHostClass.new()
	_behavior_host.setup(self)
	_laser_fade = MarisaLaserFadeClass.new()
	_laser_fade.setup(self)
	behavior = BehaviorProcessor.new()
	behavior.name = "KernelBehaviorProcessor"
	behavior.process_physics_priority = -5
	add_child(behavior)
	behavior.setup(system, behavior_ctx)
	behavior.register_behavior(&"accel", AccelBehavior.new())
	behavior.register_behavior(&"curve", CurveBehavior.new())
	behavior.register_behavior(&"laser_follow", LaserFollowBehavior.new())
	behavior.register_behavior(&"avoid_player", AvoidPlayerBehavior.new())
	behavior.register_behavior(_MOVE_WORLD_ACCEL, WorldAccelBehaviorClass.new())
	behavior.register_behavior(&"homing", HomingBehaviorClass.new())
	var radial = RadialAccelBehaviorClass.new()
	radial.host = _behavior_host
	behavior.register_behavior(&"radial_accel", radial)
	var bounce = BounceBehaviorClass.new()
	bounce.host = _behavior_host
	behavior.register_behavior(&"bounce", bounce)
	var flee = NonMidFleeBehaviorClass.new()
	flee.host = _behavior_host
	behavior.register_behavior(&"non_mid_flee", flee)
	behavior.register_behavior(_MOVE_LASER, MarisaLaserBehaviorClass.new())


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


func _sync_host_tables(id: int, data: BulletData) -> void:
	var indices: PackedInt32Array = system.get_type_indices()
	var ti: int = indices[id]
	if _texture_by_index.size() <= ti:
		_texture_by_index.resize(ti + 1)
		_damage_by_index.resize(ti + 1)
		_hit_sfx_by_index.resize(ti + 1)
	_texture_by_index[ti] = data.texture
	_damage_by_index[ti] = data.damage
	_hit_sfx_by_index[ti] = data.hit_sfx
