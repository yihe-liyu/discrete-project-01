extends GutTest
## K1：内核随机 —— 原生 PRNG 确定性（同种子同结果）+ random_dir / chance_toward。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store(seed_value: int):
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(256, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(-100000.0, 100000.0, -100000.0)
	s.set_seed(seed_value)
	return s


func _reg(store, lc: BulletLifecycle) -> int:
	var c: Dictionary = lc.compile()
	return store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])


## 每帧 set_heading(random_dir(spread))：速度方向随机。跑一帧取速度。
func _one_frame(seed_value: int, player: Vector2 = Vector2.ZERO) -> Vector2:
	var s = _store(seed_value)
	var lc := BulletLifecycle.new()
	lc.set_heading(BulletLifecycle.random_dir(1.0))
	lc.until_never()
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	s.behavior_tick(DT, player, Vector2.ZERO, false, PackedVector2Array())
	return s.get_velocity(id)


func test_same_seed_same_result() -> void:
	if not _available(): pending("无扩展"); return
	assert_true(_one_frame(1234).is_equal_approx(_one_frame(1234)), "同种子应逐位相同")


func test_different_seed_differs() -> void:
	if not _available(): pending("无扩展"); return
	assert_false(_one_frame(1234).is_equal_approx(_one_frame(4321)), "不同种子应不同")


func test_random_dir_stays_within_spread() -> void:
	if not _available(): pending("无扩展"); return
	var base := Vector2(0, -1)
	for k in 32:
		var v: Vector2 = _one_frame(100 + k)
		assert_lt(absf(base.angle_to(v.normalized())), 1.001, "应落在 ±spread 内")


func test_chance_toward_bounds() -> void:
	if not _available(): pending("无扩展"); return
	var player := Vector2(1000.0, 0.0)
	var s = _store(7)
	var lc := BulletLifecycle.new()
	lc.set_heading(BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, 1.0, 0.5))
	lc.until_never()
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	s.behavior_tick(DT, player, Vector2.ZERO, false, PackedVector2Array())
	assert_true(s.get_velocity(id).is_equal_approx(Vector2(100, 0)), "p=1 应朝 player（右）")


## 同一帧两个 random_dir：RNG 是单通道，消耗顺序即语义。
func _two_random_heads(seed_value: int, spread_a: float, spread_b: float) -> Vector2:
	var s = _store(seed_value)
	var lc := BulletLifecycle.new()
	lc.set_heading(BulletLifecycle.random_dir(spread_a))
	lc.set_heading(BulletLifecycle.random_dir(spread_b))
	lc.until_never()
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	return s.get_velocity(id)


func test_multiple_random_dir_order_is_consumption_order() -> void:
	if not _available(): pending("无扩展"); return
	# A：先 spread=0（抽取但不改向），再 spread=1 → 结果由第 2 个 draw 决定。
	# B：反过来 → 结果由第 1 个 draw 决定。同种子下两者不同 = 顺序敏感。
	var a: Vector2 = _two_random_heads(7, 0.0, 1.0)
	var b: Vector2 = _two_random_heads(7, 1.0, 0.0)
	assert_false(a.is_equal_approx(b), "交换两个 random_dir 的顺序应改变结果")
	assert_true(a.is_equal_approx(_two_random_heads(7, 0.0, 1.0)), "同程序同种子应逐位一致")
	pass_test("多 random_dir 消耗顺序敏感")
