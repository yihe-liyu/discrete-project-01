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
