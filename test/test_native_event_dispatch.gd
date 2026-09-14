extends GutTest
## L3.5-3b 回归：行为事件必须按**事件自己的 program**（`eprog`）派发。
##
## 历史 bug：`res.program`（per-bullet 快照）与宿主 `_program` 成员共享底层缓冲，
## 宿主 despawn 的 swap 写会污染同一调用的快照；事件若用它反查就会派发到错误 program，
## 表现为 sfx 越界 / emit 工厂被当 call 调（`_kernel_on_flee_burst` 参数数错误）。
## 契约：每个事件携带自己的发射 program，且该数组独立于 per-bullet 状态数组。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(64, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(64.0, 832.0, 32.0)
	return s


func _reg(store, lc: BulletLifecycle) -> int:
	var c: Dictionary = lc.compile()
	return store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])


func test_event_program_is_per_event_and_independent() -> void:
	if not _available(): pending("无扩展"); return
	var st = _store()
	var pid_bounce: int = _reg(st, BulletLifecycle.bounce(0.0, 0.3, 0.0, Callable()))
	var pid_accel: int = _reg(st, BulletLifecycle.accel(0.0))
	assert_eq(pid_bounce, 0, "bounce 应为 program 0（有 sfx）")
	assert_eq(pid_accel, 1, "accel 应为 program 1（无 sfx）")
	var pos := PackedVector2Array([Vector2(300, 10), Vector2(500, 500)])
	var vel := PackedVector2Array([Vector2(0, -300), Vector2(0, -10)])
	var life := PackedFloat32Array([100.0, 100.0])
	var fx := PackedFloat32Array([0.0, 0.0])
	var prog := PackedInt32Array([pid_bounce, pid_accel])
	var phase := PackedInt32Array([0, 0])
	var tick := PackedInt32Array([0, 0])
	var elapsed := PackedFloat32Array([0.0, 0.0])
	var slots := PackedFloat32Array()
	slots.resize(16)
	var res: Dictionary = st.behavior_batch(pos.size(), pos, vel, life, fx, prog, phase, tick, elapsed, slots, DT, Vector2.ZERO, Vector2(448, 60), true, PackedVector2Array())
	var kinds: PackedInt32Array = res.kind
	var eprog: PackedInt32Array = res.eprog
	var oprogram: PackedInt32Array = res.oprogram
	var bullet: PackedInt32Array = res.bullet
	assert_true(res.has("eprog"), "eprog 键必须存在")
	assert_true(res.has("oprogram"), "oprogram 键必须存在")
	assert_gt(kinds.size(), 0, "碰框应立即产生事件")
	assert_eq(eprog.size(), kinds.size(), "eprog 必须与事件一一对应")
	for k in kinds.size():
		assert_eq(eprog[k], oprogram[bullet[k]], "事件 program 应等于发射弹的 program")
		assert_eq(eprog[k], st.get_program(bullet[k]), "原生 _program[弹] 应等于事件 program")
		assert_eq(eprog[k], pid_bounce, "本帧事件只应来自 bounce 弹")
	if eprog.size() > 0:
		# 事件 program 独立于 per-bullet 状态缓冲：写 per-bullet 不得污染事件 program。
		var before: int = eprog[0]
		oprogram[bullet[0]] = 999
		assert_eq(eprog[0], before, "eprog 不应被 per-bullet 写污染")
