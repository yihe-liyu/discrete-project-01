## BulletLifecycle —— per-bullet 生命周期的**固定 schema 描述符** + fluent builder。
##
## 模型（完整参考见 docs/DANMAKU_API.md §3）：
##   BulletLifecycle = [Phase, Phase, ...]        有序，不可跳转
##   Phase = { moves: [Move...], until: Until, on_end: [Action...] }
##   每帧按顺序跑 moves；until 成立 → 执行 on_end → 进下一相位；then() 开新相位。
##
## 用法：
##   var lc := BulletLifecycle.new()
##   lc.accel_heading(-150.0).until_elapsed(2.0).sfx(&"kira", -8.0).despawn()
##   bullet_data.trajectory(lc)
##
## 设计要点：
##   ① 状态显式化：有状态 unit 自带槽（rotate→turned / steer→elapsed / anchor_drift→drift），
##      builder 自动分配、相位切换清零 → unit 组合互不污染。
##   ② unit 正交化：aim→steer(toward())；anchor+drift→anchor_drift；top_edge→at_wall；
##      near_player/near_boss→near(target)；emit 收方向表达式。
##   ③ 朝向与速度解耦：heading（朝向）出生取初速，rotate/set_heading 更新；
##      accel_heading / forward / random_dir / chance_toward 读它 → 速度反向后仍正确。
##
## 编译：compile() → packed program（原生 DanmakuStore 执行）；content_signature() 做结构去重。
## 创作者只调高层方法，看不到槽 / opcode。
class_name BulletLifecycle
extends RefCounted

# ---- Move 词汇（每帧施加的数学变换，共 9 个）----
const M_ACCEL_WORLD := &"accel_world"
const M_ACCEL_HEADING := &"accel_heading"
const M_ROTATE := &"rotate"
const M_STEER := &"steer"
const M_SPEED_LERP := &"speed_lerp"
const M_SCALE_SPEED := &"scale_speed"
const M_SET_HEADING := &"set_heading"
const M_SET_SPEED := &"set_speed"
const M_ANCHOR_DRIFT := &"anchor_drift"

# ---- Until 词汇（相位结束条件，5 + until_turned 糖）----
const C_NEVER := &"never"
const C_ELAPSED := &"elapsed"
const C_NEAR := &"near"
const C_AT_WALL := &"at_wall"
const C_STATE := &"state"

# ---- Action 词汇（相位结束时一次性，共 6 个）----
const A_EMIT := &"emit"
const A_SFX := &"sfx"
const A_DESPAWN := &"despawn"
const A_SET_HEADING := &"set_heading"
const A_SET_SPEED := &"set_speed"
const A_CALL := &"call"

# ---- 目标 ----
const T_PLAYER := &"player"                 ## 自机
const T_NEAREST_ENEMY := &"nearest_enemy"   ## 最近「可追击目标」（未开战 Boss 不算）
const T_BOSS := &"boss"                     ## Boss
# ---- 方向表达式 kind ----
const D_HEADING := &"heading"
const D_TOWARD := &"toward"
const D_AWAY := &"away"
const D_FORWARD := &"forward"
const D_RANDOM := &"random"
const D_CHANCE := &"chance"

# ---- 墙位掩码（注意：at_wall 只夹 左/右/上，下墙穿出）/ 状态槽比较 ----
const WALL_LEFT := 1
const WALL_RIGHT := 2
const WALL_TOP := 4
const WALL_BOTTOM := 8
const CMP_GE := 0
const CMP_LE := 1

## 有序相位：[{moves, until, on_end}]
var phases: Array = []
## 每弹状态槽数（所有相位取最大；builder 自动分配）。
var slots: int = 0
## 结构签名缓存（content_signature；0 = 未算）
var _content_sig: int = 0

var _moves: Array = []
var _until: Dictionary = {}
var _on_end: Array = []
var _slot_next: int = 0
var _last_turn_slot: int = -1
var _last_turn_limit: float = 0.0


func _init() -> void:
	_begin_phase()


func _begin_phase() -> void:
	_moves = []
	_until = {&"op": C_NEVER}
	_on_end = []
	_slot_next = 0
	_last_turn_slot = -1
	_last_turn_limit = 0.0
	phases.append({&"moves": _moves, &"until": _until, &"on_end": _on_end})


## 开始下一相位（线性，不跳转）。
func then() -> BulletLifecycle:
	_begin_phase()
	return self


func _alloc() -> int:
	var s := _slot_next
	_slot_next += 1
	slots = maxi(slots, _slot_next)
	return s


func _set_until(op: StringName, extra: Dictionary = {}) -> void:
	_until.clear()
	_until[&"op"] = op
	for k in extra:
		_until[k] = extra[k]


# ═══ 方向表达式（静态构造；供 steer / emit / set_heading / on_end_heading 用）═══

## 世界角：0 = 上，正 = 顺时针（屏幕 y 向下）。结果 = (sin a, -cos a)。
static func heading(angle: float) -> Dictionary:
	return {&"kind": D_HEADING, &"target": &"", &"angle": angle}

## 朝 target 方向再转 angle。**target 不可用时退化为向下 (0,1)** 再转 angle。
static func toward(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": D_TOWARD, &"target": target, &"angle": angle}

## 背对 target 再转 angle（逃离 / 回卷）。
static func away(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": D_AWAY, &"target": target, &"angle": angle}

## 沿弹**自身朝向**（出生朝向 / set_heading 改过的）再转 angle；与 heading(世界角) 正交。
static func forward(angle: float = 0.0) -> Dictionary:
	return {&"kind": D_FORWARD, &"target": &"", &"angle": angle}

## 沿自身朝向 ± spread 内**随机**（内核确定性 RNG，单通道；种子由宿主 RNG 派生）。
static func random_dir(spread: float) -> Dictionary:
	return {&"kind": D_RANDOM, &"target": &"", &"angle": spread}

## 以概率 p 朝 target，否则沿自身朝向再转 spread。
## **命中时精确朝 target，spread 只服务未命中的 fallback。**
## 也是 emit_variant 唯一的分支来源（0 = 未命中，1 = 命中）。
static func chance_toward(target: StringName, p: float, spread: float = 0.0) -> Dictionary:
	return {&"kind": D_CHANCE, &"target": target, &"angle": spread, &"p": p}


# ═══ Move（每帧施加；9 个）═══

## 世界坐标恒定加速度：velocity += v * dt（与朝向无关）。
func accel_world(v: Vector2) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_WORLD, &"vec": v})
	return self

## 沿**自身朝向**加速：velocity += heading * a * dt。
## 与速度解耦 → v=0 也不失义；a < 0 可减速到反向（往返探测弹的「回点」）。
func accel_heading(a: float) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_HEADING, &"a": a})
	return self

## 角速度 w（弧度/秒），同时转速度与朝向；limit > 0 时累计转角钳到 limit（自带槽）。
func rotate(w: float, limit: float = 0.0) -> BulletLifecycle:
	var s := _alloc()
	_last_turn_slot = s
	_last_turn_limit = limit
	_moves.append({&"op": M_ROTATE, &"w": w, &"limit": limit, &"slot": s})
	return self

## 朝 target 转向。ramp 秒内爬满转向权；dist_weight > 0 时近距离转得更快；
## 给了 speed_from/speed_to 时同时接管速度（homing 的融合一步，避免两段组合漂移）；
## steer_until > 0 时只在前 N 秒转。
func steer(target: StringName, max_turn_per_sec: float, ramp: float = 0.0, dist_weight: float = 0.0, speed_from: float = NAN, speed_to: float = NAN, steer_until: float = 0.0) -> BulletLifecycle:
	_moves.append({&"op": M_STEER, &"target": target, &"max_turn": max_turn_per_sec, &"ramp": ramp, &"dist_weight": dist_weight, &"speed_from": speed_from, &"speed_to": speed_to, &"steer_until": steer_until})
	return self

## 方向不变，速度按 elapsed/ramp 从 from_speed 线性插值到 to_speed。
func speed_lerp(from_speed: float, to_speed: float, ramp: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_LERP, &"from": from_speed, &"to": to_speed, &"ramp": ramp})
	return self

## 速度乘 f。**每帧乘 → 复利**；要线性变速用 speed_lerp。
func scale_speed(f: float) -> BulletLifecycle:
	_moves.append({&"op": M_SCALE_SPEED, &"f": f})
	return self

## 设速度方向（保持速度大小）**并同步朝向**。
func set_heading(dir: Dictionary) -> BulletLifecycle:
	_moves.append({&"op": M_SET_HEADING, &"dir": dir})
	return self

## 设速度大小（方向不变）。
func set_speed(speed: float) -> BulletLifecycle:
	_moves.append({&"op": M_SET_SPEED, &"speed": speed})
	return self

## 锚定 + 线性漂移（激光段）：pos = anchor_base + dir(angle) * drift。
## drift 首帧 = initial，之后每帧 += speed * dt；render_heading=true 时速度也设为 dir(angle)（供渲染朝向）。
## **必须在 trajectory(lc, anchor) 里提供锚点 spec**，否则退回 player + offset。
func anchor_drift(anchor_id: int, offset: Vector2, angle: float, speed: float, use_global: bool = true, initial: float = 0.0, render_heading: bool = false) -> BulletLifecycle:
	var s := _alloc()
	_moves.append({&"op": M_ANCHOR_DRIFT, &"anchor_id": anchor_id, &"offset": offset, &"angle": angle, &"speed": speed, &"use_global": use_global, &"initial": initial, &"render_heading": render_heading, &"slot": s})
	return self


# ═══ Until（相位结束条件；5 + until_turned 糖）═══

## 永不结束（靠 on_end 的 emit / despawn 手动结束）。
func until_never() -> BulletLifecycle:
	_set_until(C_NEVER)
	return self

## 相位经过 t 秒后结束。
func until_elapsed(t: float) -> BulletLifecycle:
	_set_until(C_ELAPSED, {&"t": t})
	return self

## 距 target < r 时结束。
## every > 0：每 every 秒最多检查一次；every_ticks > 0：每 N 帧检查一次（0 = 不节流）。
func until_near(target: StringName, r: float, every: float = 0.0, every_ticks: int = 0) -> BulletLifecycle:
	_set_until(C_NEAR, {&"target": target, &"r": r, &"every": every, &"every_ticks": every_ticks})
	return self

## 碰到掩码指定的墙时结束。**只识别 左(1) / 右(2) / 上(4)**（下墙穿出）。
## 触发时把落点夹到框上，供 emit(at_end=true) 使用。
func until_at_wall(mask: int) -> BulletLifecycle:
	_set_until(C_AT_WALL, {&"mask": mask})
	return self

## 读状态槽：cmp = CMP_GE(0) 槽 >= value；CMP_LE(1) 槽 <= value。
func until_state(slot: int, cmp: int, value: float) -> BulletLifecycle:
	_set_until(C_STATE, {&"slot": slot, &"cmp": cmp, &"value": value})
	return self

## 便捷：当前相位的 rotate 累计转角 >= 其 limit（curve 用法，不重复传 limit）。
func until_turned() -> BulletLifecycle:
	_set_until(C_STATE, {&"slot": _last_turn_slot, &"cmp": CMP_GE, &"value": _last_turn_limit})
	return self

# ═══ Action（当前相位的 on_end；相位结束时一次性执行）═══

## 播音效。key 见 docs/DANMAKU_API.md §7.2（如 &"kira" / &"shoot"）。
func sfx(key: StringName, db: float = 0.0) -> BulletLifecycle:
	_on_end.append({&"op": A_SFX, &"key": key, &"db": db})
	return self

## 相位结束时生成替换弹。
## - spawn：**BulletData**（推荐：可序列化、跨实例共用 program）／Callable()->BulletData（旧写法 / oracle）／Array（见 emit_variant）。
## - speed <= 0 → 继承当前速度大小；> 0 → 用该速度。
## - at_end = true → 用 until(at_wall) 输出的落点；否则用当前弹位置。
## - 事件回传 (program, local) 给宿主，由宿主实例化模板 —— Callable / BulletData 永不进原生。
func emit(spawn: Variant, dir: Dictionary, speed: float = 0.0, at_end: bool = false) -> BulletLifecycle:
	_on_end.append({&"op": A_EMIT, &"spawn": spawn, &"dir": dir, &"speed": speed, &"at_end": at_end})
	return self

## 变体发射：dir 的概率分支决定用 spawns 里哪个模板。内核**只回传分支号**，取模板在宿主侧。
## 目前唯一产分支的方向表达式是 chance_toward：0 = 未命中 → spawns[0]，1 = 命中 → spawns[1]。
## 典型用途：同一发分裂弹，自机狙那发换色 / 换贴图，玩家一眼能读出来。
func emit_variant(spawns: Array, dir: Dictionary, speed: float = 0.0, at_end: bool = false) -> BulletLifecycle:
	return emit(spawns, dir, speed, at_end)

## 回收自己。
func despawn() -> BulletLifecycle:
	_on_end.append({&"op": A_DESPAWN})
	return self

## 转向（保持速度大小）—— avoid / non_mid 的「逃离自机」。
func on_end_heading(dir: Dictionary) -> BulletLifecycle:
	_on_end.append({&"op": A_SET_HEADING, &"dir": dir})
	return self

## 低频内容回调：fn.call(pos, boss_pos, has_boss, host)。
## hook = **StringName**（推荐：注册表解析，可序列化、跨实例共用 program；需先 LIFECYCLE_HOOKS_SCRIPT.register）
##      或 **Callable**（旧写法 / oracle）。未注册的名字静默不调。
func on_end_call(hook: Variant) -> BulletLifecycle:
	_on_end.append({&"op": A_CALL, &"call": hook})
	return self


# ═══ Canned preset（10 个 move 的类型化薄包装）═══
# 组合定义在 LifecycleCatalog.build()（唯一真相）；这里只把类型化参数转成 params 字典。
# 每个 preset 的完整展开见 docs/DANMAKU_API.md §3.8。

## 沿初速方向加速 accel_rate；碰 左/右/上 框朝 Boss 转 bounce_angle 后发射替换弹 spawn 并自灭。
static func bounce(accel_rate: float, bounce_angle: float, spawn_speed: float, spawn: Variant,
		sfx_key: StringName = &"kira", sfx_db: float = -8.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"bounce", {
		&"accel": accel_rate, &"bounce_angle": bounce_angle, &"spawn_speed": spawn_speed,
		&"spawn": spawn, &"sfx": sfx_key, &"sfx_db": sfx_db,
	})


## 边飞边转 w，累计转满 limit 后停（进入空相位）。
static func curve(w: float, limit: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"curve", {&"curve": w, &"curve_limit": limit})


## 世界坐标恒定加速度 v，永不结束。
static func world_accel(v: Vector2) -> BulletLifecycle:
	return LifecycleCatalog.build(&"world_accel", {&"world_accel": v})


## 沿当前方向加速 a，永不结束。
static func accel(a: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"accel", {&"accel": a})


## 追踪最近敌机：按 angle_per_sec 转向、accel_time 秒内爬满转向权；
## 速度从 min_speed 升到 max_speed；proximity_boost 让近距离转得更快；持续 duration 秒。
static func homing(angle_per_sec := deg_to_rad(720.0), accel_time := 2.0, min_speed := 500.0,
		max_speed := 2000.0, duration := 2.0, proximity_boost := 150.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"homing", {
		&"homing_angle_per_sec": angle_per_sec, &"accel_time": accel_time,
		&"min_speed": min_speed, &"max_speed": max_speed,
		&"homing_duration": duration, &"proximity_boost": proximity_boost,
	})


## 沿初向加速 accel_rate；碰顶后向下发射替换弹 spawn 并自灭。
static func radial_accel(accel_rate: float, spawn: Variant, sfx_key: StringName = &"", sfx_db: float = 0.0) -> BulletLifecycle:
	return LifecycleCatalog.build(&"radial_accel", {
		&"accel_rate": accel_rate, &"spawn": spawn, &"sfx": sfx_key, &"sfx_db": sfx_db,
	})


## 靠近自机 proximity 时背向逃离，逃 flee_time 秒（每 jump 秒判定一次）。
static func avoid_player(proximity: float, jump: float, flee_time: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"avoid_player", {
		&"player_proximity": proximity, &"jump": jump, &"flee_time": flee_time,
	})


## 逃开自机（每 3 帧判定）→ 近 Boss boss_radius 时回调 burst 散圈并自灭。
## burst = hook 名（StringName，需先注册）或 Callable。
static func non_mid_flee(proximity: float, boss_radius: float, burst: Variant) -> BulletLifecycle:
	return LifecycleCatalog.build(&"non_mid_flee", {
		&"player_proximity": proximity, &"boss_radius": boss_radius, &"hook": burst,
	})


## 锚定激光（focus 子机是 player 子节点）：用锚点**局部 position**，不参与渲染朝向。
static func laser_follow(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"laser_follow", {
		&"anchor_id": anchor_id, &"anchor_offset": offset, &"angle": angle,
		&"drift_speed": drift_speed, &"initial_drift": initial_drift,
	})


## 锚定激光（子机是 World 兄弟）：用锚点 **global_position**，并把速度设为漂移方向（供渲染朝向）。
static func marisa_laser(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	return LifecycleCatalog.build(&"marisa_laser", {
		&"anchor_id": anchor_id, &"anchor_offset": offset, &"angle": angle,
		&"drift_speed": drift_speed, &"initial_drift": initial_drift,
	})


## 锚点解析（**唯一真相**；原生/参考解释器/测试都走它，避免两套语义漂移）：
##   anchor_id=0       → player + offset
##   use_global=true   → 锚点 global_position + offset（marisa 子机是 World 兄弟）
##   use_global=false  → player + 锚点局部 position（focus 子机是 player 子节点；
##                       **不读 global**，父级移动后 global 会滞后一帧 → 根部多偏 v·dt）
static func anchor_base(anchor_id: int, offset: Vector2, use_global: bool, player: Vector2) -> Vector2:
	if anchor_id != 0:
		var node: Object = instance_from_id(anchor_id)
		if node is Node2D:
			if use_global:
				return (node as Node2D).global_position + offset
			return player + (node as Node2D).position
	return player + offset


# ═══ L3：编译成原生可读的 packed program ═══
# op / target / dirk / cmp 的整数编码**必须与 C++ DanmakuStore.behavior_tick 一致**。
const ARGS := 8

const OP_M_ACCEL_WORLD := 1
const OP_M_ACCEL_HEADING := 2
const OP_M_ROTATE := 3
const OP_M_STEER := 4
const OP_M_SPEED_LERP := 5
const OP_M_SCALE_SPEED := 6
const OP_M_SET_HEADING := 7
const OP_M_SET_SPEED := 8
const OP_M_ANCHOR_DRIFT := 9
const OP_C_NEVER := 20
const OP_C_ELAPSED := 21
const OP_C_NEAR := 22
const OP_C_AT_WALL := 23
const OP_C_STATE := 24
const OP_A_EMIT := 40
const OP_A_SFX := 41
const OP_A_DESPAWN := 42
const OP_A_SET_HEADING := 43
const OP_A_SET_SPEED := 44
const OP_A_CALL := 45

const TG_PLAYER := 0
const TG_NEAREST := 1
const TG_BOSS := 2
const DK_HEADING := 0
const DK_TOWARD := 1
const DK_AWAY := 2
const DK_FORWARD := 3   ## 沿弹自身朝向（与速度解耦）
const DK_RANDOM := 4    ## 沿自身朝向 ± 随机
const DK_CHANCE := 5    ## p 概率朝 target，否则自身朝向旋转

## 编译为扁平 packed program。actions / sfx 是**程序级**表：事件回传 (program, local_id)，
## 由宿主查这两张表（Callable 永不进原生）。
func compile() -> Dictionary:
	var ops := PackedInt32Array()
	var args := PackedFloat32Array()
	var move_start := PackedInt32Array()
	var move_count := PackedInt32Array()
	var until_idx := PackedInt32Array()
	var act_start := PackedInt32Array()
	var act_count := PackedInt32Array()
	var actions: Array = []
	var sfx_keys: Array[StringName] = []
	for phase in phases:
		var mv: Array = phase[&"moves"]
		move_start.append(ops.size())
		move_count.append(mv.size())
		for m in mv:
			_emit(ops, args, _op_move(m[&"op"]), _args_move(m))
		until_idx.append(ops.size())
		_emit(ops, args, _op_cond(phase[&"until"][&"op"]), _args_cond(phase[&"until"]))
		var acts: Array = phase[&"on_end"]
		act_start.append(ops.size())
		act_count.append(acts.size())
		for a in acts:
			_emit(ops, args, _op_act(a[&"op"]), _args_act(a, actions, sfx_keys))
	return {
		&"ops": ops, &"args": args,
		&"move_start": move_start, &"move_count": move_count,
		&"until_idx": until_idx,
		&"act_start": act_start, &"act_count": act_count,
		&"phase_count": phases.size(), &"slots": slots,
		&"actions": actions, &"sfx": sfx_keys,
	}


## 结构签名（内容哈希，**不含实例身份**）：相同结构的 lifecycle 共用一个原生 program。
## 首次调用后缓存。actions（Callable）按**对象身份**参与 —— 结构相同但工厂不同的必须分开
## （program 的动作表按 program 存，串了就会调错工厂）。
func content_signature() -> int:
	if _content_sig != 0:
		return _content_sig
	var c := compile()
	var h: int = hash(c[&"ops"])
	h = h * 31 + hash(c[&"args"])
	h = h * 31 + hash(c[&"move_start"])
	h = h * 31 + hash(c[&"move_count"])
	h = h * 31 + hash(c[&"until_idx"])
	h = h * 31 + hash(c[&"act_start"])
	h = h * 31 + hash(c[&"act_count"])
	h = h * 31 + int(c[&"phase_count"]) * 7 + int(c[&"slots"])
	h = h * 31 + hash(c[&"sfx"])
	for a in c[&"actions"]:
		h = h * 31 + _hash_action(a)
	_content_sig = h if h != 0 else 1
	return _content_sig


## 动作表项的结构哈希（变体发射的模板数组递归展开）。
static func _hash_action(a: Variant) -> int:
	if a is Array:
		var sub: int = 1
		for item in a:
			sub = sub * 31 + _hash_action(item)
		return sub
	if a is Callable:
		return a.get_object_id() if a.is_valid() else 0
	if a is BulletData:
		return int(a.get_instance_id())
	if a is StringName:
		return hash(a)
	return 0


func _emit(ops: PackedInt32Array, args: PackedFloat32Array, op: int, a: Array) -> void:
	ops.append(op)
	for i in ARGS:
		args.append(float(a[i]) if i < a.size() else 0.0)


func _op_move(op: StringName) -> int:
	match op:
		M_ACCEL_WORLD: return OP_M_ACCEL_WORLD
		M_ACCEL_HEADING: return OP_M_ACCEL_HEADING
		M_ROTATE: return OP_M_ROTATE
		M_STEER: return OP_M_STEER
		M_SPEED_LERP: return OP_M_SPEED_LERP
		M_SCALE_SPEED: return OP_M_SCALE_SPEED
		M_SET_HEADING: return OP_M_SET_HEADING
		M_SET_SPEED: return OP_M_SET_SPEED
		M_ANCHOR_DRIFT: return OP_M_ANCHOR_DRIFT
	return 0


func _op_cond(op: StringName) -> int:
	match op:
		C_NEVER: return OP_C_NEVER
		C_ELAPSED: return OP_C_ELAPSED
		C_NEAR: return OP_C_NEAR
		C_AT_WALL: return OP_C_AT_WALL
		C_STATE: return OP_C_STATE
	return 0


func _op_act(op: StringName) -> int:
	match op:
		A_EMIT: return OP_A_EMIT
		A_SFX: return OP_A_SFX
		A_DESPAWN: return OP_A_DESPAWN
		A_SET_HEADING: return OP_A_SET_HEADING
		A_SET_SPEED: return OP_A_SET_SPEED
		A_CALL: return OP_A_CALL
	return 0


func _target_code(t: StringName) -> int:
	match t:
		T_PLAYER: return TG_PLAYER
		T_NEAREST_ENEMY: return TG_NEAREST
		T_BOSS: return TG_BOSS
	return -1


func _dir_args(d: Dictionary) -> Array:
	var dk := DK_HEADING
	if d[&"kind"] == D_TOWARD:
		dk = DK_TOWARD
	elif d[&"kind"] == D_AWAY:
		dk = DK_AWAY
	elif d[&"kind"] == D_FORWARD:
		dk = DK_FORWARD
	elif d[&"kind"] == D_RANDOM:
		dk = DK_RANDOM
	elif d[&"kind"] == D_CHANCE:
		dk = DK_CHANCE
	return [dk, _target_code(d[&"target"]), float(d[&"angle"]), float(d.get(&"p", 0.0))]


func _args_move(m: Dictionary) -> Array:
	match m[&"op"]:
		M_ACCEL_WORLD: return [Vector2(m[&"vec"]).x, Vector2(m[&"vec"]).y]
		M_ACCEL_HEADING: return [float(m[&"a"])]
		M_ROTATE: return [float(m[&"w"]), float(m[&"limit"]), float(m[&"slot"])]
		M_STEER: return [_target_code(m[&"target"]), float(m[&"max_turn"]), float(m[&"ramp"]), float(m[&"dist_weight"]), float(m[&"speed_from"]), float(m[&"speed_to"]), float(m[&"steer_until"])]
		M_SPEED_LERP: return [float(m[&"from"]), float(m[&"to"]), float(m[&"ramp"])]
		M_SCALE_SPEED: return [float(m[&"f"])]
		M_SET_HEADING: return _dir_args(m[&"dir"])
		M_SET_SPEED: return [float(m[&"speed"])]
		M_ANCHOR_DRIFT:
			var flags := 0.0
			if bool(m[&"use_global"]): flags += 1.0
			if bool(m[&"render_heading"]): flags += 2.0
			var off := Vector2(m[&"offset"])
			return [float(m[&"anchor_id"]), off.x, off.y, float(m[&"angle"]), float(m[&"speed"]), flags, float(m[&"initial"]), float(m[&"slot"])]
	return []


func _args_cond(c: Dictionary) -> Array:
	match c[&"op"]:
		C_ELAPSED: return [float(c[&"t"])]
		C_NEAR: return [_target_code(c[&"target"]), float(c[&"r"]), float(c[&"every"]), float(c[&"every_ticks"])]
		C_AT_WALL: return [float(c[&"mask"])]
		C_STATE: return [float(c[&"slot"]), float(c[&"cmp"]), float(c[&"value"])]
	return []


func _args_act(a: Dictionary, actions: Array, sfx_keys: Array[StringName]) -> Array:
	match a[&"op"]:
		A_EMIT:
			var aid := actions.size()
			actions.append(a[&"spawn"])
			return [float(aid)] + _dir_args(a[&"dir"]) + [float(a[&"speed"]), 1.0 if bool(a[&"at_end"]) else 0.0]
		A_SFX:
			var sid := sfx_keys.size()
			sfx_keys.append(a[&"key"])
			return [float(sid), float(a[&"db"])]
		A_SET_HEADING: return _dir_args(a[&"dir"])
		A_SET_SPEED: return [float(a[&"speed"])]
		A_CALL:
			var cid := actions.size()
			actions.append(a[&"call"])
			return [float(cid)]
	return []
