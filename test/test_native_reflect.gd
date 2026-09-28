extends GutTest
## `reflect()`（镜面方向，dk = 6）：撞墙后发射的替换弹方向 = **入射速度**按场边翻分量。
##
## 原生专属用例（**不走 parity**）：`test/reference/**` 是冻结 vendor 的参考解释器，
## 不实现新原语；parity 只覆盖两者都有的旧词汇。新原语由本文件直接对内核断言。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
const FIELD_LEFT := 64.0
const FIELD_RIGHT := 832.0
const FIELD_TOP := 32.0
const EPS := 1e-3


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(64, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(FIELD_LEFT, FIELD_RIGHT, FIELD_TOP)
	return s


func _reg(store, lc: BulletLifecycle) -> int:
	var c: Dictionary = lc.compile()
	return store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"],
		c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])


## 撞墙 → 发射替换弹（方向 = reflect([angle])）
func _mirror_lifecycle(mask: int, angle: float = 0.0) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.until_at_wall(mask)
	lc.emit(Callable(), BulletLifecycle.reflect(angle), 100.0, BulletLifecycle.AT_PHASE_END)
	lc.despawn()
	return lc


## 跑到第一次 emit 事件，返回 {dir, pos}；没等到返回空字典。
func _first_emit(store, lc: BulletLifecycle, start: Vector2, vel: Vector2, frames := 300) -> Dictionary:
	var pid := _reg(store, lc)
	var id: int = store.spawn(start, vel, 0, 0, Color.WHITE)
	store.set_program(id, pid)
	for _f in frames:
		store.integrate(DT)
		var ev: Dictionary = store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false,
			PackedVector2Array(), PackedVector2Array())
		var kinds: PackedInt32Array = ev["kind"]
		for k in kinds.size():
			if int(kinds[k]) == 0:
				return {&"dir": Vector2(ev["dx"][k], ev["dy"][k]), &"pos": Vector2(ev["x"][k], ev["y"][k])}
	return {}


func _close(a: Vector2, b: Vector2) -> bool:
	return (a - b).length() <= EPS


## 右墙：入射右下 (1,1) → 镜面应为左下 (-1,1)/√2
func test_reflect_right_wall_flips_x():
	if not _available(): pending("无扩展"); return
	var ev := _first_emit(_store(), _mirror_lifecycle(BulletLifecycle.WALL_RIGHT),
		Vector2(800.0, 300.0), Vector2(200.0, 200.0))
	assert_false(ev.is_empty(), "应撞到右墙并发射一次")
	if ev.is_empty(): return
	assert_almost_eq(ev[&"pos"].x, FIELD_RIGHT, 0.01, "发射点夹在右墙")
	assert_true(_close(ev[&"dir"], Vector2(-1.0, 1.0).normalized()), "方向 = 左下的镜面（实得 %s）" % ev[&"dir"])


## 上墙：入射右上 (1,-1) → 镜面应为右下 (1,1)/√2
func test_reflect_top_wall_flips_y():
	if not _available(): pending("无扩展"); return
	var ev := _first_emit(_store(), _mirror_lifecycle(BulletLifecycle.WALL_TOP),
		Vector2(400.0, 100.0), Vector2(200.0, -200.0))
	assert_false(ev.is_empty(), "应撞到上墙并发射一次")
	if ev.is_empty(): return
	assert_almost_eq(ev[&"pos"].y, FIELD_TOP, 0.01, "发射点夹在上墙")
	assert_true(_close(ev[&"dir"], Vector2(1.0, 1.0).normalized()), "方向 = 右下的镜面（实得 %s）" % ev[&"dir"])


## 角落（一步同时越两条边）：两边都翻 = 原路返回
func test_reflect_corner_reverses_direction():
	if not _available(): pending("无扩展"); return
	var ev := _first_emit(_store(),
		_mirror_lifecycle(BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP),
		Vector2(FIELD_RIGHT - 2.0, FIELD_TOP + 2.0), Vector2(200.0, -200.0))
	assert_false(ev.is_empty(), "应撞到右上角并发射一次")
	if ev.is_empty(): return
	assert_true(_close(ev[&"dir"], Vector2(-1.0, 1.0).normalized()),
		"角落 = x/y 都翻（原路返回，实得 %s）" % ev[&"dir"])


## angle 参数：镜面后再转 angle（做"镜面 + 微散"）；转的是**镜面结果**，不是入射
func test_reflect_angle_offsets_mirror():
	if not _available(): pending("无扩展"); return
	var quarter := PI / 2.0
	var ev := _first_emit(_store(), _mirror_lifecycle(BulletLifecycle.WALL_RIGHT, quarter),
		Vector2(800.0, 300.0), Vector2(200.0, 200.0))
	assert_false(ev.is_empty(), "应撞到右墙并发射一次")
	if ev.is_empty(): return
	# 右墙镜面 = (-1,1)/√2；再按引擎的 rotated 约定转 90° → (-1,-1)/√2
	var mirrored := Vector2(-1.0, 1.0).normalized()
	assert_true(_close(ev[&"dir"], mirrored.rotated(quarter)),
		"镜面 %s 再转 90° → %s（实得 %s）" % [mirrored, mirrored.rotated(quarter), ev[&"dir"]])
	assert_false(_close(ev[&"dir"], mirrored), "转过的不该等于没转的")


## 没贴场边（AT_CURRENT 且在场内）→ 不翻，退化为自身朝向，不静默乱转向
func test_reflect_outside_wall_falls_back_to_heading():
	if not _available(): pending("无扩展"); return
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.1)
	lc.emit(Callable(), BulletLifecycle.reflect(), 100.0, BulletLifecycle.AT_CURRENT)
	lc.despawn()
	var ev := _first_emit(_store(), lc, Vector2(400.0, 300.0), Vector2(200.0, 200.0))
	assert_false(ev.is_empty(), "0.1 秒后应发射一次")
	if ev.is_empty(): return
	assert_true(_close(ev[&"dir"], Vector2(1.0, 1.0).normalized()),
		"未贴边 → 保持入射方向（实得 %s）" % ev[&"dir"])


## 编译表：reflect 必须编成 dk = 6（与内核 `_resolve_dir` 的编号一致）
func test_reflect_compiles_to_dk_6():
	var lc := _mirror_lifecycle(BulletLifecycle.WALL_RIGHT)
	var c: Dictionary = lc.compile()
	var args: PackedFloat32Array = c["args"]
	var found := false
	for v in args:
		if is_equal_approx(v, 6.0):
			found = true
			break
	assert_true(found, "编译后的参数里应出现 dk = 6（reflect）")
