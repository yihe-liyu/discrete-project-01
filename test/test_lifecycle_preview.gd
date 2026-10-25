extends GutTest
## LifecyclePreview：单颗弹当前 phase 的确定性路径。
## 用真实原生 store 逐帧对照位置，锁住“预览不是另一套物理”。

const PREVIEW := preload("res://scripts/telegraph/lifecycle_preview.gd")
const DT := 1.0 / 60.0


func _native(lifecycle: BulletLifecycle, position: Vector2, velocity: Vector2) -> KernelNativeSystem:
	var sys := KernelNativeSystem.new()
	add_child_autofree(sys)
	sys.set_physics_process(false)   # 测试手动逐帧推，避免引擎再推一次
	sys.cull_rect = Rect2(-10000.0, -10000.0, 20000.0, 20000.0)
	sys.default_lifetime = 100.0
	sys.enable_native_behaviors = true
	var bullet_type := BulletType.new()
	bullet_type.is_spawn_fog = false
	sys.spawn(bullet_type, position, velocity, Color.WHITE,
		LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lifecycle})
	return sys


func _native_points(sys: KernelNativeSystem, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array([sys.get_position(0)])
	for _i in steps:
		sys.step(DT)
		if sys.get_active_count() == 0:
			break
		points.append(sys.get_position(0))
	return points


func _preview(lifecycle: BulletLifecycle, position: Vector2, velocity: Vector2,
		max_time: float = 1.0) -> Dictionary:
	return PREVIEW.evaluate_phase(
		lifecycle, 0, position, velocity, velocity.normalized(),
		DT, max_time, Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
			GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP))


func _assert_matches_native(lifecycle: BulletLifecycle, position: Vector2,
		velocity: Vector2, max_time: float = 1.0) -> void:
	var sys := _native(lifecycle, position, velocity)
	var native := _native_points(sys, ceili(max_time / DT) + 1)
	var preview := _preview(lifecycle, position, velocity, max_time)
	assert_true(preview.ok, "确定性 phase 应能预览")
	if not preview.ok:
		return
	var points: PackedVector2Array = preview.points
	assert_true(native.size() >= points.size(), "原生至少覆盖预览到的帧")
	for i in mini(points.size(), native.size()):
		assert_almost_eq(points[i].x, native[i].x, 0.01, "第 %d 帧 x 应与原生一致" % i)
		assert_almost_eq(points[i].y, native[i].y, 0.01, "第 %d 帧 y 应与原生一致" % i)


func test_preview_matches_native_world_accel() -> void:
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0.0, 240.0)).until_elapsed(0.5)
	_assert_matches_native(lc, Vector2(400.0, 200.0), Vector2(0.0, -100.0), 0.5)


func test_preview_matches_native_heading_accel() -> void:
	var lc := BulletLifecycle.new()
	lc.accel_heading(300.0).until_elapsed(0.4)
	_assert_matches_native(lc, Vector2(400.0, 300.0), Vector2(0.0, -120.0), 0.4)


func test_preview_matches_native_rotate_until_turned() -> void:
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.5).until_turned()
	_assert_matches_native(lc, Vector2(400.0, 300.0), Vector2(0.0, -120.0), 1.0)


func test_preview_matches_native_speed_lerp() -> void:
	var lc := BulletLifecycle.new()
	lc.speed_lerp(100.0, 400.0, 0.5).until_elapsed(0.25)
	_assert_matches_native(lc, Vector2(400.0, 300.0), Vector2(0.0, -100.0), 0.25)


func test_preview_stops_at_wall() -> void:
	var lc := BulletLifecycle.new()
	lc.until_at_wall(BulletLifecycle.WALL_RIGHT)
	var start := Vector2(GameConfig.FIELD_RIGHT - 2.0, 300.0)
	var sys := _native(lc, start, Vector2(120.0, 0.0))
	var native := _native_points(sys, 5)
	var preview := _preview(lc, start, Vector2(120.0, 0.0), 0.2)
	assert_true(preview.ok, "at_wall 应能预览")
	assert_eq(preview.reason, &"wall", "应停在右墙")
	assert_true(native.size() >= preview.points.size(), "原生至少覆盖预览到的帧")
	if preview.ok and not preview.points.is_empty():
		assert_almost_eq(preview.points[-1].x, native[preview.points.size() - 1].x, 0.01, "墙边落点应一致")


func test_preview_ignores_target_dependent_steer() -> void:
	var lc := BulletLifecycle.new()
	lc.steer(BulletLifecycle.T_PLAYER, 2.0).until_elapsed(0.5)
	var preview := _preview(lc, Vector2(400.0, 300.0), Vector2(0.0, -100.0), 0.5)
	assert_false(preview.ok, "steer 含目标依赖，不能声称精确")
	assert_true(preview.approximate, "应标记为近似")
	assert_gt(preview.points.size(), 1, "忽略瞄准后仍应画到 phase 上限")


func test_preview_marks_target_until_as_approximate() -> void:
	var lc := BulletLifecycle.new()
	lc.until_near(BulletLifecycle.T_PLAYER, 100.0).despawn()
	var preview := _preview(lc, Vector2(400.0, 300.0), Vector2(0.0, -100.0), 0.3)
	assert_false(preview.ok, "until_near 的终点依赖目标，不算精确")
	assert_true(preview.approximate, "应标记为近似")
	assert_eq(preview.reason, &"target_until", "应说明停在目标相关条件")
	assert_gt(preview.points.size(), 1, "仍可画到时间上限")


func test_phase_returns_end_state() -> void:
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0.0, 240.0)).until_elapsed(0.5)
	var preview := _preview(lc, Vector2(400.0, 200.0), Vector2(0.0, -100.0), 0.5)
	assert_true(preview.ok)
	var end_state: Dictionary = preview.end_state
	assert_almost_eq(Vector2(end_state.position).x, preview.points[-1].x, 0.01, "结束位置应与最后一点一致")
	assert_almost_eq(float(end_state.elapsed), 0.5, 0.001, "结束时间应为 phase 时长")


func test_chain_continues_to_next_phase() -> void:
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0.0, 240.0)).until_elapsed(0.25)
	lc.then()
	lc.accel_heading(300.0).until_elapsed(0.25).despawn()
	var chain := PREVIEW.evaluate_chain(
		lc, 0, Vector2(400.0, 200.0), Vector2(0.0, -100.0),
		Vector2.UP, DT, 0.6)
	assert_true(chain.ok, "两段都是确定性 phase")
	assert_eq(chain.segments.size(), 2, "应有两段")
	assert_eq(chain.reason, &"despawn", "第二段 despawn 后停止")
	var total := float(chain.end_state.elapsed)
	assert_gt(total, 0.5, "总时长应覆盖两段")
	assert_lt(total, 0.6, "不应超过两段 + 一帧")


func test_chain_applies_static_on_end_heading() -> void:
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.1).on_end_heading(BulletLifecycle.world_heading(PI / 2.0))
	lc.then()
	lc.until_elapsed(0.1)
	var chain := PREVIEW.evaluate_chain(
		lc, 0, Vector2(400.0, 300.0), Vector2(0.0, -100.0),
		Vector2.UP, DT, 0.2)
	assert_true(chain.ok)
	assert_eq(chain.segments.size(), 2, "on_end 后应继续第二段")
	assert_gt(Vector2(chain.end_state.velocity).x, 0.0, "第二段应朝右")
