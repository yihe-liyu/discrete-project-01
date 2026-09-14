## 唯一的"圆-圆重叠"测试：某点附近、指定阵营的弹 id（重叠 = dist <= 查询半径 + 弹 hitbox）。
## 不含 graze——擦弹是玩家的两阈值规则，属玩家机制；命中/伤害/清弹由调用方各自解释。
class_name CollisionResolver
extends RefCounted

## 复用缓冲：调用方须在下次调用前消费完返回值（协调器逐 collider 处理，满足）。
## ATTENTION: 返回的是**共享**数组，别跨调用保存。
static var _scratch := PackedInt32Array()


## 几何归 system.query_circle，本函数只按阵营过滤。
static func overlap_ids(system: BulletSystem, center: Vector2, radius: float, faction: BulletType.Faction) -> PackedInt32Array:
	_scratch.clear()
	if radius <= 0.0:
		return _scratch
	for id in system.query_circle(center, radius):
		var bt: BulletType = system.get_type(id)
		if bt == null or bt.faction != faction:
			continue
		_scratch.append(id)
	return _scratch
