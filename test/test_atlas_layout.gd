extends GutTest
## F7·A 图集哨兵：布局资源的 atlas_size / 每格必须与 1024² 贴图一致、落在图内，且内容表的 shape 引用都能命中。
## （换图/重排后忘改 → UV 整片错位且不报错，这条就是那个坑的哨兵。）


func test_atlas_size_matches_texture() -> void:
	var atlas: AtlasLayout = BulletShapes.BULLET_ATLAS
	assert_not_null(atlas, "应能加载 data/atlas/bullet_shapes.tres")
	assert_ne(atlas.atlas_size, Vector2.ZERO, "atlas_size 必须显式配置（非默认 ZERO）")
	assert_eq(atlas.atlas_size, BulletShapes.BULLET_ATLAS_TEXTURE.get_size(), "atlas_size 应等于贴图实际尺寸")


func test_atlas_cells_in_bounds() -> void:
	var atlas: AtlasLayout = BulletShapes.BULLET_ATLAS
	var real := BulletShapes.BULLET_ATLAS_TEXTURE.get_size()
	var empty := 0
	var outside := 0
	var out_of_uv := 0
	for key in atlas.shapes:
		var r: Rect2 = atlas.shapes[key]
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			empty += 1
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > real.x or r.end.y > real.y:
			outside += 1
		var uv: Rect2 = atlas.uv_rect(key)
		if uv.position.x < 0.0 or uv.position.y < 0.0 or uv.end.x > 1.0001 or uv.end.y > 1.0001:
			out_of_uv += 1
	assert_eq(empty, 0, "不应有空尺寸的格")
	assert_eq(outside, 0, "每格都应落在贴图内")
	assert_eq(out_of_uv, 0, "每格归一化 UV 都应落在 [0,1]")
	assert_gt(atlas.shapes.size(), 28, "形状表应覆盖全部弹型")


func test_atlas_shape_lookup() -> void:
	assert_true(BulletShapes.BULLET_ATLAS.has_shape(&"小玉"), "has_shape 应命中已定义 key")
	assert_false(BulletShapes.BULLET_ATLAS.has_shape(&"不存在的形状"), "未定义 key 应为 false")


func test_bullet_types_shapes_resolve() -> void:
	var keys := BulletCatalog.keys()
	assert_gt(keys.size(), 0, "BulletCatalog 应有弹型")
	for key in keys:
		var bt: BulletDef = BulletCatalog.find(key)
		assert_true(BulletShapes.BULLET_ATLAS.has_shape(bt.texture_key), "%s 的 texture_key=%s 应在图集中" % [key, bt.texture_key])
		var tex := BulletShapes.atlas_texture(bt.texture_key)
		assert_eq(tex.region, BulletShapes.pixel_rect(bt.texture_key), "%s region 应对应布局格" % key)
	assert_same(BulletShapes.atlas_texture(&"小玉"), BulletShapes.atlas_texture(&"小玉"), "同 shape 应复用同一 AtlasTexture 实例")
