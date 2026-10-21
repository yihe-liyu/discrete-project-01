## BulletLifecycle 的纯编译器：只读 phases/slots，输出原生 packed program。
##
## 边界（DSL10）：
##   · 不持有 BulletData / Callable / sfx 等宿主对象 → [code]compile_program()[/code] 可脱离宿主单测；
##   · action 的 local id 按「EMIT / EMIT_VARIANT / CALL 共用 actions 序号，SFX 单独 sfx 序号」
##     纯结构分配；[code]LifecycleHostTable.build()[/code] 按同一遍历顺序填模板表，两边天然对齐。
##   · op / target / dirk 的整数编码必须与 C++ DanmakuStore.behavior_tick 一致。
class_name LifecycleCompiler
extends RefCounted

const DIR_SPEC := preload("res://scripts/kernel_bridge/lifecycle/dir_spec.gd")

# ---- Move 词汇（每帧施加的数学变换，9 个 op）----
const M_ACCEL_WORLD := &"accel_world"
const M_ACCEL_HEADING := &"accel_heading"
const M_ROTATE := &"rotate"
const M_STEER := &"steer"
const M_SPEED_LERP := &"speed_lerp"
const M_SPEED_MUL := &"speed_mul"
const M_SET_HEADING := &"set_heading"
const M_SET_SPEED := &"set_speed"
const M_POSITION := &"position"
const POS_PHASE_START := 0
const POS_ANCHOR := 1

# ---- Until 词汇 ----
const C_NEVER := &"never"
const C_ELAPSED := &"elapsed"
const C_NEAR := &"near"
const C_AT_WALL := &"at_wall"
const C_STATE := &"state"
const C_SPEED := &"speed"

# ---- Action 词汇 ----
const A_EMIT := &"emit"
const A_EMIT_VARIANT := &"emit_variant"
const A_SFX := &"sfx"
const A_DESPAWN := &"despawn"
const A_SET_HEADING := &"set_heading"
const A_SET_SPEED := &"set_speed"
const A_CALL := &"call"
const A_CLEAR_FX := &"clear_fx"

# ---- 目标 / 墙位 / 比较 ----
const T_PLAYER := &"player"
const T_NEAREST_ENEMY := &"nearest_enemy"
const T_BOSS := &"boss"
const WALL_LEFT := 1
const WALL_RIGHT := 2
const WALL_TOP := 4
const CMP_GE := 0
const CMP_LE := 1
const AT_CURRENT := 0
const AT_PHASE_END := 1
const ROT_BOTH := 0
const ROT_VELOCITY := 1
const ROT_HEADING := 2

# ---- 原生 opcode / 参数 ----
const ARGS := 12
const MAX_SLOTS := 8

const OP_M_ACCEL_WORLD := 1
const OP_M_ACCEL_HEADING := 2
const OP_M_ROTATE := 3
const OP_M_STEER := 4
const OP_M_SPEED_LERP := 5
const OP_M_SPEED_MUL := 6
const OP_M_SET_HEADING := 7
const OP_M_SET_SPEED := 8
const OP_M_POSITION := 9
const OP_C_NEVER := 20
const OP_C_ELAPSED := 21
const OP_C_NEAR := 22
const OP_C_AT_WALL := 23
const OP_C_STATE := 24
const OP_C_SPEED := 25
const OP_A_EMIT := 40
const OP_A_SFX := 41
const OP_A_DESPAWN := 42
const OP_A_SET_HEADING := 43
const OP_A_SET_SPEED := 44
const OP_A_CALL := 45
const OP_A_EMIT_VARIANT := 46
const OP_A_CLEAR_FX := 47

const TG_PLAYER := 0
const TG_NEAREST := 1
const TG_BOSS := 2
const DK_HEADING := 0
const DK_TOWARD := 1
const DK_AWAY := 2
const DK_FORWARD := 3
const DK_RANDOM := 4
const DK_CHANCE := 5
const DK_REFLECT := 6


## 纯编译：只读 lc.phases / lc.slots；输出不含任何宿主对象。
static func compile_program(lc) -> Dictionary:
	var state := [false]
	var slots: int = int(lc.slots)
	if slots > MAX_SLOTS:
		push_warning("BulletLifecycle: 状态槽 %d 超过内核上限 %d（减少同相位有状态 unit；program 会被原生拒绝）" % [slots, MAX_SLOTS])
	var ops := PackedInt32Array()
	var args := PackedFloat32Array()
	var move_start := PackedInt32Array()
	var move_count := PackedInt32Array()
	var until_idx := PackedInt32Array()
	var act_start := PackedInt32Array()
	var act_count := PackedInt32Array()
	var action_idx := 0
	var sfx_idx := 0
	for phase in lc.phases:
		var mv: Array = phase[&"moves"]
		move_start.append(ops.size())
		move_count.append(mv.size())
		for m in mv:
			_emit(ops, args, _op_move(m[&"op"], state), _args_move(m, state))
		until_idx.append(ops.size())
		_emit(ops, args, _op_cond(phase[&"until"][&"op"], state), _args_cond(phase[&"until"], state))
		var acts: Array = phase[&"on_end"]
		act_start.append(ops.size())
		act_count.append(acts.size())
		for a in acts:
			var op: StringName = a[&"op"]
			var act_args := _args_act(a, state)
			match op:
				A_EMIT, A_EMIT_VARIANT, A_CALL:
					act_args = [float(action_idx)] + act_args
					action_idx += 1
				A_SFX:
					act_args = [float(sfx_idx)] + act_args
					sfx_idx += 1
			_emit(ops, args, _op_act(op, state), act_args)
	if state[0]:
		return _failed_program()
	return {
		&"ops": ops, &"args": args,
		&"move_start": move_start, &"move_count": move_count,
		&"until_idx": until_idx,
		&"act_start": act_start, &"act_count": act_count,
		&"phase_count": lc.phases.size(), &"slots": slots,
		&"compile_failed": false,
	}


## 结构签名（纯 program；不含 actions/sfx）。
static func program_signature(c: Dictionary) -> int:
	var h: int = hash(c[&"ops"])
	h = h * 31 + hash(c[&"args"])
	h = h * 31 + hash(c[&"move_start"])
	h = h * 31 + hash(c[&"move_count"])
	h = h * 31 + hash(c[&"until_idx"])
	h = h * 31 + hash(c[&"act_start"])
	h = h * 31 + hash(c[&"act_count"])
	h = h * 31 + int(c[&"phase_count"]) * 7 + int(c[&"slots"])
	return h


## 编译失败兜底：单相位 until_elapsed(0) → despawn（可见、不静默错行为）。
static func _failed_program() -> Dictionary:
	var ops := PackedInt32Array()
	var args := PackedFloat32Array()
	_emit(ops, args, OP_C_ELAPSED, [0.0, 0.0, 0.0])
	_emit(ops, args, OP_A_DESPAWN, [])
	return {
		&"ops": ops, &"args": args,
		&"move_start": PackedInt32Array([0]), &"move_count": PackedInt32Array([0]),
		&"until_idx": PackedInt32Array([0]),
		&"act_start": PackedInt32Array([1]), &"act_count": PackedInt32Array([1]),
		&"phase_count": 1, &"slots": 0,
		&"compile_failed": true,
	}


static func _emit(ops: PackedInt32Array, args: PackedFloat32Array, op: int, a: Array) -> void:
	ops.append(op)
	for i in ARGS:
		args.append(float(a[i]) if i < a.size() else 0.0)


static func _op_move(op: StringName, state: Array) -> int:
	match op:
		M_ACCEL_WORLD: return OP_M_ACCEL_WORLD
		M_ACCEL_HEADING: return OP_M_ACCEL_HEADING
		M_ROTATE: return OP_M_ROTATE
		M_STEER: return OP_M_STEER
		M_SPEED_LERP: return OP_M_SPEED_LERP
		M_SPEED_MUL: return OP_M_SPEED_MUL
		M_SET_HEADING: return OP_M_SET_HEADING
		M_SET_SPEED: return OP_M_SET_SPEED
		M_POSITION: return OP_M_POSITION
	push_error("BulletLifecycle.compile(): 未知 Move op '%s'" % str(op))
	state[0] = true
	return 0


static func _op_cond(op: StringName, state: Array) -> int:
	match op:
		C_NEVER: return OP_C_NEVER
		C_ELAPSED: return OP_C_ELAPSED
		C_NEAR: return OP_C_NEAR
		C_AT_WALL: return OP_C_AT_WALL
		C_STATE: return OP_C_STATE
		C_SPEED: return OP_C_SPEED
	push_error("BulletLifecycle.compile(): 未知 Until op '%s'" % str(op))
	state[0] = true
	return 0


static func _op_act(op: StringName, state: Array) -> int:
	match op:
		A_EMIT: return OP_A_EMIT
		A_EMIT_VARIANT: return OP_A_EMIT_VARIANT
		A_SFX: return OP_A_SFX
		A_DESPAWN: return OP_A_DESPAWN
		A_SET_HEADING: return OP_A_SET_HEADING
		A_SET_SPEED: return OP_A_SET_SPEED
		A_CALL: return OP_A_CALL
		A_CLEAR_FX: return OP_A_CLEAR_FX
	push_error("BulletLifecycle.compile(): 未知 Action op '%s'" % str(op))
	state[0] = true
	return 0


static func _target_code(t: StringName, state: Array) -> int:
	match t:
		T_PLAYER: return TG_PLAYER
		T_NEAREST_ENEMY: return TG_NEAREST
		T_BOSS: return TG_BOSS
		&"": return -1
	push_error("BulletLifecycle.compile(): 未知 target '%s'" % str(t))
	state[0] = true
	return -1


static func _dir_args(d: Variant, state: Array) -> Array:
	var spec := DIR_SPEC.from_variant(d)
	var dk := -1
	match spec.kind:
		DIR_SPEC.HEADING: dk = DK_HEADING
		DIR_SPEC.TOWARD: dk = DK_TOWARD
		DIR_SPEC.AWAY: dk = DK_AWAY
		DIR_SPEC.FORWARD: dk = DK_FORWARD
		DIR_SPEC.RANDOM: dk = DK_RANDOM
		DIR_SPEC.CHANCE: dk = DK_CHANCE
		DIR_SPEC.REFLECT: dk = DK_REFLECT
		_:
			push_error("BulletLifecycle.compile(): 未知方向 kind '%s'" % str(spec.kind))
			state[0] = true
			dk = DK_HEADING
	if spec.target == &"" and dk in [DK_TOWARD, DK_AWAY, DK_CHANCE]:
		push_error("BulletLifecycle.compile(): %s 的 target 为空（打错目标？）" % str(spec.kind))
		state[0] = true
	return [dk, _target_code(spec.target, state), spec.angle, spec.chance_p]


static func _args_move(m: Dictionary, state: Array) -> Array:
	match m[&"op"]:
		M_ACCEL_WORLD: return [Vector2(m[&"vec"]).x, Vector2(m[&"vec"]).y]
		M_ACCEL_HEADING: return [float(m[&"a"])]
		M_ROTATE: return [float(m[&"w"]), float(m[&"limit"]), float(m[&"slot"]), float(m[&"mode"])]
		M_STEER:
			if m[&"target"] == &"":
				push_error("BulletLifecycle.compile(): steer 的 target 为空（打错目标？）")
				state[0] = true
			return [_target_code(m[&"target"], state), float(m[&"max_turn"]), float(m[&"ramp"]), float(m[&"dist_weight"]), float(m[&"steer_until"])]
		M_SPEED_LERP: return [float(m[&"from"]), float(m[&"to"]), float(m[&"ramp"])]
		M_SPEED_MUL: return [float(m[&"f"])]
		M_SET_HEADING: return _dir_args(m[&"dir"], state)
		M_SET_SPEED: return [float(m[&"speed"])]
		M_POSITION:
			if int(m[&"mode"]) == POS_PHASE_START:
				return [0.0, 0.0, 0.0, 0.0, float(m[&"angle"]), float(m[&"speed"]), 0.0, float(m[&"initial"]), float(m[&"slot"]), float(m[&"sx"]), float(m[&"sy"])]
			var flags := 0.0
			if bool(m[&"use_global"]): flags += 1.0
			if bool(m[&"render_heading"]): flags += 2.0
			var off := Vector2(m[&"offset"])
			return [1.0, float(m[&"anchor_id"]), off.x, off.y, float(m[&"angle"]), float(m[&"speed"]), flags, float(m[&"initial"]), float(m[&"slot"]), -1.0, -1.0]
	return []


static func _args_cond(c: Dictionary, state: Array) -> Array:
	var head: Array = [float(c.get(&"every", 0.0)), float(c.get(&"every_ticks", 0))]
	match c[&"op"]:
		C_ELAPSED: return head + [float(c[&"t"])]
		C_NEAR:
			if c[&"target"] == &"":
				push_error("BulletLifecycle.compile(): until_near 的 target 为空（打错目标？）")
				state[0] = true
			return head + [_target_code(c[&"target"], state), float(c[&"r"])]
		C_AT_WALL: return head + [float(c[&"mask"])]
		C_STATE: return head + [float(c[&"slot"]), float(c[&"cmp"]), float(c[&"value"])]
		C_SPEED: return head + [float(c[&"cmp"]), float(c[&"value"])]
	return head


## action 参数不含 local id；compile_program 的循环按 op 类型前置 id。
static func _args_act(a: Dictionary, state: Array) -> Array:
	match a[&"op"]:
		A_EMIT:
			return _dir_args(a[&"dir"], state) + [float(a[&"speed"]), float(a[&"at"])]
		A_EMIT_VARIANT:
			var ch := DIR_SPEC.from_variant(a[&"chance"])
			if ch.target == &"":
				push_error("BulletLifecycle.compile(): emit_variant 的 chance target 为空（打错目标？）")
				state[0] = true
			return [ch.chance_p, float(DK_TOWARD), float(_target_code(ch.target, state)), 0.0,
				float(DK_FORWARD), -1.0, ch.angle, float(a[&"speed"]), float(a[&"at"])]
		A_SFX: return [float(a[&"db"])]
		A_SET_HEADING: return _dir_args(a[&"dir"], state)
		A_SET_SPEED: return [float(a[&"speed"])]
	return []
