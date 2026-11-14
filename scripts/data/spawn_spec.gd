## 内容侧发射描述：只放“这一发需要什么”，不继承 BulletData。
## 过渡期保留 lifecycle；controller 可以是 lifecycle 或 behavior。
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


func grace(v: float) -> SpawnSpec:
	out_grace = v
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


## 转成旧内核适配器；过渡期唯一需要的转换点。
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
	d.lifecycle = lifecycle
	d.behavior_spec = behavior_spec
	_cached_data = d
	return d
