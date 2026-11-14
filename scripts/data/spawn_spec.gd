## 内容侧发射描述：一颗弹“出生时需要知道的基础属性”。
## 只描述，不执行；内容侧不再调用 to_bullet_data()，只在内部边界适配旧 BulletData。
class_name SpawnSpec
extends RefCounted

var bullet_def: BulletDef
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
var _cached_data: BulletData


func tex(key: String) -> SpawnSpec:
	bullet_def = BulletCatalog.find(key)
	_cached_data = null
	return self


func color(c: Color) -> SpawnSpec:
	tint = c
	_cached_data = null
	return self


func blend(on: bool = true) -> SpawnSpec:
	use_blend = on
	_cached_data = null
	return self


func enemy() -> SpawnSpec:
	faction = BulletData.Faction.ENEMY
	_cached_data = null
	return self


func player() -> SpawnSpec:
	faction = BulletData.Faction.PLAYER
	_cached_data = null
	return self


func speed(v: float) -> SpawnSpec:
	velocity.y = v
	_cached_data = null
	return self


func direction(x: float, y: float) -> SpawnSpec:
	velocity = Vector2(x, y)
	_cached_data = null
	return self


func grace(v: float) -> SpawnSpec:
	out_grace = v
	_cached_data = null
	return self


func wrap(mask: int) -> SpawnSpec:
	wrap_mask = mask
	_cached_data = null
	return self


func hitbox_circle(radius: float, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = BulletData.HitboxShape.CIRCLE
	hitbox_radius = radius
	hitbox_offset = offset
	hitbox_size = Vector2.ZERO
	_cached_data = null
	return self


func hitbox_rect(size: Vector2, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = BulletData.HitboxShape.RECTANGLE
	hitbox_size = size
	hitbox_offset = offset
	_cached_data = null
	return self


func facing(follow: bool = true, offset: float = 0.0) -> SpawnSpec:
	follow_dir_override = 1 if follow else 0
	dir_offset_override = offset
	_cached_data = null
	return self


func no_spawn_fog() -> SpawnSpec:
	spawn_fog = 0
	_cached_data = null
	return self


func with_spawn_fog() -> SpawnSpec:
	spawn_fog = 1
	_cached_data = null
	return self


func trajectory(lc: BulletLifecycle) -> SpawnSpec:
	lifecycle = lc
	_cached_data = null
	return self


func with_behavior(spec: BehaviorSpec) -> SpawnSpec:
	behavior_spec = spec
	_cached_data = null
	return self


## 转成旧内核适配器；过渡期唯一需要消费 BulletData 的边界。
func to_bullet_data() -> BulletData:
	if _cached_data != null:
		return _cached_data
	var d := BulletData.new()
	if bullet_def != null:
		d.def(bullet_def)
	d.color(tint).blend(use_blend)
	if faction == BulletData.Faction.ENEMY:
		d.enemy()
	else:
		d.player()
	d.velocity = velocity
	d.out_grace = out_grace
	d.wrap_mask = wrap_mask
	d.lifecycle = lifecycle
	d.behavior_spec = behavior_spec

	# 判定覆盖：未设置时保留 def 的结果。
	if hitbox_radius >= 0.0:
		d.hitbox_radius = hitbox_radius
	if hitbox_offset != Vector2.ZERO:
		d.hitbox_offset = hitbox_offset
	if hitbox_size != Vector2.ZERO:
		d.hitbox_shape = BulletData.HitboxShape.RECTANGLE
		d.hitbox_size = hitbox_size
	elif hitbox_shape == BulletData.HitboxShape.CIRCLE:
		d.hitbox_shape = BulletData.HitboxShape.CIRCLE
		d.hitbox_size = Vector2.ZERO
	if follow_dir_override >= 0:
		d.follow_dir = follow_dir_override != 0
	if not is_nan(dir_offset_override):
		d.dir_offset = dir_offset_override
	if spawn_fog == 0:
		d.no_spawn_fog()
	elif spawn_fog == 1:
		d.with_spawn_fog()

	_cached_data = d
	return d
