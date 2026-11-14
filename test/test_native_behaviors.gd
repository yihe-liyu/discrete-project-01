extends GutTest
## Native behavior packs 的逐帧语义：accel_heading lifetime / bounce_emit reflect /
## homing 最近敌人 + 变速 / anchor_drift 锚点跟随。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
const LEFT := 64.0
const RIGHT := 832.0
const TOP := 32.0


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(1024, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(LEFT, RIGHT, TOP)
	return s


func _spawn(store, pos: Vector2, vel: Vector2, behavior: String, params: Array,
		anchor_slot: int = -1) -> int:
	var id: int = store.spawn(pos, vel, 0, 0, Color.WHITE)
	assert_true(store.set_behavior(id, store.get_behavior_id(behavior), PackedFloat32Array(params)),
		"behavior 应绑定：%s" % behavior)
	if anchor_slot >= 0:
		store.set_anchor_slot(id, anchor_slot)
	return id


func _event_index(res: Dictionary, kind: int) -> int:
	var kinds: PackedInt32Array = res.get("kind", PackedInt32Array())
	for i in kinds.size():
		if kinds[i] == kind:
			return i
	return -1


func test_accel_heading_lifetime_despawns_and_clears() -> void:
	if not _available(): pending("无扩展"); return
	var store = _store()
	_spawn(store, Vector2(400, 300), Vector2(0, -120), "accel_heading", [0.0, 0.08, 1.0])
	for i in 4:
		store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_eq(store.get_active_count(), 1, "未到 lifetime 应存活")
	var res: Dictionary = store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_eq(store.get_active_count(), 0, "到 lifetime 应收掉")
	assert_gte(_event_index(res, 3), 0, "despawn_clear 应同时发 clear_fx 事件")


func test_accel_heading_lifetime_zero_never_despawns() -> void:
	if not _available(): pending("无扩展"); return
	var store = _store()
	_spawn(store, Vector2(400, 300), Vector2(0, -120), "accel_heading", [10.0, 0.0, 0.0])
	for i in 180:
		store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_eq(store.get_active_count(), 1, "lifetime=0 不应自动回收")


func test_bounce_emit_reflects_off_walls() -> void:
	if not _available(): pending("无扩展"); return
	# [位置, 速度, 期望 dx 符号（0 = 不变）, 期望 dy 符号]
	var cases := [
		[Vector2(LEFT, 300), Vector2(-100, 0), 1.0, 0.0],
		[Vector2(RIGHT, 300), Vector2(100, 0), -1.0, 0.0],
		[Vector2(400, TOP), Vector2(0, -100), 0.0, 1.0],
		[Vector2(LEFT, TOP), Vector2(-100, -100), 1.0, 1.0],
	]
	for c in cases:
		var store = _store()
		_spawn(store, c[0], c[1], "bounce_emit", [0.0, 100.0, 0.0, 0.0, 1.0, 1.0])
		var res: Dictionary = store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
		var k := _event_index(res, 5)
		assert_gte(k, 0, "撞墙应发 emit 事件")
		if k < 0: continue
		var dx: float = res["dx"][k]
		var dy: float = res["dy"][k]
		if c[2] != 0.0:
			assert_eq(signf(dx), c[2], "左右墙应翻 x：%s" % c[0])
		else:
			assert_almost_eq(dx, 0.0, 0.001, "上墙不应改 x：%s" % c[0])
		if c[3] != 0.0:
			assert_eq(signf(dy), c[3], "上墙应翻 y：%s" % c[0])
		else:
			assert_almost_eq(dy, 0.0, 0.001, "左右墙不应改 y：%s" % c[0])
		assert_eq(store.get_active_count(), 0, "reflect 模式默认撞墙后回收父弹")


func test_homing_nearest_enemy_turns_and_ramps_speed() -> void:
	if not _available(): pending("无扩展"); return
	var store = _store()
	# 子弹向下飞，最近敌人在正上方 → 应掉头向上；速度 500 → 1000（1 秒）。
	_spawn(store, Vector2(400, 300), Vector2(0, 300), "homing",
		[500.0, deg_to_rad(720.0), 1.0, 1000.0, 1.0, 0.0, 0.0, 0.0])
	var enemies := PackedVector2Array([Vector2(400, 100), Vector2(780, 500)])
	for i in 60:
		store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, enemies)
	assert_lt(store.get_velocity(0).y, 0.0, "应转向最近敌人（上方）")
	assert_almost_eq(store.get_velocity(0).length(), 1000.0, 2.0, "1 秒后速度应到 1000")


func test_homing_without_enemy_only_ramps_speed() -> void:
	if not _available(): pending("无扩展"); return
	var store = _store()
	_spawn(store, Vector2(400, 300), Vector2(0, 300), "homing",
		[500.0, deg_to_rad(720.0), 1.0, 1000.0, 1.0, 0.0, 0.0, 0.0])
	for i in 60:
		store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_almost_eq(store.get_velocity(0).x, 0.0, 0.001, "无敌人不应转向")
	assert_almost_eq(store.get_velocity(0).length(), 1000.0, 2.0, "速度插值仍应生效")


func test_anchor_drift_tracks_moving_anchor() -> void:
	if not _available(): pending("无扩展"); return
	var store = _store()
	var speed := 800.0
	var initial := 13.333
	_spawn(store, Vector2.ZERO, Vector2.UP, "anchor_drift", [0.0, speed, initial, 1.0], 0)
	var anchor := Vector2(340, 560)
	store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array(),
		PackedVector2Array(), PackedVector2Array([anchor]))
	assert_almost_eq(store.get_position(0).x, anchor.x, 0.01, "x 应贴锚点")
	assert_almost_eq(store.get_position(0).y, anchor.y - initial, 0.01, "首帧用 initial")
	for i in 3:
		anchor += Vector2(5, 0)
		store.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array(),
			PackedVector2Array(), PackedVector2Array([anchor]))
	assert_almost_eq(store.get_position(0).x, anchor.x, 0.01, "锚点移动后应跟随")
	assert_almost_eq(store.get_position(0).y, anchor.y - initial - speed * DT * 3.0, 0.05,
		"漂移应逐帧累计")
	assert_almost_eq(store.get_render_rot(0), -PI / 2.0, 0.001, "render_heading 应写贴图朝向")
