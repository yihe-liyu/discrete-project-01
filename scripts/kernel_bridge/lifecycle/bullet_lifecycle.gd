## BulletLifecycle —— per-bullet 生命周期的**固定 schema 描述符** + fluent builder。
##
## 模型（完整参考见 docs/DANMAKU_API.md §3）：
##   BulletLifecycle = [Phase, Phase, ...]        有序，不可跳转
##   Phase = { moves: [Move...], until: Until, on_end: [Action...] }
##   每帧按顺序跑 moves；until 成立 → 执行 on_end → 进下一相位；then() 开新相位。
##   最后一个相位结束后：弹不再受 program 驱动，按当前速度自由积分（出界由 cull 回收）。
##
## 用法：
##   var lc := BulletLifecycle.new()
##   lc.accel_heading(-150.0).until_elapsed(2.0).sfx(&"kira").despawn()
##   bullet_data.trajectory(lc)
##
## 设计要点：
##   ① 状态显式化：有状态 unit 自带槽（rotate→turned / anchor_drift→drift / drift→起点+位移），
##      builder 自动分配、相位切换清零 → 各 unit 的槽互不污染；`steer` 读相位 elapsed（不占槽）。
##      **例外**：写位置的 unit（anchor_drift / drift）会互相覆盖位置、并覆盖速度积分结果，
##      同相位不可叠加（见 docs/DANMAKU_API.md §9.13）。
##   ② unit 正交化：aim→steer(toward())；anchor+drift→anchor_drift；top_edge→at_wall；
##      near_player/near_boss→near(target)；emit 收方向表达式。
##   ③ 朝向与速度解耦：heading（朝向）出生取初速，rotate/set_heading 更新；
##      accel_heading / forward / random_dir / chance_toward 读它 → 速度反向后仍正确。
##
## 编译：compile() → packed program（原生 DanmakuStore 执行）；content_signature() 做结构去重。
## 创作者只调高层方法，看不到槽 / opcode。
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
const T_PLAYER := COMPILER.T_PLAYER
const T_NEAREST_ENEMY := COMPILER.T_NEAREST_ENEMY
const T_BOSS := COMPILER.T_BOSS
const WALL_LEFT := COMPILER.WALL_LEFT
const WALL_RIGHT := COMPILER.WALL_RIGHT
const WALL_TOP := COMPILER.WALL_TOP
const CMP_GE := COMPILER.CMP_GE
const CMP_LE := COMPILER.CMP_LE
const AT_CURRENT := COMPILER.AT_CURRENT
const AT_PHASE_END := COMPILER.AT_PHASE_END
const ROT_BOTH := COMPILER.ROT_BOTH
const ROT_VELOCITY := COMPILER.ROT_VELOCITY
const ROT_HEADING := COMPILER.ROT_HEADING

# ---- 原生参数（公共兼容别名；opcode 内部常量在 LifecycleCompiler）----
const ARGS := COMPILER.ARGS
const MAX_SLOTS := COMPILER.MAX_SLOTS

# ---- 方向 kind（定义在 DirSpec）----
const D_HEADING := DIR_SPEC.HEADING
const D_TOWARD := DIR_SPEC.TOWARD
const D_AWAY := DIR_SPEC.AWAY
const D_FORWARD := DIR_SPEC.FORWARD
const D_RANDOM := DIR_SPEC.RANDOM
const D_CHANCE := DIR_SPEC.CHANCE
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
	# V6 节流是相位级横切属性：`.every()` / `.every_ticks()` 可能写在 until_* 之前，
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

static func heading(angle: float) -> Dictionary:
	return DIR_SPEC.heading(angle)


static func toward(target: StringName, angle: float = 0.0) -> Dictionary:
	return DIR_SPEC.toward(target, angle)


static func away(target: StringName, angle: float = 0.0) -> Dictionary:
	return DIR_SPEC.away(target, angle)


static func forward(angle: float = 0.0) -> Dictionary:
	return DIR_SPEC.forward(angle)


static func random_dir(spread: float) -> Dictionary:
	return DIR_SPEC.random_dir(spread)


static func chance_toward(target: StringName, p: float, spread: float = 0.0) -> Dictionary:
	return DIR_SPEC.chance_toward(target, p, spread)


static func reflect(angle: float = 0.0) -> Dictionary:
	return DIR_SPEC.reflect(angle)


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

## 角速度 w（弧度/秒），**同时**转速度与朝向；limit > 0 时累计转角钳到 limit（自带槽）。
func rotate(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_BOTH)

## 只转**速度**（朝向不变，V12）。
func rotate_velocity(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_VELOCITY)

## 只转**朝向**（速度不变，V12）。
func rotate_heading(w: float, limit: float = 0.0) -> BulletLifecycle:
	return _add_rotate(w, limit, ROT_HEADING)

func _add_rotate(w: float, limit: float, mode: int) -> BulletLifecycle:
	var s := _alloc()
	_last_turn_slot = s
	_last_turn_limit = limit
	_moves.append({&"op": M_ROTATE, &"w": w, &"limit": limit, &"slot": s, &"mode": mode})
	return self

## 朝 target 转向（**只转向、不改速度**）。ramp 秒内爬满转向权；dist_weight > 0 时近距离转得更快；
## steer_until > 0 时只在前 N 秒转。变速是独立轴：需要时另加 speed_lerp / set_speed。
func steer(target: StringName, max_turn_per_sec: float, ramp: float = 0.0, dist_weight: float = 0.0, steer_until: float = 0.0) -> BulletLifecycle:
	_moves.append({&"op": M_STEER, &"target": target, &"max_turn": max_turn_per_sec, &"ramp": ramp, &"dist_weight": dist_weight, &"steer_until": steer_until})
	return self

## 方向不变，速度按 elapsed/ramp 从 from_speed 线性插值到 to_speed。
func speed_lerp(from_speed: float, to_speed: float, ramp: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_LERP, &"from": from_speed, &"to": to_speed, &"ramp": ramp})
	return self

## 每帧把速度乘 f（**复利/指数算子**，不是瞬时设定）。线性变速用 speed_lerp，瞬时设定用 set_speed。
func speed_mul(f: float) -> BulletLifecycle:
	_moves.append({&"op": M_SPEED_MUL, &"f": f})
	return self

## 设速度方向（保持速度大小）**并同步朝向**。
func set_heading(dir: Dictionary) -> BulletLifecycle:
	_moves.append({&"op": M_SET_HEADING, &"dir": dir})
	return self

## 设速度大小（方向不变）。
func set_speed(speed: float) -> BulletLifecycle:
	_moves.append({&"op": M_SET_SPEED, &"speed": speed})
	return self

## V18：编译为统一 `M_POSITION`（mode=POS_PHASE_START）。
## 从**相位起点**沿 dir(angle) 匀速平移：pos = 相位起点 + dir(angle) * 累计位移。
## 与 anchor_drift 的区别：**不锚定任何外部对象**，基准就是本相位开始时自己的位置；同样不改速度/朝向。
## **⚠ 位置写入原语**：直接写 pos、覆盖积分；与 anchor_drift / 速度原语同相位会互相覆盖（DANMAKU_API §9.13）。
## 典型：整圈弹幕先「整体沿一个方向平移」一段距离（速度/朝向保留），平移结束后各自按出生方向飞出。
func drift(angle: float, speed: float, initial: float = 0.0) -> BulletLifecycle:
	var sx := _alloc()
	var sy := _alloc()
	var sd := _alloc()
	_moves.append({&"op": M_POSITION, &"mode": POS_PHASE_START, &"angle": angle, &"speed": speed, &"sx": sx, &"sy": sy, &"initial": initial, &"slot": sd})
	return self


## V18：编译为统一 `M_POSITION`（mode=POS_ANCHOR）。
## 锚定 + 线性漂移（激光段）：pos = anchor_base + dir(angle) * drift。
## drift 首帧 = initial，之后每帧 += speed * dt；render_heading=true 时设置独立渲染朝向（render_rot 通道，不写 velocity）。
## **⚠ 位置写入原语**：直接写 pos、覆盖积分；与 drift / 速度原语同相位会互相覆盖（DANMAKU_API §9.13）。
## **必须在 trajectory(lc, anchor) 里提供锚点 spec**，否则退回 player + offset。
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

## 距 target < r 时结束。节流用链式 `.every(秒)` / `.every_ticks(帧)`（V6：对所有条件通用）。
func until_near(target: StringName, r: float) -> BulletLifecycle:
	_set_until(C_NEAR, {&"target": target, &"r": r})
	return self

## 碰到掩码指定的墙（左 1 / 右 2 / 上 4）时结束。
## 纯谓词：只在越界时把**相位结束落点**写进 Until 输出（不改弹自身位置），供 emit(..., at=AT_PHASE_END) 使用。
func until_at_wall(mask: int) -> BulletLifecycle:
	_set_until(C_AT_WALL, {&"mask": mask})
	return self

## V21：速度大小满足比较时结束（|v| cmp value；cmp = CMP_GE / CMP_LE）。
## 典型：撞墙后 `accel_heading(-b)` 减速，`until_speed(CMP_LE, v_min)` 降到 v_min 即停。
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

# ---- Until 通用修饰（V6：节流是相位级横切属性，任何条件都能套）----

## 每 `sec` 秒最多检查一次该相位的 until。
func every(sec: float) -> BulletLifecycle:
	_until[&"every"] = sec
	return self

## 每 `n` 帧最多检查一次该相位的 until。
func every_ticks(n: int) -> BulletLifecycle:
	_until[&"every_ticks"] = n
	return self

## 内部：状态槽条件（slot 对创作者不可见，仅 until_turned 用；V8）。
func _set_state_until(slot: int, cmp: int, value: float) -> void:
	_set_until(C_STATE, {&"slot": slot, &"cmp": cmp, &"value": value})

# ═══ Action（当前相位的 on_end；相位结束时一次性执行）═══

## 播音效。key 见 docs/DANMAKU_API.md §7.2（如 &"kira" / &"shoot"）。
## ⚠️ `db` 默认必须是**总电平**，不能是 0.0 —— `0.0 dB` 是"满音量"，会让这个音比其它响约 15 dB
## （内容里普遍写 `lc.sfx(&"kira")` 不传 db）。
func sfx(key: StringName, db: float = AudioManager.SFX_LEVEL_DB) -> BulletLifecycle:
	_on_end.append({&"op": A_SFX, &"key": key, &"db": db})
	return self

## 相位结束时生成替换弹。
## - spawn：**BulletData**（推荐：可序列化、跨实例共用 program）／Callable()->BulletData（旧写法 / oracle）／Array（见 emit_variant）。
## - speed <= 0 → 继承当前速度大小；> 0 → 用该速度。
## - at = AT_PHASE_END → 用 until(at_wall) 输出的相位结束落点；AT_CURRENT（默认）→ 当前弹位置。
## - 事件回传 (program, local) 给宿主，由宿主实例化模板 —— Callable / BulletData 永不进原生。
func emit(spawn: Variant, dir: Dictionary, speed: float = 0.0, at: int = AT_CURRENT) -> BulletLifecycle:
	_on_end.append({&"op": A_EMIT, &"spawn": spawn, &"dir": dir, &"speed": speed, &"at": at})
	return self

## 变体发射：内核抽一次 RNG 决定分支，宿主按分支号取 spawns 里哪个模板（0=未命中，1=命中）。
## `dir` 必须是 `chance_toward(target, p, spread)`：命中→精确朝 target，未命中→forward 旋转 spread。
## 分支由内核**显式**抽取（V9），不再藏在方向求值里。
func emit_variant(spawns: Array, dir: Dictionary, speed: float = 0.0, at: int = AT_CURRENT) -> BulletLifecycle:
	if dir.get(&"kind", &"") != D_CHANCE:
		push_warning("BulletLifecycle.emit_variant(): dir 应为 chance_toward(...)，已退化为普通 emit")
		return emit(spawns, dir, speed, at)
	_on_end.append({&"op": A_EMIT_VARIANT, &"spawns": spawns, &"chance": dir, &"speed": speed, &"at": at})
	return self

## 回收自己。**静默** —— 不播任何特效（这是默认语义：多数 despawn 发生在屏外或做超时清理）。
## 想让人看见"这颗弹消散了"，用 `despawn_clear()`。
func despawn() -> BulletLifecycle:
	_on_end.append({&"op": A_DESPAWN})
	return self


## 播一次「消弹消散」特效（宿主的 `play_clear_fx`：位置 = 弹此刻位置，颜色 = 该弹当前色提亮 1.5×）。
## **纯 action：不改变任何状态** —— 弹继续飞。要"消散并消失"用 `despawn_clear()`。
func clear_fx() -> BulletLifecycle:
	_on_end.append({&"op": A_CLEAR_FX})
	return self


## 消散特效 + 回收自己（= `clear_fx().despawn()`）。
## 用于**显式**想让人看见"这颗弹消失了"的场合（时间到 / 主动湮灭）。
## ⚠️ 别把普通 `despawn()` 一律换成它：`bounce`/`radial_accel` 在**撞墙时**回收、
## `avoid_player` 相位2 在**屏外**回收 —— 那些地方播消散 = 屏外闪光 + 特效风暴。
func despawn_clear() -> BulletLifecycle:
	return clear_fx().despawn()

## 转向（保持速度大小）—— avoid / non_mid 的「逃离自机」。
func on_end_heading(dir: Dictionary) -> BulletLifecycle:
	_on_end.append({&"op": A_SET_HEADING, &"dir": dir})
	return self

## 低频内容回调（**逃逸口**，V13）：fn.call(pos, boss_pos, has_boss, host)。
## 契约：每相位结束最多一次、宿主侧执行、**非热路径**；host 只暴露 `queue_spawn`。
## 用了它，描述符就不再是唯一行为来源 —— 仅在「一次性散圈 / 难度分支」等极少数场合用。
## hook = **StringName**（推荐：注册表解析，可序列化、跨实例共用 program；需先 LIFECYCLE_HOOKS_SCRIPT.register）
##      或 **Callable**（旧写法 / oracle）。未注册的名字静默不调。
func on_end_call(hook: Variant) -> BulletLifecycle:
	_on_end.append({&"op": A_CALL, &"call": hook})
	return self


## 失效锚点告警去重（id -> true）：只报一次，避免每帧每弹刷屏。
static var _anchor_warned_ids: Dictionary = {}


## 锚点解析（**唯一真相**；原生/参考解释器/测试都走它，避免两套语义漂移）：
##   anchor_id=0       → player + offset
##   use_global=true   → 锚点 global_position + offset（marisa 子机是 World 兄弟）
##   use_global=false  → player + 锚点局部 position（focus 子机是 player 子节点；
##                       **不读 global**，父级移动后 global 会滞后一帧 → 根部多偏 v·dt）
## 失效锚点（节点已释放 / 不是 Node2D）→ **响亮告警一次**再退回自机；别静默把整批激光贴到自机。
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

## 纯 program：ops/args/phase 索引，**不含任何宿主模板 / Callable / 音效对象**。
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
	return c


## 内容签名 = 纯 program 结构 + 宿主表身份。宿主模板不同必须分开（动作表按 program 存）。
func content_signature() -> int:
	if _content_sig != 0:
		return _content_sig
	var h: int = COMPILER.program_signature(compile_program())
	h = h * 31 + HOST_TABLE.signature(host_table())
	_content_sig = h if h != 0 else 1
	return _content_sig


## DSL13：never 相位上的 on_end 是死代码；非最后相位的 never 会让下一相位永远进不去。
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
