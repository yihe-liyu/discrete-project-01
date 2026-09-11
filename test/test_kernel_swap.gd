extends GutTest
## S3a：BulletManager.use_kernel 路由（弹幕走内核池 + 内核渲染数据源；**碰撞不在本步**）。


func after_each() -> void:
	BulletManager.set_use_kernel(false)
	BulletManager.clear_all()


func _enemy_data() -> BulletData:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return d


func test_swap_routes_spawn_to_kernel() -> void:
	BulletManager.set_use_kernel(true)
	assert_not_null(BulletManager.kernel_system(), "切到内核应建出内核弹池")
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2(100, 100), Vector2.RIGHT)
	assert_eq(BulletManager.kernel_system().get_active_count(), 1, "应写进内核池")
	assert_eq(BulletManager.active_bullets.size(), 0, "不应再写旧池")


func test_kernel_cull_rect_set_to_field() -> void:
	BulletManager.set_use_kernel(true)
	assert_eq(BulletManager.kernel_system().cull_rect, Rect2(
		GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP), "剔除范围应对齐东方框")
	assert_gt(BulletManager.kernel_system().cull_margin, 0.0, "应有剔除余量")


func test_swap_back_clears_kernel_and_restores_legacy() -> void:
	BulletManager.set_use_kernel(true)
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	BulletManager.set_use_kernel(false)
	assert_eq(BulletManager.kernel_system().get_active_count(), 0, "切回旧路应清空内核池")
	var before: int = BulletManager.active_bullets.size()
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	assert_eq(BulletManager.active_bullets.size(), before + 1, "切回旧路应写旧池")


func test_kernel_priority_precedes_manager() -> void:
	BulletManager.set_use_kernel(true)
	assert_lt(BulletManager.kernel_system().process_physics_priority,
		BulletManager.process_physics_priority, "内核积分必须先于宿主碰撞（§16.3）")
