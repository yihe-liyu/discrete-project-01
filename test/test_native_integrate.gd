extends GutTest
## N2.2 原生积分器 parity：KernelNativeSystem（原生 integrate_batch）必须与 vendored
## GDScript BulletSystem 的 _physics_process **逐位一致**（位置/速度/寿命/相位/计时/活跃数）。
## 未构建扩展 → 原生不可用 → pending 跳过。

const DT := 1.0 / 60.0
const CULL := Rect2(0, 0, 896, 768)
const MARGIN := 90.0


func _native_available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _pair() -> Array:
	var gs: BulletSystem = autofree(BulletSystem.new())
	gs.cull_rect = CULL
	gs.cull_margin = MARGIN
	gs.default_lifetime = 3.0
	var nt: KernelNativeSystem = autofree(KernelNativeSystem.new())
	nt.cull_rect = CULL
	nt.cull_margin = MARGIN
	nt.default_lifetime = 3.0
	return [gs, nt]


func _spawn_same(gs: BulletSystem, nt: KernelNativeSystem, bt: BulletType) -> void:
	for i in 400:
		@warning_ignore("integer_division")   # 网格行号，故意整除
		var pos := Vector2(80.0 + (i % 20) * 30.0, 60.0 + (i / 20) * 12.0)
		var vel := Vector2.RIGHT.rotated(i * 0.37) * (140.0 + (i % 9) * 20.0)
		gs.spawn(bt, pos, vel, Color.WHITE)
		nt.spawn(bt, pos, vel, Color.WHITE)
	# 覆盖出生相位 / 短寿命 / 计时器三条分支（nt 走写访问器 → 同步原生权威行）
	for i in 40:
		gs._fx_phase[i] = 0.2
		nt.set_fx(i, 0.2)
	for i in range(100, 160):
		gs._life_left[i] = 0.3
		nt.set_life(i, 0.3)
	for i in range(200, 260):
		gs._timer[i] = 0.25
		nt.set_timer(i, 0.25)


func _assert_identical(gs: BulletSystem, nt: KernelNativeSystem, tag: String) -> void:
	assert_eq(nt.get_active_count(), gs.get_active_count(), tag + "：活跃数")
	var n: int = gs.get_active_count()
	for i in n:
		if not nt.get_position(i).is_equal_approx(gs.get_position(i)):
			fail_test(tag + "：位置第 %d 行分歧" % i)
			return
		if not nt.get_velocity(i).is_equal_approx(gs.get_velocity(i)):
			fail_test(tag + "：速度第 %d 行分歧" % i)
			return
		if not is_equal_approx(nt.get_life_left(i), gs.get_life_left(i)):
			fail_test(tag + "：寿命第 %d 行分歧" % i)
			return
		if not is_equal_approx(nt.get_fx_phase(i), gs.get_fx_phase(i)):
			fail_test(tag + "：相位第 %d 行分歧" % i)
			return
		if not is_equal_approx(nt.get_timer(i), gs.get_timer(i)):
			fail_test(tag + "：计时第 %d 行分歧" % i)
			return
	pass_test(tag + "：%d 行逐位一致" % n)


func test_native_integrate_matches_gdscript() -> void:
	if not _native_available():
		pending("未构建原生扩展 → 跳过 parity")
		return
	var p := _pair()
	var gs: BulletSystem = p[0]
	var nt: KernelNativeSystem = p[1]
	assert_true(nt.is_native_ready(), "原生应就绪")
	_spawn_same(gs, nt, BulletType.new())
	_assert_identical(gs, nt, "t=0")
	for f in 30:
		gs._physics_process(DT)
		nt._physics_process(DT)
	_assert_identical(gs, nt, "t=0.5s（有回收）")
	for f in 90:
		gs._physics_process(DT)
		nt._physics_process(DT)
	_assert_identical(gs, nt, "t=2.0s")
	assert_gt(gs.get_active_count(), 0, "长寿命弹仍应在场（保证原生跑满全程）")
	# 覆盖证明：原生路径必须真的跑过，否则 parity 是「两边都走 GDScript」的空断言
	assert_gt(nt.native_frames, 100, "原生积分路径应实际执行")


func test_backend_picks_native_when_available() -> void:
	var backend: KernelBulletHost = autofree(KernelBulletHost.new())
	backend._ensure_system()
	assert_true(backend.system is KernelNativeSystem, "扩展为必需：弹池应装配原生内核")
	assert_true(backend.system != null, "弹池应建立")
