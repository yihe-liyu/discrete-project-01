## 内容侧发射描述：一颗弹“出生时需要知道的基础属性”。
## 只描述，不执行；直接生成 BulletType，是内容与内核之间唯一的发射 DTO。
class_name SpawnSpec
extends RefCounted

## 阵营。
enum Faction {PLAYER, ENEMY}
## 判定形状。
enum HitboxShape {CIRCLE, RECTANGLE}
## 环绕边掩码：1 左 / 2 右 / 4 上 / 8 下。
enum WrapEdge {LEFT = 1, RIGHT = 2, TOP = 4, BOTTOM = 8}

var bullet_def: BulletDef
var texture: Texture2D
var tint: Color = Color.WHITE
var use_blend: bool = true
var faction: int = Faction.PLAYER
var velocity: Vector2 = Vector2.UP
var lifecycle: BulletLifecycle
## per-shot 锚点 spec（{id, offset, use_global}）；仅锚定型弹道（激光）需要。
var lifecycle_anchor: Variant = null
var behavior_spec: BehaviorSpec
var out_grace: float = 0.0
var wrap_mask: int = 0

## 弹型类别：POINT = 普通弹；LASER = 激光段（供整批淡出 / 清理）。
var kind: BulletType.Kind = BulletType.Kind.POINT
## 基础伤害（支持小数，伤害累积到整才扣血）。
var damage: float = 10.0
## 击中特效。
var hit_effect: PackedScene
## 命中音效注册器 key；空 = normal_damage。
var hit_sfx: String = ""

# 判定覆盖；-1 / ZERO 表示沿用 bullet_def。
var hitbox_shape: int = HitboxShape.CIRCLE
var hitbox_radius: float = -1.0
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_size: Vector2 = Vector2.ZERO
var follow_dir_override: int = -1   # -1 = 用 bullet_def；0/1 = 明确覆盖
var dir_offset_override: float = NAN

# -1 = 阵营默认；0 = 关闭；1 = 打开。
var spawn_fog: int = -1
## 出生特效；null = 用阵营默认。
var spawn_fx: EffectType

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
	faction = Faction.ENEMY
	_cached_type = null
	return self


func player() -> SpawnSpec:
	faction = Faction.PLAYER
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


func wrap_edges(mask: int) -> SpawnSpec:
	wrap_mask = mask
	_cached_type = null
	return self


func wrap_around() -> SpawnSpec:
	return wrap_edges(WrapEdge.LEFT | WrapEdge.RIGHT | WrapEdge.TOP | WrapEdge.BOTTOM)


func wrap_horizontal() -> SpawnSpec:
	return wrap_edges(WrapEdge.LEFT | WrapEdge.RIGHT)


func wrap_vertical() -> SpawnSpec:
	return wrap_edges(WrapEdge.TOP | WrapEdge.BOTTOM)


func hitbox_circle(radius: float, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = HitboxShape.CIRCLE
	hitbox_radius = radius
	hitbox_offset = offset
	hitbox_size = Vector2.ZERO
	_cached_type = null
	return self


func hitbox_rect(size: Vector2, offset: Vector2 = Vector2.ZERO) -> SpawnSpec:
	hitbox_shape = HitboxShape.RECTANGLE
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


func with_spawn_fog(effect: EffectType = null) -> SpawnSpec:
	spawn_fog = 1
	spawn_fx = effect
	_cached_type = null
	return self


func trajectory(lc: BulletLifecycle, anchor: Variant = null) -> SpawnSpec:
	lifecycle = lc
	lifecycle_anchor = anchor
	_cached_type = null
	return self


func with_behavior(spec: BehaviorSpec) -> SpawnSpec:
	behavior_spec = spec
	_cached_type = null
	return self


## 直接构造成内核类型。
func to_bullet_type() -> BulletType:
	if _cached_type != null:
		return _cached_type
	var bt := BulletType.new()
	bt.kind = kind
	bt.faction = BulletType.Faction.ENEMY if faction == Faction.ENEMY else BulletType.Faction.PLAYER
	bt.tint_mode = BulletType.TintMode.BLEND if use_blend else BulletType.TintMode.MULTIPLY
	bt.out_grace = out_grace
	bt.wrap_mask = wrap_mask
	bt.is_spawn_fog = spawn_fog != 0
	bt.spawn_fx = spawn_fx
	bt.damage = damage
	bt.hit_fx = hit_effect
	bt.hit_sfx = StringName(hit_sfx)
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
