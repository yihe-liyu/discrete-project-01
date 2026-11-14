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



func test_spawn_spec_carries_core_overrides() -> void:
	var s := SpawnSpec.new().tex("棱弹").enemy()
	s.color(Color.RED).blend(false).wrap(5).grace(4.0)
	s.hitbox_rect(Vector2(12, 8), Vector2(2, 3))
	s.facing(false, 0.5)
	s.no_spawn_fog()
	var d := s.to_bullet_data()
	assert_eq(d.faction, BulletData.Faction.ENEMY, "阵营")
	assert_eq(d.tint, Color.RED, "颜色")
	assert_eq(d.tint_mode, BulletData.TintMode.MULTIPLY, "混合模式")
	assert_eq(d.wrap_mask, 5, "环绕")
	assert_eq(d.out_grace, 4.0, "出界宽限")
	assert_eq(d.hitbox_shape, BulletData.HitboxShape.RECTANGLE, "矩形判定")
	assert_eq(d.hitbox_size, Vector2(12, 8), "判定尺寸")
	assert_eq(d.follow_dir, false, "朝向覆盖")
	assert_almost_eq(d.dir_offset, 0.5, 0.0001, "方向补偿")
	assert_false(d.is_spawn_fog, "出生雾覆盖")


func test_spawn_spec_spawns_without_bullet_data() -> void:
	var host := KernelBulletHost.new()
	add_child_autofree(host)
	var spec := SpawnSpec.new().tex("小玉").enemy().speed(120.0)
	var id := host.shoot_spec(spec, Vector2(300, 300), Vector2.DOWN)
	assert_true(id >= 0, "应能直接发射 SpawnSpec")
	assert_eq(host.system.get_behavior(id), -1, "无 behavior 的普通弹")
	assert_gt(host.system.get_active_count(), 0, "内核应有行")
