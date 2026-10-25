extends GutTest
## TelegraphService：内容一行调用 → chain → 场景 TelegraphPath；无节点时静默。

const SERVICE := preload("res://scripts/coroutine/services/telegraph_service.gd")
const PATH := preload("res://scripts/telegraph/telegraph_path.gd")


func _lc() -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0.0, 120.0)).until_elapsed(0.2)
	lc.then()
	lc.until_elapsed(0.2).despawn()
	return lc


func test_show_chain_draws_and_clear() -> void:
	var path = PATH.new()
	add_child_autofree(path)
	var service = SERVICE.new()
	service.telegraph_path = path
	var result: Dictionary = service.show_chain(
		_lc(), Vector2(400.0, 300.0), Vector2.DOWN, 200.0, 0.5)
	assert_true(result.ok, "确定性 chain 应成功")
	assert_true(path.is_showing(), "应交给 TelegraphPath 显示")
	assert_gt(path.point_count(), 1)
	service.clear()
	assert_false(path.is_showing(), "clear 应清掉路径")


func test_no_injected_path_is_silent() -> void:
	var service = SERVICE.new()
	var result: Dictionary = service.show_chain(
		_lc(), Vector2(400.0, 300.0), Vector2.DOWN, 200.0, 0.5)
	assert_true(result.ok, "没有展示节点时仍应返回 chain 结果")
