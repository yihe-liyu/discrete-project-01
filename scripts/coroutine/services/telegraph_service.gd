## 路径预览服务 —— ctx.telegraph（无 class_name：使用处 preload，避免 headless 全局类缓存问题）。
## 内容只给 lifecycle + 出生状态；服务负责跑 chain、把 points 交给场景里的 TelegraphPath。
## 无注入节点（测试 / 无场景）时静默跳过，不改变内容行为。

const PREVIEW := preload("res://scripts/telegraph/lifecycle_preview.gd")

## 场景里的展示节点（组合根 GameScene 注入；为空 = 静默跳过）。
var telegraph_path: Node
## 弹幕管理器（组合根注入；逐弹跟踪用）。
var bullet_manager: BulletManager
var _tracked_uids: Array[int] = []
var _paths_by_uid = {}
var _tracked_age: float = 0.0
var _tracked_color: Color = Color(1.0, 0.82, 0.35, 0.85)
var _tracked_width: float = 3.0

## 从当前 phase 起顺序预览，并立即显示。
## [code]max_time[/code] 是整个 chain 的上限；[code]phase_index[/code] 通常 0。
func show_chain(lifecycle: BulletLifecycle, origin: Vector2, direction: Vector2,
		speed: float, max_time: float = 4.0, phase_index: int = 0,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> Dictionary:
	var results := show_chain_many(lifecycle, origin, [direction], speed, max_time,
		phase_index, color, width)
	return results[0] if not results.is_empty() else {}


## 多方向同时预览：每个方向一条独立 chain；用于“每颗弹一条线”的试验。
func show_chain_many(lifecycle: BulletLifecycle, origin: Vector2, directions: Array,
		speed: float, max_time: float = 4.0, phase_index: int = 0,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> Array[Dictionary]:
	_stop_tracking()
	var results: Array[Dictionary] = []
	var paths: Array[PackedVector2Array] = []
	var lifetime := 0.0
	for direction in directions:
		var vec := Vector2(direction)
		var heading := vec.normalized() if vec != Vector2.ZERO else Vector2.UP
		var result := PREVIEW.evaluate_chain(
			lifecycle, phase_index, origin, heading * speed, heading,
			1.0 / 60.0, max_time)
		results.append(result)
		if result.points.size() >= 2:
			paths.append(result.points)
			lifetime = maxf(lifetime, float(result.end_state.get("elapsed", 0.0)))
	if telegraph_path != null and is_instance_valid(telegraph_path) and not paths.is_empty():
		telegraph_path.call("show_paths", paths, color, width, lifetime)
	return results

## 绑定一颗真实弹；单颗便捷入口。路径在加入时钉在出生状态。
func track_bullet(bullet_uid: int, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> bool:
	return track_bullets([bullet_uid], lifecycle, color, width)


## 追加多颗真实弹到当前跟踪列表；允许来自不同敌人实例 / 不同 lifecycle。
func add_tracked_bullets(bullet_uids: Array, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> bool:
	if telegraph_path == null or not is_instance_valid(telegraph_path) \
			or bullet_manager == null or lifecycle == null:
		return false
	var added := false
	for uid in bullet_uids:
		var value := int(uid)
		if value > 0 and not _tracked_uids.has(value):
			_tracked_uids.append(value)
			_capture_path(value, lifecycle)
			added = true
	if not added:
		return not _tracked_uids.is_empty()
	if _tracked_uids.is_empty():
		_stop_tracking()
		return false
	_tracked_color = color
	_tracked_width = width
	_tracked_age = 0.1
	telegraph_path.call("set_tracker", Callable(self, "_tick_tracked"))
	_tick_tracked(0.0)
	return not _tracked_uids.is_empty()


## 绑定多颗真实弹：每颗在加入时按出生状态钉一条路径；死一颗掉一条。
func track_bullets(bullet_uids: Array, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> bool:
	_stop_tracking()
	return add_tracked_bullets(bullet_uids, lifecycle, color, width)

## 清掉当前预览。
func clear() -> void:
	_stop_tracking()
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("clear_path")


func _tick_tracked(delta: float) -> void:
	if _tracked_uids.is_empty() or bullet_manager == null \
			or telegraph_path == null or not is_instance_valid(telegraph_path):
		_stop_tracking()
		return
	_tracked_age += delta
	if _tracked_age < 0.1:
		return
	_tracked_age = 0.0
	var alive: Array[int] = []
	var paths: Array[PackedVector2Array] = []
	for uid in _tracked_uids:
		if bullet_manager.bullet_phase_uid(uid) < 0:
			continue
		alive.append(uid)
		var path: PackedVector2Array = _paths_by_uid.get(uid, PackedVector2Array())
		if path.size() >= 2:
			paths.append(path)
	_tracked_uids = alive
	if _tracked_uids.is_empty():
		_stop_tracking()
		return
	if not paths.is_empty():
		telegraph_path.call("show_paths", paths, _tracked_color, _tracked_width, 0.0)


## 在加入时把路径钉在出生状态上；之后只检查存活，不再用当前 pos 重算。
func _capture_path(uid: int, lifecycle: BulletLifecycle) -> void:
	var phase: int = bullet_manager.bullet_phase_uid(uid)
	if phase < 0:
		return
	var position: Vector2 = bullet_manager.bullet_global_position_uid(uid)
	var velocity: Vector2 = bullet_manager.bullet_velocity_uid(uid)
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else Vector2.UP
	var result: Dictionary = PREVIEW.evaluate_chain(
		lifecycle, phase, position, velocity, heading, 1.0 / 60.0, 4.0)
	if result.points.size() >= 2:
		_paths_by_uid[uid] = result.points

func _stop_tracking() -> void:
	_tracked_uids.clear()
	_paths_by_uid.clear()
	_tracked_age = 0.0
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("set_tracker", Callable())
		telegraph_path.call("clear_path")
