## 路径预览服务 —— ctx.telegraph（无 class_name：使用处 preload，避免 headless 全局类缓存问题）。
## 内容只给 lifecycle + 出生状态；服务负责跑 chain、把 points 交给场景里的 TelegraphPath。
## 无注入节点（测试 / 无场景）时静默跳过，不改变内容行为。

const PREVIEW := preload("res://scripts/telegraph/lifecycle_preview.gd")

## 场景里的展示节点（组合根 GameScene 注入；为空 = 静默跳过）。
var telegraph_path: Node
## 弹幕管理器（组合根注入；逐弹跟踪用）。
var bullet_manager: BulletManager
## 发射服务（组合根注入；shoot_tracked 一行入口）。
var bullet_service: BulletService
var _tracked_uids: Array[int] = []
var _lifecycles_by_uid = {}
var _paths_by_uid = {}
var _phases_by_uid = {}
var _cursors_by_uid = {}
var _emitted_lifecycles: Array = []
var _tracked_age: float = 0.0
## 绘制折线简化阈值（像素）。
const PATH_EPSILON := 1.25
## 单次缓存的前瞻上限；距尾部 1 秒就从当前位置续算，保证长命弹的线始终连贯。
const TRACK_MAX_TIME := 2.0
## 距离缓存尾部还有多少点就开始续算（1 秒）。
const EXTEND_AHEAD_POINTS := 60
## 每个 tick 最多续算几颗，避免同一帧 50 颗一起重算造成顿感。
const EXTEND_BUDGET := 16
var _tracked_color: Color = Color(1.0, 0.82, 0.35, 0.85)
var _tracked_width: float = 1.5

## 从当前 phase 起顺序预览，并立即显示。
## [code]max_time[/code] 是整个 chain 的上限；[code]phase_index[/code] 通常 0。
func show_chain(lifecycle: BulletLifecycle, origin: Vector2, direction: Vector2,
		speed: float, max_time: float = 4.0, phase_index: int = 0,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> Dictionary:
	var results := show_chain_many(lifecycle, origin, [direction], speed, max_time,
		phase_index, color, width)
	return results[0] if not results.is_empty() else {}


## 多方向同时预览：每个方向一条独立 chain；用于“每颗弹一条线”的试验。
func show_chain_many(lifecycle: BulletLifecycle, origin: Vector2, directions: Array,
		speed: float, max_time: float = 4.0, phase_index: int = 0,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> Array[Dictionary]:
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

## 让 emit 出来的指定 lifecycle 自动进入跟踪；可重复调用注册多种子代。
func track_emitted(lifecycle: BulletLifecycle) -> bool:
	if bullet_manager == null or lifecycle == null:
		return false
	if not _emitted_lifecycles.has(lifecycle):
		_emitted_lifecycles.append(lifecycle)
	if not bullet_manager.bullet_spawned.is_connected(_on_emitted_bullet_spawned):
		bullet_manager.bullet_spawned.connect(_on_emitted_bullet_spawned)
	return true


func _on_emitted_bullet_spawned(uid: int, lifecycle: BulletLifecycle) -> void:
	if _emitted_lifecycles.has(lifecycle):
		add_tracked_bullets([uid], lifecycle, _tracked_color, _tracked_width)


## 一行入口：发射并立即跟踪这一发的真实弹；返回是否成功进入跟踪。
## 无 bullet_service / lifecycle 时仍正常发射，只是不画路径。
func shoot_tracked(bullet_data: BulletData, count: int, spread_angle: float,
		base_dir: Vector2, at: Vector2, sfx: AudioStream = null,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> bool:
	if bullet_service == null or bullet_data == null:
		return false
	var uids := bullet_service.shoot_spread_ids(
		bullet_data, count, spread_angle, base_dir, at, sfx)
	if bullet_data.lifecycle == null:
		return false
	return add_tracked_bullets(uids, bullet_data.lifecycle, color, width)


## 绑定一颗真实弹；单颗便捷入口。路径按当前 pos / phase 滚动刷新。
func track_bullet(bullet_uid: int, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> bool:
	return track_bullets([bullet_uid], lifecycle, color, width)


## 追加多颗真实弹到当前跟踪列表；允许来自不同敌人实例 / 不同 lifecycle。
## phase 起点缓存 chain，之后按当前 pos 裁前缀；旧弹路径继续更新。
func add_tracked_bullets(bullet_uids: Array, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> bool:
	if telegraph_path == null or not is_instance_valid(telegraph_path) \
			or bullet_manager == null or lifecycle == null:
		return false
	var added := false
	for uid in bullet_uids:
		var value := int(uid)
		if value > 0 and not _tracked_uids.has(value):
			_tracked_uids.append(value)
			_lifecycles_by_uid[value] = lifecycle
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


## 绑定多颗真实弹；死一颗掉一条。
func track_bullets(bullet_uids: Array, lifecycle: BulletLifecycle,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 1.5) -> bool:
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
	var extended := 0
	for uid in _tracked_uids:
		var phase: int = bullet_manager.bullet_phase_uid(uid)
		if phase < 0:
			continue
		alive.append(uid)
		var lifecycle: BulletLifecycle = _lifecycles_by_uid.get(uid)
		if lifecycle == null:
			continue
		var position: Vector2 = bullet_manager.bullet_global_position_uid(uid)
		var cached: PackedVector2Array = _paths_by_uid.get(uid, PackedVector2Array())
		var cursor: int = int(_cursors_by_uid.get(uid, 0))
		var phase_changed := int(_phases_by_uid.get(uid, -1)) != phase
		if cached.size() < 2 or phase_changed:
			_rebuild_cache(uid, phase, position, lifecycle)
		elif cursor >= cached.size() - EXTEND_AHEAD_POINTS and extended < EXTEND_BUDGET:
			_rebuild_cache(uid, phase, position, lifecycle)
			extended += 1
		var trimmed := _trim_to_current(uid, position)
		if trimmed.size() >= 2:
			var simplified := PREVIEW.simplify_path(trimmed, PATH_EPSILON)
			if simplified.size() >= 2:
				paths.append(simplified)
	_tracked_uids = alive
	if _tracked_uids.is_empty():
		_stop_tracking()
		return
	if not paths.is_empty():
		telegraph_path.call("show_paths", paths, _tracked_color, _tracked_width, 0.0)



## 在 phase 起点算一次完整 chain，缓存起来；phase 变了才重算。
func _rebuild_cache(uid: int, phase: int, position: Vector2, lifecycle: BulletLifecycle) -> void:
	var velocity: Vector2 = bullet_manager.bullet_velocity_uid(uid)
	var heading: Vector2 = velocity.normalized() if velocity != Vector2.ZERO else Vector2.UP
	var result: Dictionary = PREVIEW.evaluate_chain(
		lifecycle, phase, position, velocity, heading, 1.0 / 60.0, TRACK_MAX_TIME)
	# 缓存保留完整采样点，RDP 只用于最终绘制；否则直线会被压成 2 点，裁前缀/续算就失去中间点。
	_paths_by_uid[uid] = result.points
	_phases_by_uid[uid] = phase
	_cursors_by_uid[uid] = 0


## 把缓存路径裁成“当前弹位置 → 未来”：只画还没走到的后缀。
func _trim_to_current(uid: int, position: Vector2) -> PackedVector2Array:
	var cached: PackedVector2Array = _paths_by_uid.get(uid, PackedVector2Array())
	if cached.size() < 2:
		return PackedVector2Array()
	var start := int(_cursors_by_uid.get(uid, 0))
	var nearest := start
	var best := INF
	for i in range(start, cached.size()):
		var distance := cached[i].distance_squared_to(position)
		if distance < best:
			best = distance
			nearest = i
	_cursors_by_uid[uid] = nearest
	if nearest >= cached.size() - 1:
		return PackedVector2Array()
	var trimmed := PackedVector2Array([position])
	for i in range(nearest + 1, cached.size()):
		trimmed.append(cached[i])
	return trimmed


func _stop_tracking() -> void:
	_tracked_uids.clear()
	_lifecycles_by_uid.clear()
	_paths_by_uid.clear()
	_phases_by_uid.clear()
	_cursors_by_uid.clear()
	_tracked_age = 0.0
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("set_tracker", Callable())
		telegraph_path.call("clear_path")
