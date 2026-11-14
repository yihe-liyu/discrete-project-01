extends GutTest
## SpawnSpec：独立作者描述，能转换成 BulletData，并允许一层 child。


func test_spawn_spec_converts_to_bullet_data_with_child() -> void:
	var parent := SpawnSpec.new().tex("棱弹").enemy().color(Color.AQUA)
	var child := SpawnSpec.new().tex("米弹").enemy().color(Color.GOLD)
	parent.child = child
	var data := parent.to_bullet_data()
	assert_true(data is BulletData, "转换后应得到 BulletData")
	assert_eq(data.texture, BulletShapes.atlas_texture(&"棱弹"), "外观沿用 BulletData")
	assert_eq(parent.child.to_bullet_data().texture, BulletShapes.atlas_texture(&"米弹"), "child 保留自己的外观")
	assert_null(child.child, "默认没有更深一层")


func test_spawn_spec_service_accepts_spec() -> void:
	var svc := BulletService.new()
	assert_true(svc.has_method("shoot_spec"), "应提供 SpawnSpec 单发入口")
	assert_true(svc.has_method("shoot_spread_spec"), "应提供 SpawnSpec 扇形入口")
