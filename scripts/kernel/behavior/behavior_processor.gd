## 行为处理器：跑"名字 → Behavior 实例"表。
## 契约：行为只标记待回收，回收在本循环后统一执行（避开 swap-with-last 中途搬移）。
extends Node
class_name BehaviorProcessor

var _system: BulletSystem
var _ctx: BehaviorContext
var _registry: Dictionary[StringName, Behavior] = {}   # 名字 -> Behavior 实例
# 槽 -> 行为实例缓存（名字解析只在刷新时做一次）
var _by_slot: Array[Behavior] = []
var _cache_valid: bool = false


## 显式注入系统与上下文（由组合根 game.gd 下发，R2；不依赖父子关系）。
func setup(system: BulletSystem, ctx: BehaviorContext) -> void:
	_system = system
	_ctx = ctx
	_cache_valid = false


# ATTENTION: 必须覆写 process()，否则静默无操作（该弹没行为）。
## 注册"弹幕移动"：名字即 key，发射时用同名字。
func register_behavior(move_name: StringName, behavior: Behavior) -> void:
	_registry[move_name] = behavior
	_cache_valid = false   # 注册表变了 → 槽缓存失效


## 刷新槽 → 行为缓存（名字表增长/注册表变化时）。
func _refresh_slot_cache() -> void:
	var slot_count: int = _system.get_move_slot_count()
	_by_slot.resize(slot_count)
	for slot in range(1, slot_count):
		_by_slot[slot] = _registry.get(_system.get_move_name(slot))
	_cache_valid = true


func _physics_process(_delta: float) -> void:
	process()


## 跑一遍所有活跃弹的行为（测试可直接调用）。
func process() -> void:
	var count: int = _system.get_active_count()
	if count == 0:
		return
	# 过期才刷新（每帧只多两次比较）
	if not _cache_valid or _by_slot.size() != _system.get_move_slot_count():
		_refresh_slot_cache()
	var fx_phases: PackedFloat32Array = _system.get_fx_phases()   # 每帧现取快照：相位中的弹不跑行为
	for i in count:
		if fx_phases[i] > 0.0:
			continue   # 相位中：不跑行为
		var slot: int = _system.get_behavior_id(i)
		if slot == BulletSystem.BEHAVIOR_NONE:
			continue
		var behavior: Behavior = _by_slot[slot]
		if behavior:
			behavior.process(_system, i, _ctx)
	# 回收 pass：行为只标记，这里统一执行。
	# 必须按 id **降序**：despawn 是 swap-with-last —— 升序时先回收小 id 会把大 id 所在的行
	# 搬到小 id 槽并缩小 _active_count，使后续大 id 越界被**静默丢弃**
	# （症状：多弹同帧回收丢一个 → bounce 重复发射 / 行为弹残留）。
	var requests: PackedInt32Array = _system.take_despawn_requests()
	requests.sort()
	requests.reverse()
	for id in requests:
		_system.despawn(id)
