## 碰撞协调器：集中"检测"（query 弹池）+ 派发，规则留在实体回调（R18）。
## 跨系统（player + enemies + 未来 option）→ 挂 sibling/root，不是 BulletSystem 子节点。
class_name CollisionCoordinator
extends Node

## 每帧检查的"进攻对"：半径内与该阵营弹重叠 → 回调 on_overlap(entity, bullet_id)。
var _system: BulletSystem
var _colliders: Array = []   # [{entity, faction, radius, on_overlap}]


## 注入弹系统。
func setup(system: BulletSystem) -> void:
	_system = system


## 注册一个"进攻对"；on_overlap 必须绑实体实例方法，规则别塞进协调器（否则退回 god-object）。
func register(entity: Object, bullet_faction: BulletType.Faction, query_radius: float, on_overlap: Callable) -> void:
	for c in _colliders:
		if is_instance_valid(c.entity) and c.entity == entity:
			push_warning("CollisionCoordinator: 实体重复注册，忽略：%s" % entity)
			return   # 去重：否则同一实体会被派发两次
	_colliders.append({
		"entity": entity,
		"faction": bullet_faction,
		"radius": query_radius,
		"on_overlap": on_overlap,
	})


## 注销实体（死亡 / 换关时调；否则条目会留在表里，长局是慢泄漏）。
func unregister(entity: Object) -> void:
	for i in range(_colliders.size() - 1, -1, -1):
		if _colliders[i].entity == entity:
			_colliders.remove_at(i)


## 清掉"已释放实体"的条目（外部 free / 换关后的兜底；正常死亡走 unregister）。
func prune() -> void:
	for i in range(_colliders.size() - 1, -1, -1):
		if not is_instance_valid(_colliders[i].entity):
			_colliders.remove_at(i)


## 某弹阵营能打中的实体（行为的世界查询来源：不再建第二套实体注册表）。
## 只返回注册项，释放中的实体由 WorldQuery 过滤。
func get_entities(bullet_faction: BulletType.Faction) -> Array:
	var result := []
	for c in _colliders:
		if c.faction == bullet_faction:
			result.append(c.entity)
	return result


func _physics_process(_delta: float) -> void:
	process()


## 每帧：query + 配对 + 派发（测试可直接调，不依赖节点处理顺序）。
func process() -> void:
	if _system == null:
		return
	for c in _colliders:
		var entity = c.entity
		if entity == null or not is_instance_valid(entity):
			continue   # 实体已释放（敌机死亡 queue_free）→ 跳过
		var hits: PackedInt32Array = CollisionResolver.overlap_ids(_system, entity.global_position, c.radius, c.faction)
		# 倒序派发：on_overlap 里 despawn 是 swap-with-last，正序会让后续 id 错位 / 漏回收。
		for k in range(hits.size() - 1, -1, -1):
			c.on_overlap.call(entity, hits[k])
