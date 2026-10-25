extends RefCounted
## 单颗弹「当前 phase」的确定性路径预览。
##
## 只做一件事：给定当前 [code]pos / vel / heading[/code] 和某个 phase 的 moves / until，
## 按固定步长往前积分，返回一条折线。它不是第二套物理：
## - 不生成真弹、不参与碰撞、不消耗游戏 RNG；
## - 不跨 phase，不模拟 emit；
## - 目标相关行为（steer / toward / random / until_near）不猜，直接拒绝或标记近似。
##
## 典型用法：
## [codeblock]
## var preview := LifecyclePreview.evaluate_phase(lc, 0, pos, vel, Vector2.UP)
## if preview.ok:
##     line.points = preview.points
## [/codeblock]

const DIR_SPEC := preload("res://scripts/kernel_bridge/lifecycle/dir_spec.gd")

## 默认步长（与物理帧一致）。
const DEFAULT_DT := 1.0 / 60.0
## 默认最长预览时间；phase 永不结束时用。
const DEFAULT_MAX_TIME := 1.2
## 默认场地（只用到左 / 右 / 上三面墙）。
const DEFAULT_FIELD := Rect2(
	GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
	GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
	GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)

const M_ACCEL_WORLD := &"accel_world"
const M_ACCEL_HEADING := &"accel_heading"
const M_ROTATE := &"rotate"
const M_STEER := &"steer"
const M_SPEED_LERP := &"speed_lerp"
const M_SPEED_MUL := &"speed_mul"
const M_SET_HEADING := &"set_heading"
const M_SET_SPEED := &"set_speed"
const M_POSITION := &"position"

const C_NEVER := &"never"
const C_ELAPSED := &"elapsed"
const C_NEAR := &"near"
const C_AT_WALL := &"at_wall"
const C_STATE := &"state"
const C_SPEED := &"speed"

const ROT_VELOCITY := 1
const ROT_HEADING := 2


## 预览一个 phase；返回 [code]{ok, points, reason, phase_index, approximate}[/code]。
## [code]ok=false[/code] 表示这个 phase 含无法可靠预测的行为（steer / 目标方向 / position 等）。
static func evaluate_phase(
		lifecycle: BulletLifecycle,
		phase_index: int,
		start_position: Vector2,
		start_velocity: Vector2,
		start_heading: Vector2 = Vector2.ZERO,
		dt: float = DEFAULT_DT,
		max_time: float = DEFAULT_MAX_TIME,
		field_rect: Rect2 = DEFAULT_FIELD) -> Dictionary:
	var result := {
		"ok": false,
		"points": PackedVector2Array(),
		"reason": &"invalid",
		"phase_index": phase_index,
		"approximate": false,
	}
	if lifecycle == null or phase_index < 0 or phase_index >= lifecycle.phases.size():
		return result
	if dt <= 0.0 or max_time <= 0.0:
		return result

	var phase: Dictionary = lifecycle.phases[phase_index]
	var moves: Array = phase.get(&"moves", [])
	var until: Dictionary = phase.get(&"until", {})
	var points := PackedVector2Array([start_position])
	var approximate := false

	# 先扫一遍 moves：只有 position（需要外部锚点）直接拒绝；
	# steer / 目标方向按“忽略瞄准”处理，保持当前朝向，并标记 approximate。
	for move in moves:
		var op := StringName(move.get(&"op", &""))
		if op == M_POSITION:
			result["reason"] = &"unsupported"
			result["points"] = points
			return result
		if op != M_ACCEL_WORLD and op != M_ACCEL_HEADING and op != M_ROTATE \
				and op != M_STEER and op != M_SPEED_LERP and op != M_SPEED_MUL \
				and op != M_SET_HEADING and op != M_SET_SPEED:
			result["reason"] = &"unsupported"
			result["points"] = points
			return result
		if op == M_STEER or (op == M_SET_HEADING and not _is_static_direction(move.get(&"dir"))):
			approximate = true

	var position := start_position
	var velocity := start_velocity
	var heading := start_heading
	if heading == Vector2.ZERO:
		heading = velocity.normalized() if velocity != Vector2.ZERO else Vector2.UP
	var slots := PackedFloat32Array()
	slots.resize(maxi(lifecycle.slots, 1))

	var elapsed := 0.0
	var tick := 0
	var next_check := 0.0
	var max_steps := maxi(1, ceili(max_time / dt))

	for _step in max_steps:
		# 与原生一致：先按上一帧速度积分，再执行本帧 move，再检查 until。
		position += velocity * dt
		elapsed += dt
		tick += 1

		for move in moves:
			var op := StringName(move.get(&"op", &""))
			match op:
				M_ACCEL_WORLD:
					var accel := Vector2(move.get(&"vec", Vector2.ZERO))
					velocity += accel * dt
				M_ACCEL_HEADING:
					velocity += heading * float(move.get(&"a", 0.0)) * dt
				M_ROTATE:
					var step := float(move.get(&"w", 0.0)) * dt
					var limit := float(move.get(&"limit", 0.0))
					var slot := int(move.get(&"slot", -1))
					var turned := slots[slot] if slot >= 0 and slot < slots.size() else 0.0
					if limit > 0.0:
						var remain := limit - turned
						if remain <= 0.0:
							continue
						step = clampf(step, -remain, remain)
					if slot >= 0 and slot < slots.size():
						slots[slot] = turned + absf(step)
					var mode := int(move.get(&"mode", 0))
					if mode != ROT_HEADING:
						velocity = velocity.rotated(step)
					if mode != ROT_VELOCITY:
						heading = heading.rotated(step)
				M_SPEED_LERP:
					var direction := velocity.normalized()
					if direction != Vector2.ZERO:
						var ramp := float(move.get(&"ramp", 0.0))
						var factor := 1.0 if ramp <= 0.0 else clampf(elapsed / ramp, 0.0, 1.0)
						var speed := lerpf(float(move.get(&"from", 0.0)), float(move.get(&"to", 0.0)), factor)
						velocity = direction * speed
				M_SPEED_MUL:
					velocity *= float(move.get(&"f", 1.0))
				M_STEER:
					# 忽略瞄准：保持当前朝向继续走，不对目标转向。
					approximate = true
				M_SET_HEADING:
					var direction := _static_direction(move.get(&"dir"), heading)
					if direction == Vector2.ZERO:
						approximate = true
					else:
						var speed := velocity.length()
						velocity = direction * speed
						heading = direction
				M_SET_SPEED:
					var length := velocity.length()
					var direction := velocity / length if length > 0.0 else heading
					if direction != Vector2.ZERO:
						velocity = direction * float(move.get(&"speed", 0.0))
				_:
					result["reason"] = &"unsupported"
					result["points"] = points
					return result

		var check := _check_until(until, position, velocity, elapsed, tick, slots, field_rect, next_check)
		next_check = float(check.get("next", next_check))
		if bool(check.get("unsupported", false)):
			approximate = true
		points.append(position)
		if bool(check.get("done", false)):
			result["ok"] = not approximate
			result["approximate"] = approximate
			result["points"] = points
			result["reason"] = &"target_until" if approximate else StringName(check.get("reason", &"done"))
			return result

	result["ok"] = not approximate
	result["approximate"] = approximate
	result["points"] = points
	result["reason"] = &"target_until" if approximate else &"max_time"
	return result


## 静态方向（heading / world_heading / forward）才允许预览；目标/随机方向返回 false。
static func _is_static_direction(dir: Variant) -> bool:
	if dir == null:
		return true
	var kind := StringName(dir.get("kind"))
	return kind == DIR_SPEC.HEADING or kind == DIR_SPEC.FORWARD


## 解析静态方向；目标/随机方向返回 ZERO（调用前已过滤）。
static func _static_direction(dir: Variant, heading: Vector2) -> Vector2:
	if dir == null:
		return heading
	match StringName(dir.get("kind")):
		DIR_SPEC.HEADING:
			return Vector2.UP.rotated(float(dir.get("angle")))
		DIR_SPEC.FORWARD:
			return heading.rotated(float(dir.get("angle")))
		_:
			return Vector2.ZERO


## 检查 until；[code]next[/code] 是下一次秒级节流的触发时间。
static func _check_until(until: Dictionary, position: Vector2, velocity: Vector2,
		elapsed: float, tick: int, slots: PackedFloat32Array,
		field_rect: Rect2, next_check: float) -> Dictionary:
	var every_ticks := int(until.get(&"every_ticks", 0))
	if every_ticks > 0 and tick % every_ticks != 0:
		return {"done": false, "next": next_check}
	var every := float(until.get(&"every", 0.0))
	if every > 0.0:
		if elapsed < next_check:
			return {"done": false, "next": next_check}
		next_check = elapsed + every

	match StringName(until.get(&"op", &"never")):
		C_NEVER:
			return {"done": false, "next": next_check}
		C_ELAPSED:
			return {"done": elapsed >= float(until.get(&"t", 0.0)), "reason": &"elapsed", "next": next_check}
		C_AT_WALL:
			var mask := int(until.get(&"mask", 0))
			var hit := false
			if (mask & 1) != 0 and position.x <= field_rect.position.x:
				hit = true
			elif (mask & 2) != 0 and position.x >= field_rect.end.x:
				hit = true
			if (mask & 4) != 0 and position.y <= field_rect.position.y:
				hit = true
			return {"done": hit, "reason": &"wall", "next": next_check}
		C_SPEED:
			var cmp := int(until.get(&"cmp", 0))
			var value := float(until.get(&"value", 0.0))
			var speed := velocity.length()
			return {"done": speed >= value if cmp == 0 else speed <= value, "reason": &"speed", "next": next_check}
		C_STATE:
			var slot := int(until.get(&"slot", -1))
			if slot < 0 or slot >= slots.size():
				return {"done": false, "next": next_check}
			var cmp := int(until.get(&"cmp", 0))
			var value := float(until.get(&"value", 0.0))
			return {"done": slots[slot] >= value if cmp == 0 else slots[slot] <= value, "reason": &"turned", "next": next_check}
		C_NEAR:
			# 目标位置相关：无法在“忽略瞄准”的前提下判断结束点。
			return {"done": false, "unsupported": true, "next": next_check}
		_:
			return {"done": false, "unsupported": true, "next": next_check}
