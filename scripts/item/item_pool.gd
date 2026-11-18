## Item 对象池，挂在 World 下
class_name ItemPool
extends Node

const ITEM_SCENE = preload("res://scenes/item.tscn")
const POOL_SIZE: int = 128

## 实体注册表（组合根为 World 注入）——透传给道具
var entity_registry: EntityRegistry

var _pool: Array[Item] = []


func _ready() -> void:
	for i in range(POOL_SIZE):
		var item: Item = ITEM_SCENE.instantiate()
		item.set_physics_process(false)
		item.visible = false
		add_child(item)
		_pool.append(item)


## 从池取 / 新建 Item，注入注册表、setup、显示并开物理；返回该 Item。
func spawn(pos: Vector2, type: int) -> Item:
	var item: Item
	if _pool.is_empty():
		item = ITEM_SCENE.instantiate()
		add_child(item)
	else:
		item = _pool.pop_back()
		if not is_instance_valid(item):
			item = ITEM_SCENE.instantiate()
			add_child(item)
		elif not item.is_inside_tree():
			add_child(item)

	item.entity_registry = entity_registry
	item.setup(type, pos)
	item.visible = true
	item.set_physics_process(true)
	return item


## 当前场上可见道具 [type, x, y]；按类型/位置排序，避免回收顺序造成假差异。
func item_snapshot() -> Array:
	var out: Array = []
	for child in get_children():
		if child is Item and child.visible:
			out.append([int(child.item_type), child.global_position.x, child.global_position.y])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		if not is_equal_approx(float(a[1]), float(b[1])):
			return float(a[1]) < float(b[1])
		return float(a[2]) < float(b[2]))
	return out


## 当前场上可见道具的状态指纹（排序后的位置 + 类型）；回放 trace 用。
func item_signature() -> int:
	var h := 0
	for e in item_snapshot():
		h = (h * 31 + int(e[0])) & 0x7fffffff
		h = (h * 31 + hash(Vector2(float(e[1]), float(e[2])))) & 0x7fffffff
	return h


## 场上可见道具数量。
func visible_count() -> int:
	var n := 0
	for child in get_children():
		if child is Item and child.visible:
			n += 1
	return n


## 回收 Item：隐藏 / 停物理，池未满回池，否则 queue_free；已在池中忽略。
func recycle(item: Item) -> void:
	if not is_instance_valid(item):
		return
	if item in _pool:
		return  # 已在池中，防重复
	item.visible = false
	item.set_physics_process(false)
	if _pool.size() < POOL_SIZE:
		_pool.append(item)
	else:
		item.queue_free()
