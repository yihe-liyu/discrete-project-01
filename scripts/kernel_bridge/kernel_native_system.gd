## KernelNativeSystem——把内核积分循环交给原生 integrate_batch（N2.2）。
##
## 归属：**桥接层**（scripts/kernel_bridge），不在 vendor 内核目录内 → 不触发 re-vendor。
## 做法：继承 vendored BulletSystem，只覆写 _physics_process。存储 / 回收 / 全部公开接口
## 仍走内核契约，因此行为 / 碰撞 / 渲染看到的 system 依然是 BulletSystem（零改动）。
##
## 原生无状态：数组按值进出，回收不由原生 swap——原生只回 dead 列表，本类按**同序**重放
## despawn（与内核 swap-with-last 语义逐位一致，parity 测试 test_native_integrate 证明）。
## 未加载扩展时 is_native_ready() = false，调用方退回纯 GDScript BulletSystem。
class_name KernelNativeSystem
extends BulletSystem

var _accel: Object = null
## 诊断计数器：真正走了原生路径的帧数（parity 测试据此证明**没有**悄悄回退）。
var native_frames: int = 0


func _init() -> void:
	super()
	_ensure_native()


## 探测并实例化原生积分加速器（幂等；无扩展则保持 null）。
func _ensure_native() -> void:
	if _accel == null and ClassDB.class_exists("DanmakuStore"):
		_accel = ClassDB.instantiate("DanmakuStore")


## 原生是否可用（false = 应改用 BulletSystem）。
func is_native_ready() -> bool:
	_ensure_native()
	return _accel != null


## 覆写内核积分循环：语义与 BulletSystem._physics_process 1:1，只是把整段循环搬原生。
func _physics_process(delta: float) -> void:
	_ensure_native()
	if _accel == null:
		super(delta)
		return
	_last_delta = delta
	if _active_count == 0:
		return
	# 本帧位置全变 → 碰撞查询前重建网格（与基类同）
	_grid_active = false
	_grid_dirty = true
	var cull := cull_rect
	var res: Dictionary = _accel.integrate_batch(
		_active_count, _positions, _velocities, _life_left, _fx_phase, _timer,
		delta, cull.position, cull.size, cull_margin)
	# 原生数组沿用 SoA 约定 = **容量大小**（≥ 活跃数），故只校验下界，绝不可对比 active_count。
	if not res.has("positions") or (res.positions as PackedVector2Array).size() < _active_count:
		super(delta)   # 原生返回异常：退回 GDScript 内核，不让错误数据进池
		return
	native_frames += 1
	_positions = res.positions
	_velocities = res.velocities
	_life_left = res.life_left
	_fx_phase = res.fx_phase
	_timer = res.timers
	# 回收由内核契约统一执行（同序重放 → 与原生循环内的 swap 逐位一致）
	for id in res.dead:
		despawn(id)
