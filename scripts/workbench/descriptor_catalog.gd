extends RefCounted
## DescriptorCatalog —— `BulletLifecycle` 原语的**元数据 + 唯一 apply 分发**。
##
## F10 拼装器只做两件事：
##   1. 把 UI 的 `{op, args}` 通过本文件翻译成 builder 调用（组合逻辑仍只在 BulletLifecycle）；
##   2. 用 MOVES/UNTILS/ACTIONS/DIRS 给 UI 提供词汇表和参数表单。
##
## **不加 class_name**：工作台/测试用 preload，避免新 class_name 全局缓存未导入。
## **不复制组合**：`apply_*()` 只调 `BulletLifecycle` 的公开 builder；预设的展开也走这里。

const MOVES: Array = [
	{id = &"accel_world", label = "世界加速", signature = "accel_world(v: Vector2)",
	 params = [{key = "v", type = "Vector2", default = Vector2.ZERO}]},
	{id = &"accel_heading", label = "沿朝向加速", signature = "accel_heading(a: float)",
	 params = [{key = "a", type = "float", default = 0.0}]},
	{id = &"rotate", label = "旋转（速度+朝向）", signature = "rotate(w, limit=0)",
	 params = [{key = "w", type = "float", default = 0.0}, {key = "limit", type = "float", default = 0.0}]},
	{id = &"rotate_velocity", label = "只转速度", signature = "rotate_velocity(w, limit=0)",
	 params = [{key = "w", type = "float", default = 0.0}, {key = "limit", type = "float", default = 0.0}]},
	{id = &"rotate_heading", label = "只转朝向", signature = "rotate_heading(w, limit=0)",
	 params = [{key = "w", type = "float", default = 0.0}, {key = "limit", type = "float", default = 0.0}]},
	{id = &"steer", label = "朝目标转向", signature = "steer(target, max_turn, ramp=0, dist_weight=0, steer_until=0)",
	 params = [
		{key = "target", type = "target", default = BulletLifecycle.T_NEAREST_ENEMY},
		{key = "max_turn", type = "float", default = TAU},
		{key = "ramp", type = "float", default = 0.0},
		{key = "dist_weight", type = "float", default = 0.0},
		{key = "steer_until", type = "float", default = 0.0},
	 ]},
	{id = &"speed_lerp", label = "速度线性插值", signature = "speed_lerp(from, to, ramp)",
	 params = [{key = "from", type = "float", default = 0.0}, {key = "to", type = "float", default = 0.0}, {key = "ramp", type = "float", default = 0.0}]},
	{id = &"speed_mul", label = "速度复利乘", signature = "speed_mul(f)",
	 params = [{key = "f", type = "float", default = 1.0}]},
	{id = &"set_heading", label = "设朝向（保持速度）", signature = "set_heading(dir)",
	 params = [{key = "dir", type = "dir", default = {}}]},
	{id = &"set_speed", label = "设速度大小", signature = "set_speed(speed)",
	 params = [{key = "speed", type = "float", default = 0.0}]},
	{id = &"anchor_drift", label = "锚点漂移（激光）", signature = "anchor_drift(anchor_id, offset, angle, speed, use_global=true, initial=0, render_heading=false)",
	 params = [
		{key = "anchor_id", type = "int", default = 0},
		{key = "offset", type = "Vector2", default = Vector2.ZERO},
		{key = "angle", type = "float", default = 0.0},
		{key = "speed", type = "float", default = 0.0},
		{key = "use_global", type = "bool", default = true},
		{key = "initial", type = "float", default = 0.0},
		{key = "render_heading", type = "bool", default = false},
	 ]},
	{id = &"drift", label = "相位起点平移", signature = "drift(angle, speed, initial=0)",
	 params = [{key = "angle", type = "float", default = 0.0}, {key = "speed", type = "float", default = 0.0}, {key = "initial", type = "float", default = 0.0}]},
]

const UNTILS: Array = [
	{id = &"never", label = "永不结束", signature = "until_never()", params = []},
	{id = &"elapsed", label = "经过 N 秒", signature = "until_elapsed(t)", params = [{key = "t", type = "float", default = 0.0}]},
	{id = &"near", label = "靠近目标", signature = "until_near(target, r)",
	 params = [{key = "target", type = "target", default = BulletLifecycle.T_PLAYER}, {key = "r", type = "float", default = 0.0}]},
	{id = &"at_wall", label = "碰到场边", signature = "until_at_wall(mask)",
	 params = [{key = "mask", type = "int", default = 7}]},
	{id = &"speed", label = "速度比较", signature = "until_speed(cmp, value)",
	 params = [{key = "cmp", type = "int", default = BulletLifecycle.CMP_LE}, {key = "value", type = "float", default = 0.0}]},
	{id = &"turned", label = "累计转角", signature = "until_turned()", params = []},
]

const ACTIONS: Array = [
	{id = &"emit", label = "发射替换弹", signature = "emit(spawn, dir, speed=0, at=AT_CURRENT)",
	 params = [
		{key = "spawn", type = "spawn", default = null},
		{key = "dir", type = "dir", default = {}},
		{key = "speed", type = "float", default = 0.0},
		{key = "at", type = "at", default = BulletLifecycle.AT_CURRENT},
	 ]},
	{id = &"emit_variant", label = "二选一发射", signature = "emit_variant(spawns, dir, speed=0, at=AT_CURRENT)",
	 params = [
		{key = "spawns", type = "spawns", default = []},
		{key = "dir", type = "dir", default = {}},
		{key = "speed", type = "float", default = 0.0},
		{key = "at", type = "at", default = BulletLifecycle.AT_CURRENT},
	 ]},
	{id = &"sfx", label = "音效", signature = "sfx(key, db=SFX_LEVEL_DB)",
	 params = [{key = "key", type = "sfx", default = &""}, {key = "db", type = "float", default = AudioManager.SFX_LEVEL_DB}]},
	{id = &"despawn", label = "静默回收", signature = "despawn()", params = []},
	{id = &"clear_fx", label = "只播消散", signature = "clear_fx()", params = []},
	{id = &"despawn_clear", label = "消散 + 回收", signature = "despawn_clear()", params = []},
	{id = &"on_end_heading", label = "相位结束改朝向", signature = "on_end_heading(dir)",
	 params = [{key = "dir", type = "dir", default = {}}]},
	{id = &"on_end_call", label = "相位结束调 hook", signature = "on_end_call(hook)",
	 params = [{key = "hook", type = "hook", default = &""}]},
]

const DIRS: Array = [
	{id = &"heading", label = "世界角", signature = "heading(angle)",
	 params = [{key = "angle", type = "float", default = 0.0}]},
	{id = &"toward", label = "朝目标", signature = "toward(target, angle=0)",
	 params = [{key = "target", type = "target", default = BulletLifecycle.T_PLAYER}, {key = "angle", type = "float", default = 0.0}]},
	{id = &"away", label = "背目标", signature = "away(target, angle=0)",
	 params = [{key = "target", type = "target", default = BulletLifecycle.T_PLAYER}, {key = "angle", type = "float", default = 0.0}]},
	{id = &"forward", label = "沿自身朝向", signature = "forward(angle=0)",
	 params = [{key = "angle", type = "float", default = 0.0}]},
	{id = &"random", label = "自身朝向 ± 随机", signature = "random_dir(spread=PI)",
	 params = [{key = "spread", type = "float", default = PI}]},
	{id = &"chance", label = "概率朝目标", signature = "chance_toward(target, p, spread=0)",
	 params = [
		{key = "target", type = "target", default = BulletLifecycle.T_PLAYER},
		{key = "p", type = "float", default = 1.0},
		{key = "spread", type = "float", default = 0.0},
	 ]},
	{id = &"reflect", label = "镜面反射", signature = "reflect(angle=0)",
	 params = [{key = "angle", type = "float", default = 0.0}]},
]


static func move_defs() -> Array: return MOVES
static func until_defs() -> Array: return UNTILS
static func action_defs() -> Array: return ACTIONS
static func dir_defs() -> Array: return DIRS


static func has_op(kind: StringName, id: StringName) -> bool:
	for e in _defs(kind):
		if StringName(e.id) == id:
			return true
	return false


static func ids(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for e in _defs(kind):
		out.append(StringName(e.id))
	return out


static func _defs(kind: StringName) -> Array:
	match kind:
		&"move": return MOVES
		&"until": return UNTILS
		&"action": return ACTIONS
		&"dir": return DIRS
	return []


# ═══ apply：UI/Composer 的 {op, args} → builder ═══

static func apply_move(lc: BulletLifecycle, op_call: Dictionary) -> void:
	var op := StringName(op_call.get("op", &""))
	match op:
		&"accel_world":
			lc.accel_world(op_call.get("v", Vector2.ZERO))
		&"accel_heading":
			lc.accel_heading(float(op_call.get("a", 0.0)))
		&"rotate":
			lc.rotate(float(op_call.get("w", 0.0)), float(op_call.get("limit", 0.0)))
		&"rotate_velocity":
			lc.rotate_velocity(float(op_call.get("w", 0.0)), float(op_call.get("limit", 0.0)))
		&"rotate_heading":
			lc.rotate_heading(float(op_call.get("w", 0.0)), float(op_call.get("limit", 0.0)))
		&"steer":
			lc.steer(StringName(op_call.get("target", BulletLifecycle.T_NEAREST_ENEMY)),
				float(op_call.get("max_turn", 0.0)), float(op_call.get("ramp", 0.0)),
				float(op_call.get("dist_weight", 0.0)), float(op_call.get("steer_until", 0.0)))
		&"speed_lerp":
			lc.speed_lerp(float(op_call.get("from", 0.0)), float(op_call.get("to", 0.0)), float(op_call.get("ramp", 0.0)))
		&"speed_mul":
			lc.speed_mul(float(op_call.get("f", 1.0)))
		&"set_heading":
			lc.set_heading(op_call.get("dir", BulletLifecycle.heading(0.0)))
		&"set_speed":
			lc.set_speed(float(op_call.get("speed", 0.0)))
		&"anchor_drift":
			lc.anchor_drift(int(op_call.get("anchor_id", 0)), op_call.get("offset", Vector2.ZERO),
				float(op_call.get("angle", 0.0)), float(op_call.get("speed", 0.0)),
				bool(op_call.get("use_global", true)), float(op_call.get("initial", 0.0)),
				bool(op_call.get("render_heading", false)))
		&"drift":
			lc.drift(float(op_call.get("angle", 0.0)), float(op_call.get("speed", 0.0)), float(op_call.get("initial", 0.0)))
		_:
			push_error("DescriptorCatalog: 未知 Move op '%s'" % str(op))


static func apply_until(lc: BulletLifecycle, op_call: Dictionary) -> void:
	var op := StringName(op_call.get("op", &"never"))
	match op:
		&"never":
			lc.until_never()
		&"elapsed":
			lc.until_elapsed(float(op_call.get("t", 0.0)))
		&"near":
			lc.until_near(StringName(op_call.get("target", &"")), float(op_call.get("r", 0.0)))
		&"at_wall":
			lc.until_at_wall(int(op_call.get("mask", 0)))
		&"speed":
			lc.until_speed(int(op_call.get("cmp", 0)), float(op_call.get("value", 0.0)))
		&"turned":
			lc.until_turned()
		_:
			push_error("DescriptorCatalog: 未知 Until op '%s'" % str(op))
			return
	if op_call.has("every"):
		lc.every(float(op_call["every"]))
	if op_call.has("every_ticks"):
		lc.every_ticks(int(op_call["every_ticks"]))


static func apply_action(lc: BulletLifecycle, op_call: Dictionary) -> void:
	var op := StringName(op_call.get("op", &""))
	match op:
		&"emit":
			lc.emit(op_call.get("spawn"), op_call.get("dir", BulletLifecycle.heading(0.0)),
				float(op_call.get("speed", 0.0)), int(op_call.get("at", BulletLifecycle.AT_CURRENT)))
		&"emit_variant":
			lc.emit_variant(op_call.get("spawns", []), op_call.get("dir", BulletLifecycle.heading(0.0)),
				float(op_call.get("speed", 0.0)), int(op_call.get("at", BulletLifecycle.AT_CURRENT)))
		&"sfx":
			if op_call.has("db"):
				lc.sfx(StringName(op_call.get("key", &"")), float(op_call["db"]))
			else:
				lc.sfx(StringName(op_call.get("key", &"")))
		&"despawn":
			lc.despawn()
		&"clear_fx":
			lc.clear_fx()
		&"despawn_clear":
			lc.despawn_clear()
		&"on_end_heading":
			lc.on_end_heading(op_call.get("dir", BulletLifecycle.heading(0.0)))
		&"on_end_call":
			lc.on_end_call(op_call.get("hook", &""))
		_:
			push_error("DescriptorCatalog: 未知 Action op '%s'" % str(op))


static func make_dir(id: StringName, args: Dictionary = {}) -> Dictionary:
	match id:
		&"heading":
			return BulletLifecycle.heading(float(args.get("angle", 0.0)))
		&"toward":
			return BulletLifecycle.toward(StringName(args.get("target", BulletLifecycle.T_PLAYER)), float(args.get("angle", 0.0)))
		&"away":
			return BulletLifecycle.away(StringName(args.get("target", BulletLifecycle.T_PLAYER)), float(args.get("angle", 0.0)))
		&"forward":
			return BulletLifecycle.forward(float(args.get("angle", 0.0)))
		&"random":
			return BulletLifecycle.random_dir(float(args.get("spread", PI)))
		&"chance":
			return BulletLifecycle.chance_toward(StringName(args.get("target", BulletLifecycle.T_PLAYER)),
				float(args.get("p", 1.0)), float(args.get("spread", 0.0)))
		&"reflect":
			return BulletLifecycle.reflect(float(args.get("angle", 0.0)))
	push_error("DescriptorCatalog: 未知 Dir op '%s'" % str(id))
	return BulletLifecycle.heading(0.0)
