extends GutTest
## SpawnSpec 过渡入口：当前必须仍能作为 BulletData 使用，并允许一层 child。


func test_spawn_spec_is_bullet_data_with_child() -> void:
	var parent := SpawnSpec.new().tex("棱弹").enemy().color(Color.AQUA)
	var child := SpawnSpec.new().tex("米弹").enemy().color(Color.GOLD)
	parent.child = child
	assert_true(parent is BulletData, "过渡期 SpawnSpec 必须兼容旧 API")
	assert_eq(parent.texture, BulletShapes.atlas_texture(&"棱弹"), "外观沿用 BulletData")
	assert_eq(parent.child.texture, BulletShapes.atlas_texture(&"米弹"), "child 保留自己的外观")
	assert_null(child.child, "默认没有更深一层")
