extends GutTest
## TelegraphPath：路径展示层只负责画线，不挂判定。

const PATH := preload("res://scripts/telegraph/telegraph_path.gd")


func test_show_and_clear_path() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	assert_false(path.is_showing(), "初始应隐藏")

	path.show_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 10), Vector2(20, 30)]))
	assert_true(path.is_showing(), "有 >= 2 个点时应显示")
	assert_eq(path.point_count(), 3, "点数应写入 Line2D")

	path.clear_path()
	assert_false(path.is_showing(), "清空后应隐藏")
	assert_eq(path.point_count(), 0, "清空后不应保留点")


func test_single_point_clears_path() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	path.show_path(PackedVector2Array([Vector2(5, 5)]))
	assert_false(path.is_showing(), "单点无法成线，视为清空")
	assert_eq(path.point_count(), 0)


func test_show_path_replaces_previous_points() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	path.show_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]))
	path.show_path(PackedVector2Array([Vector2(0, 0), Vector2(0, 10), Vector2(10, 10)]))
	assert_eq(path.point_count(), 3, "第二次应替换而不是追加")
	assert_true(path.is_showing())


func test_lifetime_clears_path() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	path.show_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]),
		Color.WHITE, 3.0, 0.05)
	assert_true(path.is_showing())
	path.call("_process", 0.1)
	assert_false(path.is_showing(), "超过 lifetime 应自动清空")
	assert_eq(path.point_count(), 0)


func test_show_multiple_paths() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	path.show_paths([
		PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]),
		PackedVector2Array([Vector2(0, 10), Vector2(10, 10)]),
		PackedVector2Array([Vector2(0, 20), Vector2(10, 20)]),
	], Color.WHITE, 3.0, 0.5)
	assert_true(path.is_showing())
	assert_eq(path.path_count(), 3, "三条独立线")
	path.clear_path()
	assert_eq(path.path_count(), 0)


func test_layer_below_enemy_bullets() -> void:
	var path: Node2D = PATH.new()
	add_child_autofree(path)
	assert_eq(path.z_index, LayerConfig.ENEMY_BULLET - 1, "路径应压在敌弹之下")
	assert_false(path.z_as_relative, "路径使用绝对层")
