extends GutTest
## K2：弹道「朝向」状态化 —— accel_heading 与速度解耦（可减速→反向）+ forward() 方向糖。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(256, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(-100000.0, 100000.0, -100000.0)
	return s


func _reg(store, lc: BulletLifecycle) -> int:
	var c: Dictionary = lc.compile()
	return store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])


func test_forward_is_spawn_direction() -> void:
	if not _available(): pending("无扩展"); return
	var s = _store()
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	assert_true(s.get_forward(id).is_equal_approx(Vector2(0, -1)), "朝向应取自初速方向")


func test_accel_heading_reverses_through_zero() -> void:
	if not _available(): pending("无扩展"); return
	# 沿自身朝向反向加速 → 减速到停 → 继续反向飞回。旧实现用 v.normalized()，v=0 时会冻住。
	var lc := BulletLifecycle.new()
	lc.accel_heading(-400.0)
	lc.until_never()
	var s = _store()
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	for _f in 60:   # 1s：v 应从 -100 线性变到 +300
		s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_gt(s.get_velocity(id).y, 0.0, "1s 后应已反向（速度向下）")
	assert_almost_eq(s.get_velocity(id).y, 300.0, 1.0, "匀加速应为 -100 + 400×1s")


func test_set_heading_forward_uses_own_heading() -> void:
	if not _available(): pending("无扩展"); return
	# forward(PI/2)：沿自身朝向（出生=向上）右转 90° → 速度变向右；朝向同步更新
	var lc := BulletLifecycle.new()
	lc.set_heading(BulletLifecycle.forward(PI / 2.0))
	lc.until_never()
	var s = _store()
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(s.get_velocity(id).is_equal_approx(Vector2(100, 0)), "速度应为自身朝向右转 90°（保持速率）")
	assert_true(s.get_forward(id).is_equal_approx(Vector2(1, 0)), "朝向应同步更新为右")

func test_anchor_drift_preserves_heading_then_forward_scatters() -> void:
	if not _available(): pending("无扩展"); return
	# 「定点扩散」核心：anchor_drift 只写位置、不改朝向 → 平移后 forward() 仍 = 出生角。
	var lc := BulletLifecycle.new()
	lc.anchor_drift(0, Vector2.ZERO, PI, 100.0, true, 0.0, false)   # 向下 100px/s 平移
	lc.until_elapsed(0.5)
	lc.then()
	lc.set_heading(BulletLifecycle.forward(0.0))                    # 回到出生朝向（右）
	lc.until_never()
	var s = _store()
	var pid: int = _reg(s, lc)
	var anchor := Vector2(100, 100)
	var id: int = s.spawn(anchor, Vector2(200, 0), 0, 0, Color.WHITE)   # 初速向右 → 出生朝向 = 右
	s.set_program(id, pid)
	var bases := PackedVector2Array([anchor])
	# 复刻游戏帧序：先 integrate 再 behavior_tick
	for _f in 10:   # 相位1 中途：位置被 anchor_drift 接管（向下），朝向仍为出生方向
		s.integrate(DT)
		s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array(), bases)
	assert_true(s.get_forward(id).is_equal_approx(Vector2(1, 0)), "anchor_drift 不应改朝向")
	assert_gt(s.get_position(id).y, anchor.y + 1.0, "相位1 应沿平移方向向下移动")
	for _f in 40:   # 越过 0.5s → 相位2：沿出生朝向（右）飞出
		s.integrate(DT)
		s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array(), bases)
	assert_true(s.get_velocity(id).is_equal_approx(Vector2(200, 0)), "相位2 速度应为出生朝向 × 原速率")
	assert_gt(s.get_position(id).x, anchor.x + 20.0, "相位2 应沿出生角度向右扩散")
