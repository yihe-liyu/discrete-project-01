class_name ItemService
extends RefCounted
## 道具服务

## 弱引用 ctx：避免 StageContext ↔ ItemService 形成 RefCounted 环导致关卡退出后泄漏
var _ctx_ref: WeakRef
var ctx: StageContext:
	get:
		return _ctx_ref.get_ref() as StageContext if _ctx_ref else null
	set(value):
		_ctx_ref = weakref(value) if value else null

func spawn(type: int, position: Vector2) -> void:
	if not ctx or not ctx.active():
		return
	var scene := ctx.runner.get_tree().current_scene
	if not scene: return
	var world := scene.get_node_or_null("World")
	if world:
		var pool: ItemPool = world.get_node_or_null("ItemPool") as ItemPool
		if pool: pool.spawn(position, type)
