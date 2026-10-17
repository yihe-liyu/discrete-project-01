extends GutTest
## F10c：LifecycleCatalog 只剩 `{lifecycle}` 兼容入口；旧 move preset 组合已删。

const FIX := preload("res://test/fixtures/lifecycle_fixtures.gd")


func test_lifecycle_entry_build_returns_same() -> void:
	var lc := FIX.homing()
	var out := LifecycleCatalog.build(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	assert_eq(out, lc, "lifecycle 入口应原样返回")


func test_unknown_move_returns_null() -> void:
	assert_true(LifecycleCatalog.build(&"no_such_move", {}) == null, "未知 move → null")
	assert_true(LifecycleCatalog.build(&"bounce", {&"accel": 100.0}) == null, "旧 preset move 已删 → null")


func test_lifecycle_signature_uses_content() -> void:
	var a := FIX.homing()
	var b := FIX.homing()
	assert_eq(
		LifecycleCatalog.signature(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": a}),
		LifecycleCatalog.signature(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": b}),
		"同结构 lifecycle 应同签名")
	var c := FIX.homing(deg_to_rad(360.0))
	assert_ne(
		LifecycleCatalog.signature(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": a}),
		LifecycleCatalog.signature(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": c}),
		"不同结构应不同签名")


func test_cache_keyed_by_signature() -> void:
	var cat: LifecycleCatalog = autofree(LifecycleCatalog.new())
	var a := FIX.homing()
	var b: BulletLifecycle = cat.get_lifecycle(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": a})
	var c: BulletLifecycle = cat.get_lifecycle(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": a})
	assert_eq(b, c, "同签名应命中缓存")
	assert_eq(cat.cache_size(), 1, "缓存只 1 条")


func test_unknown_move_cached_null() -> void:
	var cat: LifecycleCatalog = autofree(LifecycleCatalog.new())
	assert_true(cat.get_lifecycle(&"nope", {}) == null, "未知 move → null")
	assert_true(cat.get_lifecycle(&"nope", {}) == null, "未知 move 也缓存 null")
	assert_eq(cat.cache_size(), 1, "缓存 1 条 null")
