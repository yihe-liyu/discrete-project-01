extends GutTest
## N2 存储段：原生 DanmakuStore 的存储 / 积分 / 回收语义与 GDScript BulletSystem 1:1。

const DT := 1.0 / 60.0
const CULL := Rect2(0.0, 0.0, 896.0, 768.0)
const MARGIN := 90.0


func _gs() -> BulletSystem:
	var s: BulletSystem = autofree(BulletSystem.new())
	s.cull_rect = CULL
	s.cull_margin = MARGIN
	s.default_lifetime = 2.5
	return s


func _nat():
	if not ClassDB.class_exists("DanmakuStore"):
		return null
	var n = ClassDB.instantiate("DanmakuStore")
	n.setup(1024, CULL)
	n.set_margin(MARGIN)
	n.set_default_life(2.5)
	return n


func _cmp(gs: BulletSystem, n, tag: String) -> String:
	var count: int = gs.get_active_count()
	if count != n.get_active_count():
		return tag + " 活跃数 %d vs %d" % [count, n.get_active_count()]
	for i in count:
		if not gs.get_position(i).is_equal_approx(n.get_position(i)):
			return tag + " 位置行 %d" % i
		if not gs.get_velocity(i).is_equal_approx(n.get_velocity(i)):
			return tag + " 速度行 %d" % i
		if not is_equal_approx(gs.get_life_left(i), n.get_life_left(i)):
			return tag + " 寿命行 %d" % i
		if not is_equal_approx(gs.get_fx_phase(i), n.get_fx_phase(i)):
			return tag + " 相位行 %d" % i
		if not is_equal_approx(gs.get_timer(i), n.get_timer(i)):
			return tag + " 计时行 %d" % i
	return ""


func test_native_storage_matches_gdscript() -> void:
	var n = _nat()
	if n == null:
		pending("未构建原生扩展")
		return
	var gs := _gs()
	var bt := BulletType.new()
	var rows := 100
	for i in rows:
		var pos := Vector2(80.0 + (i % 20) * 30.0, 60.0 + (i / 20) * 20.0)
		var vel := Vector2.RIGHT.rotated(i * 0.19) * (150.0 + (i % 7) * 20.0)
		gs.spawn(bt, pos, vel, Color.WHITE)
		n.spawn(pos, vel, i % 4, i % 3, Color.WHITE)
	for i in range(0, 30):
		gs._life_left[i] = 0.5
		n.set_life(i, 0.5)
	for i in range(30, 50):
		gs._fx_phase[i] = 0.3
		n.set_fx(i, 0.3)
	for i in range(50, 70):
		gs._timer[i] = 0.25
		n.set_timer(i, 0.25)

	var frames := 180
	for f in frames:
		gs._physics_process(DT)
		n.integrate(DT)
		var msg := _cmp(gs, n, "帧 %d" % f)
		if msg != "":
			fail_test(msg)
			return
	pass_test("原生存储 %d 弹 × %d 帧与 GDScript 逐位一致" % [rows, frames])


func test_native_despawn_swap_parity() -> void:
	var n = _nat()
	if n == null:
		pending("未构建原生扩展")
		return
	var gs := _gs()
	var bt := BulletType.new()
	for i in 8:
		gs.spawn(bt, Vector2(i, 0.0), Vector2.ZERO, Color.WHITE)
		n.spawn(Vector2(i, 0.0), Vector2.ZERO, 0, 0, Color.WHITE)
	gs.despawn(3)
	n.despawn(3)
	assert_eq(n.get_active_count(), gs.get_active_count(), "despawn 后活跃数")
	for i in gs.get_active_count():
		assert_true(n.get_position(i).is_equal_approx(gs.get_position(i)), "swap 后行 %d" % i)
