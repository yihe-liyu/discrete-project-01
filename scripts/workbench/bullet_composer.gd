extends RefCounted
## BulletComposer —— F10 的无 UI 模型：相位 → Move/Until/Action → BulletLifecycle。
##
## 设计边界：
## - 只做线性相位（与 BulletLifecycle 一致，没有跳转/分支）；
## - 组合逻辑不复制：每个 op 都走 [code]DescriptorCatalog.apply_*()[/code] → [code]BulletLifecycle[/code] builder；
## - 难度变体不进本类：一个 Composer 代表一个难度变体；UI 用 4 个实例装 4 档；
## - 表达式/代码生成是 UI 层的事；本类只保证“拼出来的 lifecycle 与手写等价”。
##
## 数据结构：
##   phases = [{moves: [op_call...], until: op_call, on_end: [op_call...]}]
##   op_call = {op: StringName, ...args}
##
## 不加 class_name：测试/工作台用 preload，避免新 class_name 全局缓存未导入。

const CATALOG = preload("res://scripts/workbench/descriptor_catalog.gd")
const DIR_SPEC = preload("res://scripts/kernel_bridge/lifecycle/dir_spec.gd")

## 每个相位：moves 有序；until 一个；on_end 有序。
var phases: Array = []


func _init() -> void:
	add_phase()


## 追加一个空相位（默认 until=never）。
func add_phase() -> int:
	phases.append({"moves": [], "until": {"op": "never"}, "on_end": []})
	return phases.size() - 1


func phase(index: int) -> Dictionary:
	return phases[index]


func move_count(index: int) -> int:
	return (phases[index]["moves"] as Array).size()


## 给某个相位追加 Move；args 里可以有任意键，[code]op[/code] 由这里统一写入。
func add_move(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	(phases[phase_index]["moves"] as Array).append(op_call)


## 设置某相位的 Until；[code]every[/code] / [code]every_ticks[/code] 是 Until 的修饰键，放在 args 里。
func set_until(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	phases[phase_index]["until"] = op_call


## 给某相位追加 on_end Action。
func add_action(phase_index: int, op: StringName, args: Dictionary = {}) -> void:
	var op_call: Dictionary = args.duplicate(true)
	op_call["op"] = op
	(phases[phase_index]["on_end"] as Array).append(op_call)


## 从声明式 spec 载入（golden test / 工作区恢复 / UI 序列化共用）。
## spec = {phases: [{moves: [...], until: {...}, on_end: [...]}]}
func from_spec(spec: Dictionary) -> void:
	phases.clear()
	for p in spec.get("phases", []):
		var idx := add_phase()
		for m in p.get("moves", []):
			add_move(idx, StringName(m.get("op", &"")), m)
		var u: Dictionary = p.get("until", {})
		set_until(idx, StringName(u.get("op", &"never")), u)
		for a in p.get("on_end", []):
			add_action(idx, StringName(a.get("op", &"")), a)
	if phases.is_empty():
		add_phase()


func to_spec() -> Dictionary:
	return {"phases": phases.duplicate(true)}


## 核心：按顺序调 builder，得到与手写完全同构的 lifecycle。
## 注意：每个相位都要显式 apply_until（默认 never），保证 [code]_set_until[/code] 的修饰键语义一致。
func to_lifecycle() -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	for i in phases.size():
		if i > 0:
			lc.then()
		var p: Dictionary = phases[i]
		for m in p["moves"]:
			CATALOG.apply_move(lc, m)
		CATALOG.apply_until(lc, p["until"])
		for a in p["on_end"]:
			CATALOG.apply_action(lc, a)
	return lc


## 生成可粘贴的 GDScript。[code]_spawn[/code] 是占位：内容里换成自己的 BulletData（或当前弹）。
## 只生成“弹道”这段，不生成 [code]_tick[/code] / 波次调度 —— 与 F10 的边界一致。
func to_code() -> String:
	var lines: Array[String] = ["var lc := BulletLifecycle.new()"]
	for i in phases.size():
		if i > 0:
			lines.append("lc.then()")
		var p: Dictionary = phases[i]
		for m in p["moves"]:
			lines.append("lc." + _move_code(m))
		lines.append("lc." + _until_code(p["until"]))
		for a in p["on_end"]:
			lines.append("lc." + _action_code(a))
	lines.append("data.trajectory(lc)")
	return "\n".join(lines)


func _move_code(op_call: Dictionary) -> String:
	var op := StringName(op_call.get("op", &""))
	match op:
		&"accel_world":
			return "accel_world(%s)" % _vec2_code(op_call.get("v", Vector2.ZERO))
		&"accel_heading":
			return "accel_heading(%s)" % _num_code(op_call.get("a", 0.0))
		&"rotate":
			return "rotate(%s, %s)" % [_num_code(op_call.get("w", 0.0)), _num_code(op_call.get("limit", 0.0))]
		&"rotate_velocity":
			return "rotate_velocity(%s, %s)" % [_num_code(op_call.get("w", 0.0)), _num_code(op_call.get("limit", 0.0))]
		&"rotate_heading":
			return "rotate_heading(%s, %s)" % [_num_code(op_call.get("w", 0.0)), _num_code(op_call.get("limit", 0.0))]
		&"steer":
			return "steer(%s, %s, %s, %s, %s)" % [
				_target_code(op_call.get("target", BulletLifecycle.T_NEAREST_ENEMY)),
				_num_code(op_call.get("max_turn", 0.0)), _num_code(op_call.get("ramp", 0.0)),
				_num_code(op_call.get("dist_weight", 0.0)), _num_code(op_call.get("steer_until", 0.0))]
		&"speed_lerp":
			return "speed_lerp(%s, %s, %s)" % [_num_code(op_call.get("from", 0.0)), _num_code(op_call.get("to", 0.0)), _num_code(op_call.get("ramp", 0.0))]
		&"speed_mul":
			return "speed_mul(%s)" % _num_code(op_call.get("f", 1.0))
		&"set_heading":
			return "set_heading(%s)" % _dir_code(op_call.get("dir", {}), false)
		&"set_speed":
			return "set_speed(%s)" % _num_code(op_call.get("speed", 0.0))
		&"anchor_drift":
			return "anchor_drift(%s, %s, %s, %s, %s, %s, %s)" % [
				str(int(op_call.get("anchor_id", 0))), _vec2_code(op_call.get("offset", Vector2.ZERO)),
				_num_code(op_call.get("angle", 0.0)), _num_code(op_call.get("speed", 0.0)),
				str(bool(op_call.get("use_global", true))), _num_code(op_call.get("initial", 0.0)),
				str(bool(op_call.get("render_heading", false)))]
		&"drift":
			return "drift(%s, %s, %s)" % [_num_code(op_call.get("angle", 0.0)), _num_code(op_call.get("speed", 0.0)), _num_code(op_call.get("initial", 0.0))]
	return "pass  # 未知 Move %s" % op


func _until_code(op_call: Dictionary) -> String:
	var op := StringName(op_call.get("op", &"never"))
	var base := ""
	match op:
		&"never": base = "until_never()"
		&"elapsed": base = "until_elapsed(%s)" % _num_code(op_call.get("t", 0.0))
		&"near": base = "until_near(%s, %s)" % [_target_code(op_call.get("target", &"")), _num_code(op_call.get("r", 0.0))]
		&"at_wall": base = "until_at_wall(%s)" % _wall_code(int(op_call.get("mask", 0)))
		&"speed": base = "until_speed(%s, %s)" % [_cmp_code(int(op_call.get("cmp", BulletLifecycle.CMP_LE))), _num_code(op_call.get("value", 0.0))]
		&"turned": base = "until_turned()"
		_: return "pass  # 未知 Until %s" % op
	if op_call.has("every"):
		base += ".every(%s)" % _num_code(op_call["every"])
	if op_call.has("every_ticks"):
		base += ".every_ticks(%d)" % int(op_call["every_ticks"])
	return base


func _action_code(op_call: Dictionary) -> String:
	var op := StringName(op_call.get("op", &""))
	match op:
		&"emit":
			return "emit(%s, %s, %s, %s)" % [
				_spawn_code(op_call.get("spawn_slot", "current")), _dir_code(op_call.get("dir", {}), true),
				_num_code(op_call.get("speed", 0.0)), _at_code(op_call.get("at", BulletLifecycle.AT_CURRENT))]
		&"emit_variant":
			var spawns: Array = op_call.get("spawns", [])
			var slots: Array = op_call.get("spawn_slots", [])
			# 快照会把 spawns 存成空数组（BulletData 不可序列化），所以按 slots 也要能生成 A/B。
			var count := maxi(maxi(spawns.size(), slots.size()), 2)
			var parts: Array[String] = []
			for i in count:
				parts.append(_spawn_code(slots[i] if i < slots.size() else "current"))
			var arr_code := "[" + ", ".join(parts) + "]"
			return "emit_variant(%s, %s, %s, %s)" % [
				arr_code, _dir_code(op_call.get("dir", {}), true),
				_num_code(op_call.get("speed", 0.0)), _at_code(op_call.get("at", BulletLifecycle.AT_CURRENT))]
		&"sfx":
			var key := _string_name_code(op_call.get("key", &""))
			if op_call.has("db"):
				return "sfx(%s, %s)" % [key, _num_code(op_call["db"])]
			return "sfx(%s)" % key
		&"despawn": return "despawn()"
		&"clear_fx": return "clear_fx()"
		&"despawn_clear": return "despawn_clear()"
		&"on_end_heading": return "on_end_heading(%s)" % _dir_code(op_call.get("dir", {}), true)
		&"on_end_call": return "on_end_call(%s)" % _string_name_code(op_call.get("hook", &""))
	return "pass  # 未知 Action %s" % op


func _dir_code(dir_v: Variant, for_action: bool = false) -> String:
	var spec := DIR_SPEC.from_variant(dir_v)
	match spec.kind:
		BulletLifecycle.D_HEADING:
			var fn := "BulletLifecycle.world_heading" if for_action else "BulletLifecycle.heading"
			return "%s(%s)" % [fn, _num_code(spec.angle)]
		BulletLifecycle.D_TOWARD:
			return "BulletLifecycle.toward(%s, %s)" % [_target_code(spec.target), _num_code(spec.angle)]
		BulletLifecycle.D_AWAY:
			return "BulletLifecycle.away(%s, %s)" % [_target_code(spec.target), _num_code(spec.angle)]
		BulletLifecycle.D_FORWARD:
			return "BulletLifecycle.forward(%s)" % _num_code(spec.angle)
		BulletLifecycle.D_RANDOM:
			return "BulletLifecycle.random_dir(%s)" % _num_code(spec.angle)
		BulletLifecycle.D_CHANCE:
			return "BulletLifecycle.chance_toward(%s, %s, %s)" % [
				_target_code(spec.target), _num_code(spec.chance_p), _num_code(spec.angle)]
		BulletLifecycle.D_REFLECT:
			return "BulletLifecycle.reflect(%s)" % _num_code(spec.angle)
	return "BulletLifecycle.heading(0.0)"

func _target_code(target: Variant) -> String:
	match StringName(target):
		BulletLifecycle.T_PLAYER: return "BulletLifecycle.T_PLAYER"
		BulletLifecycle.T_NEAREST_ENEMY: return "BulletLifecycle.T_NEAREST_ENEMY"
		BulletLifecycle.T_BOSS: return "BulletLifecycle.T_BOSS"
	return "StringName(\"%s\")" % str(target)


func _at_code(at: Variant) -> String:
	return "BulletLifecycle.AT_PHASE_END" if int(at) == BulletLifecycle.AT_PHASE_END else "BulletLifecycle.AT_CURRENT"


func _cmp_code(cmp: int) -> String:
	return "BulletLifecycle.CMP_GE" if cmp == BulletLifecycle.CMP_GE else "BulletLifecycle.CMP_LE"


func _wall_code(mask: int) -> String:
	var parts: Array[String] = []
	if mask & BulletLifecycle.WALL_LEFT: parts.append("BulletLifecycle.WALL_LEFT")
	if mask & BulletLifecycle.WALL_RIGHT: parts.append("BulletLifecycle.WALL_RIGHT")
	if mask & BulletLifecycle.WALL_TOP: parts.append("BulletLifecycle.WALL_TOP")
	return " | ".join(parts) if not parts.is_empty() else "0"


func _spawn_code(slot: Variant) -> String:
	# 代码里不写真实例；按模板槽位给占位，作者替换成自己的 BulletData。
	match str(slot):
		"a": return "_spawn_a"
		"b": return "_spawn_b"
	return "_spawn"


func _vec2_code(v: Variant) -> String:
	var vec: Vector2 = v if v is Vector2 else Vector2.ZERO
	return "Vector2(%s, %s)" % [_num_code(vec.x), _num_code(vec.y)]


func _num_code(v: Variant) -> String:
	if v is int:
		return str(v)
	if v is float:
		return String.num(float(v), 6)
	return str(v)


func _string_name_code(v: Variant) -> String:
	return "&\"%s\"" % str(v)


## 静态校验：只查“拼装器能提前发现”的坑；编译期的 op/target 守卫仍在 BulletLifecycle。
## 返回 [] = 没发现问题；非空 = 人话错误列表。
func validate() -> Array[String]:
	var errors: Array[String] = []
	for i in phases.size():
		var p: Dictionary = phases[i]
		var has_rotate := false
		for m in p["moves"]:
			var mop := StringName(m.get("op", &""))
			if mop in [&"rotate", &"rotate_velocity", &"rotate_heading"]:
				has_rotate = true
			if mop == &"steer" and StringName(m.get("target", &"")) == &"":
				errors.append("相位 %d：steer 的 target 为空" % (i + 1))
		var u: Dictionary = p["until"]
		var uop := StringName(u.get("op", &"never"))
		if uop == &"turned" and not has_rotate:
			errors.append("相位 %d：until_turned 前必须有 rotate / rotate_velocity / rotate_heading" % (i + 1))
		if uop == &"near" and StringName(u.get("target", &"")) == &"":
			errors.append("相位 %d：until_near 的 target 为空" % (i + 1))
		for a in p["on_end"]:
			var aop := StringName(a.get("op", &""))
			if aop == &"emit" and a.get("spawn") == null:
				errors.append("相位 %d：emit 的 spawn 为空" % (i + 1))
			if aop == &"emit_variant":
				var d := DIR_SPEC.from_variant(a.get("dir", {}))
				if d.kind != BulletLifecycle.D_CHANCE:
					errors.append("相位 %d：emit_variant 的 dir 必须是 chance_toward" % (i + 1))
			if aop == &"on_end_call" and StringName(a.get("hook", &"")) == &"":
				errors.append("相位 %d：on_end_call 的 hook 为空" % (i + 1))
	return errors
