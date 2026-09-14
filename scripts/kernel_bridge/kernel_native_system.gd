## KernelNativeSystem —— 原生积分 + 原生行为执行（N2.2 + L3.5-3b）。
##
## 归属：**桥接层**，继承 vendored BulletSystem，只覆写存储 / 积分 / 行为钩子。
## 接入：KernelBulletBackend 在原生可用时用它，并**不再创建 BehaviorProcessor** ——
## 行为由原生 behavior_batch 执行（描述符经 LifecycleCatalog + compile 注册成 program）。
## 未加载扩展时 is_native_ready() = false，调用方退回纯 GDScript 内核。
class_name KernelNativeSystem
extends BulletSystem

const SLOT_STRIDE := 8

var _accel: Object = null
## 诊断计数器：真正走了原生积分路径的帧数。
var native_frames: int = 0

# ── 原生行为执行（由 KernelBulletBackend 装配）──
var native_behaviors: bool = false
var behavior_ctx: BehaviorContext
var behavior_host          # KernelBehaviorHost
var boss_getter: Callable

var _program := PackedInt32Array()
var _pphase := PackedInt32Array()
var _ptick := PackedInt32Array()
var _pelapsed := PackedFloat32Array()
var _pslots := PackedFloat32Array()
var _catalog := LifecycleCatalog.new()
var _program_data: Array = []
var _sig_to_program: Dictionary = {}


func _init() -> void:
	super()
	_ensure_native()


func _ensure_native() -> void:
	if _accel == null and ClassDB.class_exists("DanmakuStore"):
		_accel = ClassDB.instantiate("DanmakuStore")
		# 原生侧不知宿主场域常量：注入（at_wall 判定用）。
		_accel.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)


func is_native_ready() -> bool:
	_ensure_native()
	return _accel != null


## 容量变化时同步桥接侧的行为数组（基类会 resize 自己的 SoA）。
func _ensure_capacity(capacity: int) -> void:
	super(capacity)
	var cap: int = _positions.size()
	if _program.size() < cap:
		_program.resize(cap)
		_pphase.resize(cap)
		_ptick.resize(cap)
		_pelapsed.resize(cap)
		_pslots.resize(cap * SLOT_STRIDE)


## 发射：基类写入 GDScript 存储；这里再绑定原生 program。
func spawn(bullet_data: BulletType, position: Vector2, velocity: Vector2, color: Color = Color.WHITE, move: StringName = &"", behavior_params: Variant = null) -> int:
	var id: int = super(bullet_data, position, velocity, color, move, behavior_params)
	var params: Dictionary = behavior_params if behavior_params is Dictionary else {}
	var prog: int = _program_for(move, params) if native_behaviors else -1
	_program[id] = prog
	_pphase[id] = 0
	_ptick[id] = 0
	_pelapsed[id] = 0.0
	for s in SLOT_STRIDE:
		_pslots[id * SLOT_STRIDE + s] = 0.0
	return id


## 回收：镜像基类的 swap-with-last（尾行搬进空槽）。
func despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	var tail: int = _active_count - 1
	super(id)
	if id != tail:
		_program[id] = _program[tail]
		_pphase[id] = _pphase[tail]
		_ptick[id] = _ptick[tail]
		_pelapsed[id] = _pelapsed[tail]
		for s in SLOT_STRIDE:
			_pslots[id * SLOT_STRIDE + s] = _pslots[tail * SLOT_STRIDE + s]


## move+params → 原生 program（编译 + 注册，按签名缓存）。
func _program_for(move: StringName, params: Dictionary) -> int:
	if _accel == null:
		return -1
	var sig: int = LifecycleCatalog.signature(move, params)
	if _sig_to_program.has(sig):
		return _sig_to_program[sig]
	var lc: BulletLifecycle = _catalog.get_lifecycle(move, params)
	var pid: int = -1
	if lc != null:
		var c: Dictionary = lc.compile()
		var expected: int = _program_data.size()
		pid = _accel.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
		if pid != expected:
			push_error("[KernelNativeSystem] program 对齐失败：native pid=%d, 期望 %d" % [pid, expected])
		_program_data.append(c)
	_sig_to_program[sig] = pid
	return pid


## 覆写：原生积分（integrate_batch）+ 原生行为（behavior_batch）。
func _physics_process(delta: float) -> void:
	_ensure_native()
	if _accel == null:
		super(delta)
		return
	_last_delta = delta
	if _active_count == 0:
		return
	_grid_active = false
	_grid_dirty = true
	var cull := cull_rect
	var res: Dictionary = _accel.integrate_batch(
		_active_count, _positions, _velocities, _life_left, _fx_phase, _timer,
		delta, cull.position, cull.size, cull_margin)
	if not res.has("positions") or (res.positions as PackedVector2Array).size() < _active_count:
		super(delta)
		return
	native_frames += 1
	_positions = res.positions
	_velocities = res.velocities
	_life_left = res.life_left
	_fx_phase = res.fx_phase
	_timer = res.timers
	for id in res.dead:
		despawn(id)
	if native_behaviors:
		_run_native_behaviors(delta)


func _run_native_behaviors(delta: float) -> void:
	if _active_count == 0:
		return
	var player := Vector2.ZERO
	var enemies := PackedVector2Array()
	if behavior_ctx != null:
		player = behavior_ctx.get_player_position()
		for e in behavior_ctx.get_world().get_enemies():
			enemies.append(e.global_position)
	var boss = boss_getter.call() if boss_getter.is_valid() else null
	var has_boss: bool = is_instance_valid(boss)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	var res: Dictionary = _accel.behavior_batch(
		_active_count, _positions, _velocities, _life_left, _fx_phase,
		_program, _pphase, _ptick, _pelapsed, _pslots,
		delta, player, boss_pos, has_boss, enemies)
	_positions = res.positions
	_velocities = res.velocities
	_life_left = res.life
	_fx_phase = res.fx
	_program = res.oprogram
	_pphase = res.phase
	_ptick = res.tick
	_pelapsed = res.elapsed
	_pslots = res.slots
	var ids: Array = []
	for id in res.dead:
		ids.append(id)
	ids.sort()
	ids.reverse()
	for id in ids:
		despawn(id)
	_drain_events(res, has_boss, boss_pos)


func _drain_events(res: Dictionary, has_boss: bool, boss_pos: Vector2) -> void:
	var kinds: PackedInt32Array = res.kind
	if kinds.is_empty():
		return
	var local: PackedInt32Array = res.local
	var xs: PackedFloat32Array = res.x
	var ys: PackedFloat32Array = res.y
	var dxs: PackedFloat32Array = res.dx
	var dys: PackedFloat32Array = res.dy
	var vals: PackedFloat32Array = res.val
	# 事件携带自己的 program（eprog）；**不能**用 per-bullet program 去反查 ——
	# 两者在本调用内不一致会静默错派（历史 bug，见 BEST_PRACTICES_LOG）。
	var eprog: PackedInt32Array = res.eprog
	for k in kinds.size():
		var prog: int = eprog[k]
		if prog < 0 or prog >= _program_data.size():
			continue
		var c: Dictionary = _program_data[prog]
		match kinds[k]:
			0:
				var factory: Callable = c["actions"][local[k]]
				var b = factory.call()
				if b != null and behavior_host != null:
					b.velocity = Vector2(0.0, vals[k])
					behavior_host.queue_spawn(b, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]))
			1:
				var key: StringName = c["sfx"][local[k]]
				var stream = AssetRegistry.sounds.get(String(key), null)
				if stream != null:
					AudioManager.play_sfx(stream, vals[k])
			2:
				(c["actions"][local[k]] as Callable).call(Vector2(xs[k], ys[k]), boss_pos, has_boss, behavior_host)