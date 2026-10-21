## per-bullet 生命周期描述符 + fluent builder。
##
## [b]模型[/b]
## [codeblock]
## BulletLifecycle = [Phase, Phase, ...]
## Phase = { moves: [Move...], until: Until, on_end: [Action...] }
## [/codeblock]
## 每帧按顺序跑 moves；until 成立 → 执行 on_end → 进入下一相位；[method then] 开新相位。
## 最后一个相位结束后，弹不再受 program 驱动，按当前速度自由积分（出界由 cull 回收）。
## [br]
## [b]用法[/b][br]
## [codeblock]
## var lc := BulletLifecycle.new()
## lc.accel_heading(-150.0).until_elapsed(2.0).sfx(&"kira").despawn()
## bullet_data.trajectory(lc)
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 位置写入原语（[code]drift[/code] / [code]anchor_drift[/code]）同相位会互相覆盖，
## 也会覆盖速度积分；不要和速度原语混在同一相位。[br]
## - [code]anchor_drift[/code] 必须在 [code]trajectory(lc, anchor)[/code] 提供锚点 spec，否则退回自机。[br]
## - [code]until=never[/code] 的相位不会自动结束；最后一相位的 on_end 是死代码（编译会警告）。[br]
## 完整参考：[code]docs/DANMAKU_API.md[/code] §3；位置覆盖规则见 §9.13。
class_name BulletLifecycle
extends RefCounted

# ---- 外部模块 ----
const DIR_SPEC := preload("res://scripts/kernel_bridge/lifecycle/dir_spec.gd")
const COMPILER := preload("res://scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd")
const HOST_TABLE := preload("res://scripts/kernel_bridge/lifecycle/lifecycle_host_table.gd")

# ---- Move 词汇（对外 API 兼容别名；定义在 LifecycleCompiler）----
const M_ACCEL_WORLD := COMPILER.M_ACCEL_WORLD
const M_ACCEL_HEADING := COMPILER.M_ACCEL_HEADING
const M_ROTATE := COMPILER.M_ROTATE
const M_STEER := COMPILER.M_STEER
const M_SPEED_LERP := COMPILER.M_SPEED_LERP
const M_SPEED_MUL := COMPILER.M_SPEED_MUL
const M_SET_HEADING := COMPILER.M_SET_HEADING
const M_SET_SPEED := COMPILER.M_SET_SPEED
const M_POSITION := COMPILER.M_POSITION
const POS_PHASE_START := COMPILER.POS_PHASE_START
const POS_ANCHOR := COMPILER.POS_ANCHOR

# ---- Until / Action / 目标 / 墙位 ----
const C_NEVER := COMPILER.C_NEVER
const C_ELAPSED := COMPILER.C_ELAPSED
const C_NEAR := COMPILER.C_NEAR
const C_AT_WALL := COMPILER.C_AT_WALL
const C_STATE := COMPILER.C_STATE
const C_SPEED := COMPILER.C_SPEED
const A_EMIT := COMPILER.A_EMIT
const A_EMIT_VARIANT := COMPILER.A_EMIT_VARIANT
const A_SFX := COMPILER.A_SFX
const A_DESPAWN := COMPILER.A_DESPAWN
const A_SET_HEADING := COMPILER.A_SET_HEADING
const A_SET_SPEED := COMPILER.A_SET_SPEED
const A_CALL := COMPILER.A_CALL
const A_CLEAR_FX := COMPILER.A_CLEAR_FX
## 目标：自机。
const T_PLAYER := COMPILER.T_PLAYER
## 目标：最近的敌人。
const T_NEAREST_ENEMY := COMPILER.T_NEAREST_ENEMY
## 目标：Boss。
const T_BOSS := COMPILER.T_BOSS
## 墙掩码：左边界。
const WALL_LEFT := COMPILER.WALL_LEFT
## 墙掩码：右边界。
const WALL_RIGHT := COMPILER.WALL_RIGHT
## 墙掩码：上边界。
const WALL_TOP := COMPILER.WALL_TOP
## [code]until_speed()[/code] 比较：[code]|v| >= value[/code]。
const CMP_GE := COMPILER.CMP_GE
## [code]until_speed()[/code] 比较：[code]|v| <= value[/code]。
const CMP_LE := COMPILER.CMP_LE
## [code]emit()[/code] 落点：当前弹位置。
const AT_CURRENT := COMPILER.AT_CURRENT
## [code]emit()[/code] 落点：[code]until_at_wall()[/code] 记录的相位结束落点。
const AT_PHASE_END := COMPILER.AT_PHASE_END
## [code]rotate()[/code] 模式：速度与朝向一起转。
const ROT_BOTH := COMPILER.ROT_BOTH
## [code]rotate()[/code] 模式：只转速度。
const ROT_VELOCITY := COMPILER.ROT_VELOCITY
## [code]rotate()[/code] 模式：只转朝向。
const ROT_HEADING := COMPILER.ROT_HEADING

# ---- 原生参数（公共兼容别名；opcode 内部常量在 LifecycleCompiler）----
const ARGS := COMPILER.ARGS
const MAX_SLOTS := COMPILER.MAX_SLOTS

# ---- 方向 kind（定义在 DirSpec）----
## 方向表达式 kind：相对发射者朝向。
const D_HEADING := DIR_SPEC.HEADING
## 方向表达式 kind：朝目标。
const D_TOWARD := DIR_SPEC.TOWARD
## 方向表达式 kind：背向目标。
const D_AWAY := DIR_SPEC.AWAY
## 方向表达式 kind：沿当前朝向。
const D_FORWARD := DIR_SPEC.FORWARD
## 方向表达式 kind：随机方向。
const D_RANDOM := DIR_SPEC.RANDOM
## 方向表达式 kind：概率朝目标。
const D_CHANCE := DIR_SPEC.CHANCE
## 方向表达式 kind：沿当前速度反射。
const D_REFLECT := DIR_SPEC.REFLECT

## 有序相位：[{moves, until, on_end}]
var phases: Array = []
## 每弹状态槽数（所有相位取最大；builder 自动分配）。
var slots: int = 0
## 结构签名缓存（content_signature；0 = 未算）
var _content_sig: int = 0
## never 相位警告只报一次（compile() 可能被 content_signature / spawn 多次调用）
var _warned_never: bool = false

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
	# 节流是相位级横切属性：`.every()` / `.every_ticks()` 可能写在 until_* 之前，
	# 这里必须先保住修饰键再 clear；否则“先 every 再 until”会被静默清空。
	var every_sec: float = float(_until.get(&"every", 0.0))
	var ticks_mod: int = int(_until.get(&"every_ticks", 0))
	_until.clear()
	_until[&"op"] = op
	if every_sec > 0.0:
		_until[&"every"] = every_sec
	if ticks_mod > 0:
		_until[&"every_ticks"] = ticks_mod
	for k in extra:
		_until[k] = extra[k]


# ═══ 方向表达式（兼容入口；实现与词汇在 DirSpec）═══

## 绝对世界角；[code]angle[/code] 以向上为 0、顺时针为正（弧度）。只用于 [method set_heading]。
static func heading(angle: float) -> RefCounted:
	return DIR_SPEC.heading(angle)


## 显式世界角：emit / on_end_heading 用；不随发射者变的固定方向。
static func world_heading(angle: float) -> RefCounted:
	return DIR_SPEC.world_heading(angle)


## 朝目标的方向表达式；[code]angle[/code] 为额外偏移（弧度）。目标见 [code]T_PLAYER[/code] / [code]T_BOSS[/code] / [code]T_NEAREST_ENEMY[/code]。
static func toward(target: StringName, angle: float = 0.0) -> RefCounted:
	return DIR_SPEC.toward(target, angle)


## 背向目标的方向表达式；[code]angle[/code] 为额外偏移（弧度）。
static func away(target: StringName, angle: float = 0.0) -> RefCounted:
	return DIR_SPEC.away(target, angle)


## 沿当前朝向的方向表达式；[code]angle[/code] 为额外偏移（弧度）。
static func forward(angle: float = 0.0) -> RefCounted:
	return DIR_SPEC.forward(angle)


## 随机方向；以当前朝向为中心 ±[code]spread[/code] 均匀随机（单侧张角，总张角 = 2×spread），由内核 RNG 求值。
static func random_dir(spread: float) -> RefCounted:
	return DIR_SPEC.random_dir(spread)


## 概率方向：[code]p[/code] 概率精确朝目标，否则 [code]forward[/code] 旋转 [code]spread[/code]；配合 [code]emit_variant()[/code]。
static func chance_toward(target: StringName, p: float, spread: float = 0.0) -> RefCounted:
	return DIR_SPEC.chance_toward(target, p, spread)


## 把当前速度按发射点所在场边翻分量，再转 [code]angle[/code]；未贴边时退化为当前朝向。
## 配 [method until_at_wall] + [code]AT_PHASE_END[/code] 使用。
static func reflect(angle: float = 0.0) -> RefCounted:
	return DIR_SPEC.reflect(angle)


# ═══ Move（每帧施加；9 个）═══

## 世界坐标恒定加速度：velocity += v * dt（与朝向无关）。
func accel_world(v: Vector2) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_WORLD, &"vec": v})
	return self

## 沿自身朝向加速：velocity += heading * a * dt。
## 与速度解耦 → v=0 也不失义；a < 0 可减速到反向（往返探测弹的「回点」）。
func accel_heading(a: float) -> BulletLifecycle:
	_moves.append({&"op": M_ACCEL_HEADING, &"a": a})
	return self

## 角速度 w（弧度/秒），同时转速度与朝向；limit > 0 时累计转角钳到 limit（自带槽）。
func rotate(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_BOTH)

## 只转速度（朝向不变）。
func rotate_velocity(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_VELOCITY)

## 只转朝向（速度不变）。
func rotate_heading(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_HEADING)

func _add_rotate(w: float, limit: float, mode: int) -> BulletLifecycle:
	var s := _alloc()
	_last_turn_slot = s
	_last_turn_limit = limit
	_moves.append({&"op": M_ROTATE, &"w": w, &"limit": limit, &"slot": s, &"mode": mode})
	return self

## 朝 target 转向（只转向、不改速度）。ramp 秒内爬满转向权；dist_weight > 0 时近距离转得更快；
## steer_until > 0 时只在前 N 秒转。变速是独立轴：需要时另加 speed_lerp / set_speed。
func steer(target: StringName, max_turn_per_sec: float, ramp: float = 0.0, dist_weight: float = 0.0, steer_until: float = 0.0) -> BulletLifecycle:
	_moves.append({&"op": M_STEER, &"target": target, &"max_turn": max_turn_per_sec, &"ramp": ramp, &"dist_weight": dist_weight, &"steer_until": steer_until})
	return self

## 方向不变，速度按 elapsed/ramp 从 from_speed 线性插值到 to_speed。
func speed_lerp(from_speed: float, to_speed: float, ramp: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_LERP, &"from": from_speed, &"to": to_speed, &"ramp": ramp})
	return self

## 每帧把速度乘 f（复利/指数算子，不是瞬时设定）。线性变速用 speed_lerp，瞬时设定用 set_speed。
func speed_mul(f: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_MUL, &"f": f})
	return self

## 设速度方向（保持速度大小）并同步朝向。
func set_heading(dir: Variant) -> BulletLifecycle:
	_moves.append({&"op": M_SET_HEADING, &"dir": DIR_SPEC.from_variant(dir)})
	return self

## 设速度大小（方向不变）。
func set_speed(speed: float) -> BulletLifecycle:
	_moves.append({&"op": M_SET_SPEED, &"speed": speed})
	return self

## 编译为统一 [code]M_POSITION[/code]（mode=POS_PHASE_START）。
## 从相位起点沿 dir(angle) 匀速平移：pos = 相位起点 + dir(angle) * 累计位移。
## 与 anchor_drift 的区别：不锚定任何外部对象，基准就是本相位开始时自己的位置；同样不改速度/朝向。
## 位置写入原语：直接写 pos、覆盖积分；与 anchor_drift / 速度原语同相位会互相覆盖（DANMAKU_API §9.13）。
## 典型：整圈弹幕先「整体沿一个方向平移」一段距离（速度/朝向保留），平移结束后各自按出生方向飞出。
func drift(angle: float, speed: float, initial: float = 0.0) -> BulletLifecycle:
	var sx := _alloc()
	var sy := _alloc()
	var sd := _alloc()
	_moves.append({&"op": M_POSITION, &"mode": POS_PHASE_START, &"angle": angle, &"speed": speed, &"sx": sx, &"sy": sy, &"initial": initial, &"slot": sd})
	return self


## 编译为统一 [code]M_POSITION[/code]（mode=POS_ANCHOR）。
## 锚定 + 线性漂移（激光段）：pos = anchor_base + dir(angle) * drift。
## drift 首帧 = initial，之后每帧 += speed * dt；render_heading=true 时设置独立渲染朝向（render_rot 通道，不写 velocity）。
## 位置写入原语：直接写 pos、覆盖积分；与 drift / 速度原语同相位会互相覆盖（DANMAKU_API §9.13）。
## 必须在 trajectory(lc, anchor) 里提供锚点 spec，否则退回 player + offset。
func anchor_drift(anchor_id: int, offset: Vector2, angle: float, speed: float, use_global: bool = true, initial: float = 0.0, render_heading: bool = false) -> BulletLifecycle:
	var s := _alloc()
	_moves.append({&"op": M_POSITION, &"mode": POS_ANCHOR, &"anchor_id": anchor_id, &"offset": offset, &"angle": angle, &"speed": speed, &"use_global": use_global, &"initial": initial, &"render_heading": render_heading, &"slot": s})
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

## 距 target < r 时结束。节流用链式 [code].every(秒)[/code] / [code].every_ticks(帧)[/code]（对所有条件通用）。
func until_near(target: StringName, r: float) -> BulletLifecycle:
	_set_until(C_NEAR, {&"target": target, &"r": r})
	return self

## 碰到掩码指定的墙（左 1 / 右 2 / 上 4）时结束。
## 纯谓词：只在越界时把相位结束落点写进 Until 输出（不改弹自身位置），供 emit(..., at=AT_PHASE_END) 使用。
func until_at_wall(mask: int) -> BulletLifecycle:
	_set_until(C_AT_WALL, {&"mask": mask})
	return self

## 速度大小满足比较时结束（|v| cmp value；cmp = CMP_GE / CMP_LE）。
## 典型：撞墙后 [code]accel_heading(-b)[/code] 减速，[code]until_speed(CMP_LE, v_min)[/code] 降到 v_min 即停。
func until_speed(cmp: int, value: float) -> BulletLifecycle:
	_set_until(C_SPEED, {&"cmp": cmp, &"value": value})
	return self


## 便捷：当前相位的 rotate 累计转角 >= 其 limit（curve 用法）。必须跟在同相位的 rotate 之后。
func until_turned() -> BulletLifecycle:
	if _last_turn_slot < 0:
		push_warning("BulletLifecycle.until_turned(): 本相位没有前置 rotate，退化为 until_never")
		return until_never()
	if _last_turn_limit <= 0.0:
		push_warning("BulletLifecycle.until_turned(): rotate limit<=0（无限转角）无「转满」定义，退化为 until_never")
		return until_never()
	_set_state_until(_last_turn_slot, CMP_GE, _last_turn_limit)
	return self

# ---- Until 通用修饰（节流是相位级横切属性，任何条件都能套）----

## 每 [code]sec[/code] 秒最多检查一次该相位的 until。
func every(sec: float) -> BulletLifecycle:
	_until[&"every"] = sec
	return self

## 每 [code]n[/code] 帧最多检查一次该相位的 until。
func every_ticks(n: int) -> BulletLifecycle:
	_until[&"every_ticks"] = n
	return self

## 内部：状态槽条件（slot 对创作者不可见，仅 until_turned 用）。
func _set_state_until(slot: int, cmp: int, value: float) -> void:
	_set_until(C_STATE, {&"slot": slot, &"cmp": cmp, &"value": value})

# ═══ Action（当前相位的 on_end；相位结束时一次性执行）═══

## 播音效。key 见 docs/DANMAKU_API.md §7.2（如 &"kira" / &"shoot"）。
## [code]db[/code] 默认必须是总电平，不能是 0.0 —— [code]0.0 dB[/code] 是"满音量"，会让这个音比其它响约 15 dB
## （内容里普遍写 [code]lc.sfx(&"kira")[/code] 不传 db）。
func sfx(key: StringName, db: float = AudioManager.SFX_LEVEL_DB) -> BulletLifecycle:
	_on_end.append({&"op": A_SFX, &"key": key, &"db": db})
	return self

## 相位结束时生成替换弹。
## - spawn：BulletData（推荐：可序列化、跨实例共用 program）／Callable()->BulletData（旧写法 / oracle）／Array（见 emit_variant）。
## - speed <= 0 → 继承当前速度大小；> 0 → 用该速度。
## - at = AT_PHASE_END → 用 until(at_wall) 输出的相位结束落点；AT_CURRENT（默认）→ 当前弹位置。
## - 事件回传 (program, local) 给宿主，由宿主实例化模板 —— Callable / BulletData 永不进原生。
func emit(spawn: Variant, dir: Variant, speed: float = 0.0, at: int = AT_CURRENT) -> BulletLifecycle:
	return _append_emit(spawn, DIR_SPEC.from_variant(dir), speed, at, null)


## 每次 emit 时在 base speed 上做 ±spread 的逐发求值（均匀分布）。
## speed<=0 仍表示继承当前速度；spread=0 等价于常量。原生只收到 base speed，
## 倍率放在宿主表，由 KernelNativeSystem / 参考解释器在事件落地时求值。
func emit_speed_rel(spawn: Variant, dir: Variant, speed: float = 0.0, spread: float = 0.15,
		at: int = AT_CURRENT) -> BulletLifecycle:
	var lo := clampf(1.0 - absf(spread), 0.0, 2.0)
	var hi := 1.0 + absf(spread)
	return _append_emit(spawn, DIR_SPEC.from_variant(dir), speed, at, {&"min": lo, &"max": hi})


func _append_emit(spawn: Variant, spec: RefCounted, speed: float, at: int,
		speed_spec: Variant) -> BulletLifecycle:
	# 裸 heading 是世界角，不随发射者变；在 emit 里必须显式写 world_heading，防“以为会跟随”的误用。
	if spec.eval_phase == DIR_SPEC.EvalPhase.WORLD and not spec.allow_world:
		push_error("BulletLifecycle.emit(): world angle 请用 world_heading()，不要用 heading()（heading 只给 set_heading）")
	var act := {&"op": A_EMIT, &"spawn": spawn, &"dir": spec, &"speed": speed, &"at": at}
	if speed_spec != null:
		act[&"speed_spec"] = speed_spec
	_on_end.append(act)
	return self

## 变体发射：内核抽一次 RNG 决定分支，宿主按分支号取 spawns 里哪个模板（0=未命中，1=命中）。
## [code]dir[/code] 必须是 [code]chance_toward(target, p, spread)[/code]：命中→精确朝 target，未命中→forward 旋转 spread。
## 分支由内核显式抽取，不再藏在方向求值里。
func emit_variant(spawns: Array, dir: Variant, speed: float = 0.0, at: int = AT_CURRENT) -> BulletLifecycle:
	var spec := DIR_SPEC.from_variant(dir)
	if spec.kind != D_CHANCE:
		push_warning("BulletLifecycle.emit_variant(): dir 应为 chance_toward(...)，已退化为普通 emit")
		return emit(spawns, spec, speed, at)
	_on_end.append({&"op": A_EMIT_VARIANT, &"spawns": spawns, &"chance": spec, &"speed": speed, &"at": at})
	return self

## 回收自己。静默 —— 不播任何特效（这是默认语义：多数 despawn 发生在屏外或做超时清理）。
## 想让人看见"这颗弹消散了"，用 [code]despawn_clear()[/code]。
func despawn() -> BulletLifecycle:
	_on_end.append({&"op": A_DESPAWN})
	return self


## 播一次「消弹消散」特效（宿主的 [code]play_clear_fx[/code]：位置 = 弹此刻位置，颜色 = 该弹当前色提亮 1.5×）。
## 纯 action：不改变任何状态 —— 弹继续飞。要"消散并消失"用 [code]despawn_clear()[/code]。
func clear_fx() -> BulletLifecycle:
	_on_end.append({&"op": A_CLEAR_FX})
	return self


## 消散特效 + 回收自己（= [code]clear_fx().despawn()[/code]）。
## 用于显式想让人看见"这颗弹消失了"的场合（时间到 / 主动湮灭）。
## 别把普通 [code]despawn()[/code] 一律换成它：[code]bounce[/code]/[code]radial_accel[/code] 在撞墙时回收、
## [code]avoid_player[/code] 相位2 在屏外回收 —— 那些地方播消散 = 屏外闪光 + 特效风暴。
func despawn_clear() -> BulletLifecycle:
	return clear_fx().despawn()

## 转向（保持速度大小）—— avoid / non_mid 的「逃离自机」。
func on_end_heading(dir: Variant) -> BulletLifecycle:
	var spec := DIR_SPEC.from_variant(dir)
	if spec.eval_phase == DIR_SPEC.EvalPhase.WORLD and not spec.allow_world:
		push_error("BulletLifecycle.on_end_heading(): world angle 请用 world_heading()")
	_on_end.append({&"op": A_SET_HEADING, &"dir": spec})
	return self

## 低频内容回调（逃逸口）：fn.call(pos, boss_pos, has_boss, host)。
## 契约：每相位结束最多一次、宿主侧执行、非热路径；host 只暴露 [code]queue_spawn[/code]。
## 用了它，描述符就不再是唯一行为来源 —— 仅在「一次性散圈 / 难度分支」等极少数场合用。
## hook = StringName（推荐：注册表解析，可序列化、跨实例共用 program；需先 LIFECYCLE_HOOKS_SCRIPT.register）
## 或 Callable（旧写法 / oracle）。未注册的名字静默不调。
func on_end_call(hook: Variant) -> BulletLifecycle:
	_on_end.append({&"op": A_CALL, &"call": hook})
	return self


## 失效锚点告警去重（id -> true）：只报一次，避免每帧每弹刷屏。
static var _anchor_warned_ids: Dictionary = {}


## 锚点解析（唯一真相；原生/参考解释器/测试都走它）：
## - [code]anchor_id=0[/code] → player + offset
## - [code]use_global=true[/code] → 锚点 global_position + offset（marisa 子机是 World 兄弟）
## - [code]use_global=false[/code] → player + 锚点局部 position（focus 子机是 player 子节点；不读 global，父级移动后 global 会滞后一帧）
## - 失效锚点（已释放 / 不是 Node2D）→ 响亮告警一次再退回自机。
static func anchor_base(anchor_id: int, offset: Vector2, use_global: bool, player: Vector2) -> Vector2:
	if anchor_id != 0:
		var node: Object = instance_from_id(anchor_id)
		if node is Node2D:
			if use_global:
				return (node as Node2D).global_position + offset
			return player + (node as Node2D).position
		if not _anchor_warned_ids.has(anchor_id):
			_anchor_warned_ids[anchor_id] = true
			push_error("BulletLifecycle.anchor_base(): 锚点 id=%d 已失效/不是 Node2D，退回自机（激光会贴到自机）" % anchor_id)
	return player + offset


# ═══ 编译 / 签名（实现拆在 LifecycleCompiler + LifecycleHostTable）═══

## 纯 program：ops/args/phase 索引，不含任何宿主模板 / Callable / 音效对象。
func compile_program() -> Dictionary:
	var c: Dictionary = COMPILER.compile_program(self)
	if not _warned_never and not bool(c.get(&"compile_failed", false)):
		_warned_never = true
		_warn_unreachable_phases()
	return c


## 宿主表：spawn / Callable / sfx，和纯 program 分开。
func host_table() -> Dictionary:
	return HOST_TABLE.build(self)


## 兼容入口：纯 program + 宿主表合并（现有测试/参考解释器/旧调用点继续可用）。
func compile() -> Dictionary:
	var c := compile_program()
	var h := host_table()
	c[&"actions"] = h[&"actions"]
	c[&"sfx"] = h[&"sfx"]
	c[&"speed_specs"] = h[&"speed_specs"]
	return c


## 内容签名 = 纯 program 结构 + 宿主表身份。宿主模板不同必须分开（动作表按 program 存）。
func content_signature() -> int:
	if _content_sig != 0:
		return _content_sig
	var h: int = COMPILER.program_signature(compile_program())
	h = h * 31 + HOST_TABLE.signature(host_table())
	_content_sig = h if h != 0 else 1
	return _content_sig


## never 相位上的 on_end 是死代码；非最后相位的 never 会让下一相位永远进不去。
func _warn_unreachable_phases() -> void:
	for i in phases.size():
		var phase: Dictionary = phases[i]
		if phase[&"until"][&"op"] != C_NEVER:
			continue
		var acts: Array = phase[&"on_end"]
		if i < phases.size() - 1:
			push_warning("BulletLifecycle: 相位 %d 的 until=never，下一相位永远不会进入" % (i + 1))
		elif not acts.is_empty():
			var has_despawn := false
			var has_emit := false
			for action in acts:
				var op: StringName = action[&"op"]
				if op == A_DESPAWN or op == A_CLEAR_FX:
					has_despawn = true
				elif op == A_EMIT or op == A_EMIT_VARIANT:
					has_emit = true
			push_warning("BulletLifecycle: 最后相位 until=never，on_end 的 %d 个 action 永远不会执行（despawn=%s / emit=%s）" % [acts.size(), str(has_despawn), str(has_emit)])
