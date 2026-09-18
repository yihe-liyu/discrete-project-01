## KernelBehaviorHost—— 桥接行为的「延后动作」队列。
##
## 内核契约：行为循环中途禁止 spawn/despawn（swap-with-last 会搬行）。
## 故行为只 request_despawn + 入队新弹；循环结束后由 KernelBulletBackend._physics_process(-4) 统一 flush。
## 无 class_name（避免新增全局类需要 --import 重建缓存）；由 KernelBulletBackend preload。
extends RefCounted

## V13：backend 私有化 —— on_end_call 内容回调只能经 queue_spawn 入队，拿不到整个后端。
var _backend   # KernelBulletBackend
var _spawns: Array[Dictionary] = []


func setup(p_backend) -> void:
	_backend = p_backend


## 当前 Boss（经后端注入的实体注册表；无则 null）——桥接行为查询用
func get_boss():
	return _backend.entity_registry.get_boss() if _backend != null and _backend.entity_registry != null else null


## 入队一次发射。**入队瞬间快照 per-shot 状态**（backend.prepare_shot）：
## 内容复用同一 BulletData 模板改速度 / 染色再入队是 M2 的正常写法；
## 若拖到 flush 时才读实例，同一帧所有入队项会被最后一次写入覆盖（non_mid01 红弹速度梯度消失即此因）。
func queue_spawn(data: BulletData, pos: Vector2, dir: Vector2) -> void:
	if _backend == null or data == null:
		return
	_spawns.append(_backend.prepare_shot(data, pos, dir))


func flush() -> void:
	if _spawns.is_empty():
		return
	var pending := _spawns
	_spawns = []   # 先取走：flush 中若再入队不丢
	for spec in pending:
		if _backend != null:
			_backend.spawn_prepared(spec)
