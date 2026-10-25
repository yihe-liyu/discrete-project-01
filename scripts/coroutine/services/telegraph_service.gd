## 路径预览服务 —— ctx.telegraph（无 class_name：使用处 preload，避免 headless 全局类缓存问题）。
## 内容只给 lifecycle + 出生状态；服务负责跑 chain、把 points 交给场景里的 TelegraphPath。
## 无注入节点（测试 / 无场景）时静默跳过，不改变内容行为。

const PREVIEW := preload("res://scripts/telegraph/lifecycle_preview.gd")

## 场景里的展示节点（组合根 GameScene 注入；为空 = 静默跳过）。
var telegraph_path: Node
## 弹幕管理器（组合根注入；逐弹跟踪用）。
var bullet_manager: BulletManager
var _tracked_uid: int = -1
var _bullet_lifecycle: BulletLifecycle
var _tracked_phase: int = -1
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

## 绑定一颗真实弹：按它的当前 phase / pos / vel 逐帧刷新路径；弹死自动清线。
## 只用于单颗原型；50 颗要先做多线合批与稳定身份。
func track_bullet(bullet_uid: int, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> bool:
	if telegraph_path == null or not is_instance_valid(telegraph_path) \
			or bullet_manager == null or bullet_uid <= 0 or lifecycle == null:
		return false
	_stop_tracking()
	_tracked_uid = bullet_uid
	_bullet_lifecycle = lifecycle
	_tracked_phase = -1
	_tracked_age = 0.0
	_tracked_color = color
	_tracked_width = width
	telegraph_path.call("set_tracker", Callable(self, "_tick_tracked"))
	_tick_tracked(0.0)
	return _tracked_uid >= 0


## 清掉当前预览。
func clear() -> void:
	_stop_tracking()
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("clear_path")


func _tick_tracked(delta: float) -> void:
	if _tracked_uid < 0 or _bullet_lifecycle == null or bullet_manager == null \
			or telegraph_path == null or not is_instance_valid(telegraph_path):
		_stop_tracking()
		return
	var phase: int = bullet_manager.bullet_phase_uid(_tracked_uid)
	if phase < 0:
		_stop_tracking()
		return
	_tracked_age += delta
	if phase == _tracked_phase and _tracked_age < 0.1:
		return
	_tracked_age = 0.0
	var position: Vector2 = bullet_manager.bullet_global_position_uid(_tracked_uid)
	var velocity: Vector2 = bullet_manager.bullet_velocity_uid(_tracked_uid)
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else Vector2.UP
	var result: Dictionary = PREVIEW.evaluate_chain(
		_bullet_lifecycle, phase, position, velocity, heading, 1.0 / 60.0, 4.0)
	if result.points.size() >= 2:
		var lifetime: float = float(result.end_state.get("elapsed", 0.0))
		telegraph_path.call("show_path", result.points, _tracked_color, _tracked_width, lifetime)
	_tracked_phase = phase


func _stop_tracking() -> void:
	_tracked_uid = -1
	_bullet_lifecycle = null
	_tracked_phase = -1
	_tracked_age = 0.0
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("set_tracker", Callable())
		telegraph_path.call("clear_path")
