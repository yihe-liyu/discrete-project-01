extends GutTest
## L3.5-2：LifecycleCatalog —— move+params → BulletLifecycle 的映射与缓存。

func test_build_all_moves() -> void:
	var cases := {
		&"world_accel": {&"world_accel": Vector2(0, 300.0)},
		&"accel": {&"accel": 90.0},
		&"curve": {&"curve": 2.0, &"curve_limit": 1.0},
		&"homing": {&"homing_angle_per_sec": 1.0, &"accel_time": 1.0, &"min_speed": 200.0, &"max_speed": 500.0, &"homing_duration": 2.0, &"proximity_boost": 150.0},
		&"radial_accel": {&"accel_rate": 120.0, &"spawn_factory": Callable(), &"sfx": "kira", &"sfx_db": -6.0},
		&"bounce": {&"accel": 100.0, &"bounce_angle": 0.3, &"spawn_factory": Callable(), &"spawn_speed": 0.0, &"sfx": "kira", &"sfx_db": -8.0},
		&"avoid_player": {},
		&"non_mid_flee": {&"player_proximity": 150.0, &"on_flee_burst": Callable()},
		&"marisa_laser": {&"anchor_id": 0, &"anchor_offset": Vector2(1, 0), &"drift_speed": 800.0, &"angle": 0.3},
		&"laser_follow": {&"anchor_id": 0, &"anchor_offset": Vector2(1, 0), &"drift_speed": 1000.0, &"angle": 0.0, &"initial_drift": 5.0},
	}
	for move in cases:
		var lc := LifecycleCatalog.build(move, cases[move])
		assert_true(lc != null, "move %s 应有映射" % move)
		assert_gt(lc.phases.size(), 0, "move %s 应有相位" % move)


func test_build_structure() -> void:
	var b := LifecycleCatalog.build(&"bounce", {&"accel": 100.0, &"bounce_angle": 0.3, &"sfx": "kira"})
	assert_eq(b.phases.size(), 1, "bounce 单相位")
	assert_eq(b.phases[0][&"moves"][0][&"op"], BulletLifecycle.M_ACCEL_HEADING, "bounce 首 move")
	var h := LifecycleCatalog.build(&"homing", {&"homing_angle_per_sec": 1.0})
	assert_eq(h.phases[0][&"moves"][0][&"op"], BulletLifecycle.M_STEER, "homing 首 move")
	var cv := LifecycleCatalog.build(&"curve", {&"curve": 2.0, &"curve_limit": 1.0})
	assert_eq(cv.phases.size(), 2, "curve 两相位")
	var nm := LifecycleCatalog.build(&"non_mid_flee", {&"player_proximity": 150.0})
	assert_eq(nm.phases.size(), 2, "non_mid 两相位")


func test_unknown_move_returns_null() -> void:
	assert_true(LifecycleCatalog.build(&"no_such_move", {}) == null, "未知 move → null")


func test_sfx_key_converted_to_stringname() -> void:
	var b := LifecycleCatalog.build(&"bounce", {&"accel": 1.0, &"sfx": "kira"})
	var c := b.compile()
	assert_eq(c[&"sfx"].size(), 1, "bounce 有 1 个 sfx")
	assert_eq(c[&"sfx"][0], &"kira", "String 转 StringName")
	var b2 := LifecycleCatalog.build(&"bounce", {&"accel": 1.0, &"sfx": ""})
	assert_eq(b2.compile()[&"sfx"].size(), 0, "空 sfx 不加动作")


func test_cache_keyed_by_signature() -> void:
	var cat: LifecycleCatalog = autofree(LifecycleCatalog.new())
	var p := {&"accel": 100.0, &"bounce_angle": 0.3, &"sfx": "kira"}
	var a: BulletLifecycle = cat.get_lifecycle(&"bounce", p)
	var b: BulletLifecycle = cat.get_lifecycle(&"bounce", p)
	assert_true(a == b, "同签名应命中缓存")
	assert_eq(cat.cache_size(), 1, "缓存只 1 条")
	var c: BulletLifecycle = cat.get_lifecycle(&"bounce", {&"accel": 200.0, &"bounce_angle": 0.3, &"sfx": "kira"})
	assert_true(c != a, "不同 params 应新建")
	assert_eq(cat.cache_size(), 2, "缓存 2 条")
	var n: BulletLifecycle = cat.get_lifecycle(&"nope", {})
	var n2: BulletLifecycle = cat.get_lifecycle(&"nope", {})
	assert_true(n == null and n2 == null, "未知 move 也缓存 null")
	assert_eq(cat.cache_size(), 3, "缓存 3 条")
