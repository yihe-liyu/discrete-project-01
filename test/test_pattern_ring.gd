extends GutTest
## Pattern spike：基类 / 参数默认值 / Ring 的方向计算。

const RING := preload("res://data/patterns/ring.gd")
const PARAMS := preload("res://scripts/patterns/pattern_params.gd")


func test_ring_extends_bullet_pattern():
	var ring := RING.new()
	assert_true(ring is BulletPattern, "具体 pattern 应继承 BulletPattern")
	assert_true(ring.has_method("fire"), "具体 pattern 应实现 fire()")


func test_pattern_params_defaults_are_sane():
	var p := PARAMS.new()
	assert_gt(p.count, 0, "默认应有弹数")
	assert_gt(p.speed, 0.0, "默认应有速度")
	assert_almost_eq(p.spread, TAU, 0.001, "默认整圈")
	assert_null(p.bullet_def, "bullet_def 由内容/预设注入，默认空")
	assert_eq(p.extra, {}, "extra 默认为空")


func test_pattern_params_preset_loads():
	var preset: PatternParams = load("res://data/patterns/presets/ring_default.tres")
	assert_not_null(preset, "预设 .tres 应能加载")
	if preset == null:
		return
	assert_eq(preset.count, 12, "预设弹数")
	assert_not_null(preset.bullet_def, "预设应注入弹型定义")
	assert_almost_eq(preset.spread, TAU, 0.001, "预设整圈")


func test_spread_directions_full_ring_and_single():
	for count in [1, 3, 12]:
		var dirs: Array[Vector2] = RING.spread_directions(count, TAU, Vector2.UP)
		assert_eq(dirs.size(), count, "整圈应产生 count 个方向")
		for d in dirs:
			assert_almost_eq(d.length(), 1.0, 0.001, "方向应是单位向量")

	var single := RING.spread_directions(1, PI / 2.0, Vector2.UP)
	assert_eq(single.size(), 1, "单发只产生一个方向")
	assert_eq(single[0], Vector2.UP, "单发直接用 base_dir，不旋转")

	var arc := RING.spread_directions(3, PI / 2.0, Vector2.UP)
	assert_eq(arc.size(), 3, "扇形 3 发")
	assert_almost_eq(arc[1].angle(), Vector2.UP.angle(), 0.001, "扇形中轴 = base_dir")
	assert_almost_eq(arc[0].angle(), Vector2.UP.angle() - PI / 4.0, 0.001, "左端点 -45°")
	assert_almost_eq(arc[2].angle(), Vector2.UP.angle() + PI / 4.0, 0.001, "右端点 +45°")


func test_ring_fire_spawns_count_bullets():
	var bm := BulletManager.new()
	add_child_autofree(bm)
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	rt.bullet_manager = bm
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	runner.run(func(): return true)
	var ctx := StageContext.new(runner)
	ctx.stage = rt

	var preset: PatternParams = load("res://data/patterns/presets/ring_default.tres")
	var p := PARAMS.new()
	p.bullet_def = preset.bullet_def
	p.count = 6
	p.speed = 100.0
	RING.new().fire(ctx, p, Vector2(100, 100), Vector2.UP)
	assert_eq(bm.kernel_system().get_active_count(), 6, "6 发环弹应写进内核池")
	bm.clear_bullets()


func test_fire_with_null_context_is_noop():
	var ring := RING.new()
	ring.fire(null, PARAMS.new(), Vector2.ZERO, Vector2.UP)
	assert_true(true, "null ctx 应静默返回，不崩")
