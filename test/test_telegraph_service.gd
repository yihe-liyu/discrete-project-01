extends GutTest
## TelegraphService：内容一行调用 → chain → 场景 TelegraphPath；无节点时静默。

const SERVICE := preload("res://scripts/coroutine/services/telegraph_service.gd")
const PATH := preload("res://scripts/telegraph/telegraph_path.gd")
const BULLET_SERVICE := preload("res://scripts/coroutine/services/bullet_service.gd")


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


func test_show_chain_many_draws_multiple_paths() -> void:
	var path = PATH.new()
	add_child_autofree(path)
	var service = SERVICE.new()
	service.telegraph_path = path
	var results: Array[Dictionary] = service.show_chain_many(
		_lc(), Vector2(400.0, 300.0),
		[Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], 200.0, 0.5)
	assert_eq(results.size(), 3, "三个方向各一份结果")
	assert_eq(path.path_count(), 3, "应画三条线")


func test_track_bullets_prunes_dead_uids() -> void:
	var bm := BulletManager.new()
	add_child_autofree(bm)
	await get_tree().process_frame
	if bm.kernel_system() == null or not bm.kernel_system().is_native_ready():
		pending("无原生扩展")
		return
	var bs = BULLET_SERVICE.new()
	bs.bullet_manager = bm
	var lc := BulletLifecycle.new()
	lc.until_elapsed(5.0).despawn()
	var data := BulletData.new().tex("小玉").speed(100.0).enemy().trajectory(lc)
	var uids: Array[int] = bs.shoot_spread_ids(
		data, 3, TAU, Vector2.DOWN, Vector2(448, 240))
	assert_eq(uids.size(), 3)

	var path = PATH.new()
	add_child_autofree(path)
	var service = SERVICE.new()
	service.telegraph_path = path
	service.bullet_manager = bm
	assert_true(service.track_bullets(uids, lc), "三颗都应进入跟踪")
	path.call("_process", 0.2)
	assert_eq(path.path_count(), 3, "三颗应各一条线")

	var more: Array[int] = bs.shoot_spread_ids(
		data, 2, TAU, Vector2.DOWN, Vector2(448, 240))
	assert_true(service.add_tracked_bullets(more, lc), "新弹应追加而不是重置")
	path.call("_process", 0.2)
	assert_eq(path.path_count(), 5, "旧弹 + 新弹应同时保留")

	bm.despawn_bullet(0)
	path.call("_process", 0.2)
	assert_eq(path.path_count(), 4, "死一颗应掉一条")
