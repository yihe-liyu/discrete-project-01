## KernelBulletBackend（Track A / S1）——宿主侧适配：BulletData（原项目）→ BulletType（内核）。
##
## 边界（见 scripts/kernel/README.md）：内核不认识 BulletData；映射只发生在**本文件**（宿主桥接层）。
## 缓存按**内容签名**而非实例——原项目两种用法并存：enemy01 复用同一实例并改速度，
## cs_reimu / non01_shoot 每发 `BulletData.new()`；按实例缓存会让内核弹型表每发长一个。
##
## S1 范围：直线弹。`coroutine_script` / `accel` 的行为映射留 S4（未映射时按直线发射并计数）。
## 渲染不在本类：纹理走**旁表**（`texture_for_index`），S2 把它喂给原项目 BulletMultiMesh。
class_name KernelBulletBackend
extends Node

## 内核弹池。默认本机新建；S3 交由 BulletManager 注入/接管。
var system: BulletSystem
## 未映射行为（有 coroutine_script 或 accel）的发射次数——S4 前用来看覆盖面。
var unmapped_behavior_count: int = 0

var _type_by_sig: Dictionary = {}              # 内容签名(int) → BulletType
var _texture_by_index: Array[Texture2D] = []   # 内核弹型下标 → 贴图（渲染旁表）
var _damage_by_index := PackedFloat32Array()   # 宿主专有：伤害（内核 BulletType 无 damage，见 §16.1）
var _hit_sfx_by_index: Array[String] = []      # 宿主专有：命中音效 key


func _ready() -> void:
	_ensure_system()


## 懒建内核弹池（幂等）：不强依赖节点已在树中。
func _ensure_system() -> void:
	if system != null:
		return
	system = BulletSystem.new()
	system.name = "KernelBulletSystem"
	add_child(system)


## 发射一颗弹。语义对齐原项目 `Bullet.bind`：`direction` 定方向，`data.velocity` 只取速度大小。
func shoot(data: BulletData, pos: Vector2, direction: Vector2) -> int:
	if data == null:
		return -1
	_ensure_system()
	if data.coroutine_script != null or data.accel != Vector2.ZERO:
		unmapped_behavior_count += 1   # S1 只做直线；S4 接行为
	var type := type_for(data)
	var speed: float = data.velocity.length()
	var vel: Vector2 = direction.normalized() * speed if direction != Vector2.ZERO else data.velocity
	var id: int = system.spawn(type, pos, vel, data.tint)
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
