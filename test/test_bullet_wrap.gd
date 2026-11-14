extends GutTest
## 弹幕四边环绕：碰到下边回上边、左边回右边，反之亦然。


func _setup() -> KernelNativeSystem:
	var bm := BulletManager.new()
	add_child_autofree(bm)
	await get_tree().process_frame
	var sys := bm.kernel_system()
	if sys == null or not sys.is_native_ready():
		return null
	bm.set_physics_process(false)
	return sys


func test_wrap_bottom_to_top() -> void:
	var sys := await _setup()
	if sys == null:
		pending("无原生扩展")
		return
	var bm := BulletManager.current
	var data := SpawnSpec.new().tex("小玉").speed(200.0).enemy().no_spawn_fog().wrap_around()
	var row := bm.shoot_spec(data, Vector2(448, GameConfig.FIELD_BOTTOM + 10), Vector2.DOWN)
	sys.set_position(row, Vector2(448, GameConfig.FIELD_BOTTOM + 10))
	sys.set_velocity(row, Vector2(0, 200))
	sys.step(1.0 / 60.0)
	var pos := sys.get_position(row)
	assert_lt(pos.y, GameConfig.FIELD_BOTTOM, "底边应回到上方")
	assert_gt(pos.y, GameConfig.FIELD_TOP, "应在场地内")


func test_wrap_left_to_right() -> void:
	var sys := await _setup()
	if sys == null:
		pending("无原生扩展")
		return
	var bm := BulletManager.current
	var data := SpawnSpec.new().tex("小玉").speed(200.0).enemy().no_spawn_fog().wrap_around()
	var row := bm.shoot_spec(data, Vector2(GameConfig.FIELD_LEFT - 10, 300), Vector2.LEFT)
	sys.set_position(row, Vector2(GameConfig.FIELD_LEFT - 10, 300))
	sys.set_velocity(row, Vector2(-200, 0))
	sys.step(1.0 / 60.0)
	var pos := sys.get_position(row)
	assert_gt(pos.x, GameConfig.FIELD_LEFT, "左边应回到场内")
	assert_lt(pos.x, GameConfig.FIELD_RIGHT, "不应停在左边界外")


func test_wrap_flag_reaches_bullet_type() -> void:
	var data := SpawnSpec.new().enemy().wrap_around()
	assert_eq(data.to_bullet_type().wrap_mask, 15, "四边环绕掩码应进入 BulletType")


func test_wrap_mask_selects_edges() -> void:
	var horizontal := SpawnSpec.new().enemy().wrap_horizontal()
	assert_eq(horizontal.wrap_mask, 3, "左右环绕 = LEFT | RIGHT")
	var vertical := SpawnSpec.new().enemy().wrap_vertical()
	assert_eq(vertical.wrap_mask, 12, "上下环绕 = TOP | BOTTOM")
