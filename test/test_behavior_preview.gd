extends GutTest
## BehaviorPreview：直接跑 native behavior tick 的路径预览。

const PREVIEW := preload("res://scripts/telegraph/behavior_preview.gd")


func test_straight_line_without_behavior() -> void:
	var spec := SpawnSpec.new().tex("小玉").enemy()
	var res: Dictionary = PREVIEW.evaluate(
		spec, Vector2(400, 300), Vector2(0, 100), 0.1)
	assert_true(res.ok, "无 behavior 应走直线兜底")
	assert_eq(res.reason, &"no_behavior")
	assert_almost_eq(res.points[res.points.size() - 1].y, 310.0, 0.5, "直线应走到 0.1s 的位置")


func test_accel_heading_curves_path() -> void:
	var spec := SpawnSpec.new().tex("小玉").enemy() \
		.with_behavior(BulletBehaviors.accel(Vector2(0, 1200)))
	var res: Dictionary = PREVIEW.evaluate(
		spec, Vector2(400, 300), Vector2(0, 100), 0.2)
	assert_true(res.ok, "accel 应可预览")
	assert_gt(res.points.size(), 2, "应产生多点折线")
	assert_gt(res.points[res.points.size() - 1].y, 320.0, "加速后应比直线更远")


func test_anchor_drift_uses_anchor() -> void:
	var spec := SpawnSpec.new().tex("小玉").enemy() \
		.with_behavior(BulletBehaviors.anchor_drift(0.0, 800.0, 13.333, true))
	var anchor := Vector2(340, 560)
	var res: Dictionary = PREVIEW.evaluate(
		spec, anchor + Vector2(0, -13.333), Vector2.UP, 0.1,
		1.0 / 60.0, Vector2.ZERO, PackedVector2Array(), anchor)
	assert_true(res.ok, "anchor_drift 应可预览")
	assert_almost_eq(res.points[0].x, anchor.x, 0.01, "首点应贴锚点")
	assert_lt(res.points[res.points.size() - 1].y, anchor.y, "应向上漂移")


func test_bounce_emit_stops_at_wall() -> void:
	var child := SpawnSpec.new().tex("米弹").enemy()
	var tpl := EmitTemplate.new(&"preview_bounce", child)
	assert_true(EmitTemplateRegistry.new().register(tpl), "模板应注册")
	var spec := SpawnSpec.new().tex("小玉").speed(100.0).enemy() \
		.with_behavior(BulletBehaviors.bounce_emit(tpl, 100.0, 0.0, 0.0, true, true))
	var res: Dictionary = PREVIEW.evaluate(
		spec, Vector2(830, 300), Vector2(100, 0), 0.5)
	assert_true(res.ok, "bounce 应可预览")
	var last: Vector2 = res.points[res.points.size() - 1]
	assert_lte(last.x, 832.5, "撞墙后应停止（不再往后画）")
	assert_gt(last.x, 800.0, "路径应走到墙附近")


func test_simplify_keeps_corners() -> void:
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(20, 0),
		Vector2(20, 10), Vector2(20, 20),
	])
	var simplified := PREVIEW.simplify_path(points, 0.5)
	assert_eq(simplified.size(), 3, "共线点应被压掉，只留两个拐点 + 端点")


func test_null_spec_is_invalid() -> void:
	var res: Dictionary = PREVIEW.evaluate(null, Vector2.ZERO, Vector2.UP, 0.1)
	assert_false(res.ok, "null spec 应返回 invalid")
