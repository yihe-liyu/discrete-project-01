## 行为问世界的窄接口：只回答"敌人在哪"；伤害/清弹等规则留在实体，不塞进来（避免胖 ctx）。
## 目标来源是组合根给的 Callable（通常 = CollisionCoordinator.get_entities(PLAYER).bind(...)），
## 敌人增减自动生效，不存第二份注册表；喂假 provider 即可单测。
## 目标契约：Node2D + 公开 take_damage(amount)；已释放/待释放的自动跳过。
class_name WorldQuery
extends RefCounted

var _provider: Callable


## 注入目标来源（返回 Array 的 Callable）。不注入 = 永远没有敌人（空查询，不是错误）。
func setup(provider: Callable) -> void:
	_provider = provider


## 当前敌人列表（每次新建数组，已剔除释放中/已释放的实体）。
func get_enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not _provider.is_valid():
		return result
	for entity in _provider.call():
		if is_instance_valid(entity) and entity is Node2D and not entity.is_queued_for_deletion():
			result.append(entity)
	return result


## 离 from 最近的敌人；无则 null。max_distance < 0 = 不限距离。同距取先注册者（确定性）。
func get_nearest_enemy(from: Vector2, max_distance: float = -1.0) -> Node2D:
	var best: Node2D = null
	var best_d2 := INF
	var limit_d2 := INF if max_distance < 0.0 else max_distance * max_distance
	for enemy in get_enemies():
		var d2: float = from.distance_squared_to(enemy.global_position)
		if d2 <= limit_d2 and d2 < best_d2:
			best = enemy
			best_d2 = d2
	return best


## 半径内的敌人（**不排序**，顺序 = 注册顺序，确定性）。
func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var r2: float = radius * radius
	for enemy in get_enemies():
		if center.distance_squared_to(enemy.global_position) <= r2:
			result.append(enemy)
	return result
