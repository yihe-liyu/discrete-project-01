## 内容侧发射描述：一颗弹“出生时需要知道的基础属性”。
## 只描述，不执行；直接生成 BulletType，不依赖 BulletData。
class_name SpawnSpec
extends RefCounted

var bullet_def: BulletDef
var texture: Texture2D
var tint: Color = Color.WHITE
var use_blend: bool = true
var faction: int = BulletData.Faction.PLAYER
var velocity: Vector2 = Vector2.UP
var lifecycle: BulletLifecycle
var behavior_spec: BehaviorSpec
var out_grace: float = 0.0
var wrap_mask: int = 0

# 判定覆盖；-1 / ZERO 表示沿用 bullet_def。
var hitbox_shape: int = BulletData.HitboxShape.CIRCLE
var hitbox_radius: float = -1.0
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_size: Vector2 = Vector2.ZERO
var follow_dir_override: int = -1   # -1 = 用 bullet_def；0/1 = 明确覆盖
var dir_offset_override: float = NAN

# -1 = 用 BulletData 默认；0 = 关闭；1 = 打开。
var spawn_fog: int = -1

var child: SpawnSpec
var _cached_type: BulletType


func tex(key: String) -> SpawnSpec:
	bullet_def = BulletCatalog.find(key)
	texture = BulletShapes.atlas_texture(StringName(key)) if bullet_def != null else null
	_cached_type = null
	return self


func color(c: Color) -> SpawnSpec:
	tint = c
	_cached_type = null
	return self


func blend(on: bool = true) -> SpawnSpec:
	use_blend = on
	_cached_type = null
	return self


func enemy() -> SpawnSpec:
	faction = BulletData.Faction.ENEMY
	_cached_type = null
	return self


func player() -> SpawnSpec:
	faction = BulletData.Faction.PLAYER
	_cached_type = null
	return self


func speed(v: float) -> SpawnSpec:
	velocity.y = v
	_cached_type = null
	return self


func direction(x: float, y: float) -> SpawnSpec:
	velocity = Vector2(x, y)
	_cached_type = null
	return self


func grace(v: float) -> SpawnSpec:
	out_grace = v
	_cached_type = null
	return self


func wrap(mask: int) -> SpawnSpec:
	wrap_mask = mask
	_cached_type = null
	return self


func hitbox_circle(radius: float, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = BulletData.HitboxShape.CIRCLE
	hitbox_radius = radius
	hitbox_offset = offset
	hitbox_size = Vector2.ZERO
	_cached_type = null
	return self


func hitbox_rect(size: Vector2, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = BulletData.HitboxShape.RECTANGLE
	hitbox_size = size
	hitbox_offset = offset
	_cached_type = null
	return self


func facing(follow: bool = true, offset: float = 0.0) -> SpawnSpec:
	follow_dir_override = 1 if follow else 0
	dir_offset_override = offset
	_cached_type = null
	return self


func no_spawn_fog() -> SpawnSpec:
	spawn_fog = 0
	_cached_type = null
	return self


func with_spawn_fog() -> SpawnSpec:
	spawn_fog = 1
	_cached_type = null
	return self


func trajectory(lc: BulletLifecycle) -> SpawnSpec:
	lifecycle = lc
	_cached_type = null
	return self


func with_behavior(spec: BehaviorSpec) -> SpawnSpec:
	behavior_spec = spec
	_cached_type = null
	return self


## 直接构造成内核类型；新路径不再经过 BulletData。
func to_bullet_type() -> BulletType:
	if _cached_type != null:
		return _cached_type
	var bt := BulletType.new()
	bt.kind = BulletType.Kind.POINT
	bt.faction = BulletType.Faction.ENEMY if faction == BulletData.Faction.ENEMY else BulletType.Faction.PLAYER
	bt.tint_mode = BulletType.TintMode.BLEND if use_blend else BulletType.TintMode.MULTIPLY
	bt.out_grace = out_grace
	bt.wrap_mask = wrap_mask
	bt.is_spawn_fog = spawn_fog != 0
	if bullet_def != null:
		bt.hitbox_radius = bullet_def.hitbox_radius
		bt.hitbox_offset = bullet_def.hitbox_offset
		bt.hitbox_size = bullet_def.hitbox_size
		bt.follow_dir = bullet_def.follow_dir
		bt.dir_offset = bullet_def.dir_offset
	if hitbox_radius >= 0.0:
		bt.hitbox_radius = hitbox_radius
	if hitbox_offset != Vector2.ZERO:
		bt.hitbox_offset = hitbox_offset
	if hitbox_size != Vector2.ZERO:
		bt.hitbox_size = hitbox_size
	if follow_dir_override >= 0:
		bt.follow_dir = follow_dir_override != 0
	if not is_nan(dir_offset_override):
		bt.dir_offset = dir_offset_override
	_cached_type = bt
	return bt
