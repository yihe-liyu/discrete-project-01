extends GutTest
## SpawnSpec：独立作者描述，能直接转换成 BulletType，并允许一层 child。


func test_tex_uses_bullet_def_texture_key() -> void:
	# 自机弹的 id（reimu_main）≠ 图集 shape key（灵梦自机主弹）；不能拿 id 直接查图集。
	var s := SpawnSpec.new().tex("reimu_main").player()
	assert_not_null(s.texture, "reimu_main 应有贴图")
	assert_eq(s.texture, BulletShapes.atlas_texture(&"灵梦自机主弹"), "应使用 BulletDef.texture_key")


func test_spawn_spec_keeps_type_and_child() -> void:
	var parent := SpawnSpec.new().tex("棱弹").enemy().color(Color.AQUA)
	var child := SpawnSpec.new().tex("米弹").enemy().color(Color.GOLD)
	parent.child = child
	assert_eq(parent.texture, BulletShapes.atlas_texture(&"棱弹"), "外观")
	assert_eq(parent.child.texture, BulletShapes.atlas_texture(&"米弹"), "child 保留自己的外观")
	assert_null(child.child, "默认没有更深一层")


func test_spawn_spec_service_accepts_spec() -> void:
	var svc := BulletService.new()
	assert_true(svc.has_method("shoot_spec"), "应提供 SpawnSpec 单发入口")
	assert_true(svc.has_method("shoot_spread_spec"), "应提供 SpawnSpec 扇形入口")



func test_spawn_spec_carries_core_overrides() -> void:
	var s := SpawnSpec.new().tex("棱弹").enemy()
	s.color(Color.RED).blend(false).wrap_edges(5).grace(4.0)
	s.hitbox_rect(Vector2(12, 8), Vector2(2, 3))
	s.facing(false, 0.5)
	s.no_spawn_fog()
	var bt := s.to_bullet_type()
	assert_eq(s.faction, SpawnSpec.Faction.ENEMY, "阵营")
	assert_eq(s.tint, Color.RED, "颜色")
	assert_eq(s.use_blend, false, "混合模式")
	assert_eq(bt.tint_mode, BulletType.TintMode.MULTIPLY, "blend(false) → MULTIPLY")
	assert_eq(s.wrap_mask, 5, "环绕")
	assert_eq(bt.out_grace, 4.0, "出界宽限")
	assert_eq(bt.hitbox_size, Vector2(12, 8), "判定尺寸")
	assert_eq(bt.follow_dir, false, "朝向覆盖")
	assert_almost_eq(bt.dir_offset, 0.5, 0.0001, "方向补偿")
	assert_false(bt.is_spawn_fog, "出生雾覆盖")


func test_spawn_spec_spawns_directly() -> void:
	var host := KernelBulletHost.new()
	add_child_autofree(host)
	var spec := SpawnSpec.new().tex("小玉").enemy().speed(120.0)
	var id := host.shoot_spec(spec, Vector2(300, 300), Vector2.DOWN)
	assert_true(id >= 0, "应能直接发射 SpawnSpec")
	assert_eq(host.system.get_behavior(id), -1, "无 behavior 的普通弹")
	assert_gt(host.system.get_active_count(), 0, "内核应有行")
