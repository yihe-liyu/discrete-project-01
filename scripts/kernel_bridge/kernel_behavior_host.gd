## KernelBehaviorHost—— 桥接行为的「延后动作」队列。
##
## 内核契约：行为循环中途禁止 spawn/despawn（swap-with-last 会搬行）。
## 故行为只 request_despawn + 入队新弹；循环结束后由 KernelBulletBackend._physics_process(-4) 统一 flush。
## 无 class_name（避免新增全局类需要 --import 重建缓存）；由 KernelBulletBackend preload。
extends RefCounted

var backend   # KernelBulletBackend
var _spawns: Array[Dictionary] = []


func setup(p_backend) -> void:
	backend = p_backend


## 当前 Boss（经后端注入的实体注册表；无则 null）——桥接行为查询用
func get_boss():
	return backend.entity_registry.get_boss() if backend != null and backend.entity_registry != null else null


## 入队一次发射。data 须是已按运行时改好的**副本**（模板会被复用）。
func queue_spawn(data: BulletData, pos: Vector2, dir: Vector2) -> void:
	_spawns.append({data = data, pos = pos, dir = dir})


func flush() -> void:
	if _spawns.is_empty():
		return
	var pending := _spawns
	_spawns = []   # 先取走：flush 中若再入队不丢
	for s in pending:
		if backend != null:
			backend.shoot(s.data, s.pos, s.dir)
