extends RefCounted
## 单颗弹的确定性路径预览：直接跑 native behavior 的同一份 tick，不生成真弹。
##
## 与运行时共用 C++ behavior pack，所以不会出现“预览一套、实战另一套”。
## 行为 emit 子代后不续算（第一版只画父弹路径）；despawn 后停止。
## 无 behavior 的弹走直线；无原生扩展时也退化为直线，保证预览服务不崩。

const DEFAULT_DT := 1.0 / 60.0
const DEFAULT_MAX_TIME := 1.2
const DEFAULT_FIELD := Rect2(
	GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
	GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
	GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
const MAX_FRAMES := 720


## 预览一个 SpawnSpec 的飞行路径。
## 返回 [code]{ok, points, reason, approximate, end_state}[/code]。
static func evaluate(spec: SpawnSpec, origin: Vector2, velocity: Vector2,
		max_time: float = DEFAULT_MAX_TIME, dt: float = DEFAULT_DT,
		player: Vector2 = Vector2.ZERO,
		enemies: PackedVector2Array = PackedVector2Array(),
		anchor_position: Variant = null) -> Dictionary:
	var result := {
		"ok": false,
		"points": PackedVector2Array([origin]),
		"reason": &"invalid",
		"approximate": false,
		"end_state": {
			"position": origin,
			"velocity": velocity,
			"elapsed": 0.0,
		},
	}
	if spec == null or max_time <= 0.0 or dt <= 0.0:
		return result
	var frames := clampi(int(ceil(max_time / dt)), 1, MAX_FRAMES)
	var behavior := spec.behavior_spec
	if behavior == null or not ClassDB.class_exists("DanmakuStore"):
		return _straight(result, origin, velocity, frames, dt, &"no_behavior" if behavior == null else &"no_native")

	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(16, Rect2(-100000, -100000, 200000, 200000))
	store.set_field(DEFAULT_FIELD.position.x, DEFAULT_FIELD.end.x, DEFAULT_FIELD.position.y)
	var bid: int = store.get_behavior_id(String(behavior.id))
	if bid < 0:
		return _straight(result, origin, velocity, frames, dt, &"unknown_behavior")

	var anchor := player
	var has_anchor := false
	if anchor_position != null:
		anchor = Vector2(anchor_position)
		has_anchor = true
	elif spec.anchor != null:
		anchor = _resolve_anchor(spec.anchor, player)
		has_anchor = true
	elif behavior.id == &"anchor_drift":
		has_anchor = true   # 无锚点时退回自机（与宿主一致）

	var points: PackedVector2Array = store.preview_behavior(
		bid, behavior.params, origin, velocity, frames, dt,
		player, enemies, anchor, has_anchor)
	if points.size() < 2:
		return _straight(result, origin, velocity, frames, dt, &"empty")
	result["ok"] = true
	result["points"] = points
	result["reason"] = &"ok"
	result["end_state"] = {
		"position": points[points.size() - 1],
		"velocity": velocity,
		"elapsed": float(points.size() - 1) * dt,
	}
	return result


## 直线兜底：不依赖原生，仍能画出一条合理的预览。
static func _straight(result: Dictionary, origin: Vector2, velocity: Vector2,
		frames: int, dt: float, reason: StringName) -> Dictionary:
	var points := PackedVector2Array([origin])
	var p := origin
	for i in frames:
		p += velocity * dt
		points.append(p)
	result["ok"] = true
	result["points"] = points
	result["reason"] = reason
	result["approximate"] = reason != &"no_behavior"
	result["end_state"] = {
		"position": p,
		"velocity": velocity,
		"elapsed": float(frames) * dt,
	}
	return result


static func _resolve_anchor(spec: Variant, player: Vector2) -> Vector2:
	if not (spec is Dictionary):
		return player
	var id := int(spec.get(&"id", 0))
	var offset: Vector2 = spec.get(&"offset", Vector2.ZERO)
	var use_global := bool(spec.get(&"use_global", true))
	if id != 0:
		var node: Object = instance_from_id(id)
		if node is Node2D:
			if use_global:
				return (node as Node2D).global_position + offset
			return player + (node as Node2D).position
	return player + offset


## 折线简化（RDP）：只保留端点和超过 epsilon 的拐点。
static func simplify_path(points: PackedVector2Array, epsilon: float = 1.25) -> PackedVector2Array:
	if points.size() <= 2 or epsilon <= 0.0:
		return points
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var start := span.x
		var end := span.y
		var farthest := -1.0
		var index := -1
		for i in range(start + 1, end):
			var distance := _point_to_segment_distance(points[i], points[start], points[end])
			if distance > farthest:
				farthest = distance
				index = i
		if index >= 0 and farthest > epsilon:
			keep[index] = 1
			stack.append(Vector2i(start, index))
			stack.append(Vector2i(index, end))
	var simplified := PackedVector2Array()
	for i in points.size():
		if keep[i] != 0:
			simplified.append(points[i])
	return simplified


static func _point_to_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)
