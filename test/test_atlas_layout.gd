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


## 格间余量（S13 判据，2026-09-30 复核后机械化）：**互不相干**的形状之间缝要 ≥1px
## （线性过滤 / mipmap 会跨格渗色），但**同一张原图**的引用方式必须放行 —— 本图集里正好两组：
##   ① 「整条 vs 它的切片」：`魔理沙子机高速弹`(512×32) 与 `…高速弹0..7`，一个矩形**包住**另一个；
##   ② 连续帧之间 0 缝：`…高速弹0..7` 同 y 同高、x 首尾相接 —— 它们本来就是一张画切出来的。
## 判据 = **外来重叠 0 对** + **互不相干的最窄缝 ≥ 1px**；不锁具体像素（重排图集不会白红）。
func test_atlas_gutter_and_no_foreign_overlap() -> void:
	const MIN_GUTTER := 1.0
	var atlas: AtlasLayout = BulletShapes.BULLET_ATLAS
	var keys := atlas.shape_keys()
	var foreign_overlap: Array[String] = []
	var narrowest := INF
	var adjacent := 0
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = atlas.shapes[keys[i]]
			var b: Rect2 = atlas.shapes[keys[j]]
			if _same_artwork(a, b):
				continue
			if a.intersects(b):
				foreign_overlap.append("%s × %s" % [keys[i], keys[j]])
				continue
			var gap := _adjacency_gap(a, b)
			if gap < INF:
				adjacent += 1
				narrowest = minf(narrowest, gap)

	assert_eq(foreign_overlap.size(), 0, "互不相干的格不许重叠：%s" % str(foreign_overlap))
	assert_gt(adjacent, 0, "应能算到互不相干的相邻格对（否则这条在空转）")
	assert_gt(narrowest, MIN_GUTTER - 0.001, "互不相干的最窄缝应 ≥ %.0f px（实测 %.0f）" % [MIN_GUTTER, narrowest])


## 同一张原图：① 一个矩形包住另一个（整条 vs 切片）；② 连续帧（同 y 同高且 x 首尾相接，竖直同理）
static func _same_artwork(a: Rect2, b: Rect2) -> bool:
	if a.encloses(b) or b.encloses(a):
		return true
	var same_row: bool = is_equal_approx(a.position.y, b.position.y) and is_equal_approx(a.size.y, b.size.y) \
			and (is_equal_approx(a.end.x, b.position.x) or is_equal_approx(b.end.x, a.position.x))
	var same_col: bool = is_equal_approx(a.position.x, b.position.x) and is_equal_approx(a.size.x, b.size.x) \
			and (is_equal_approx(a.end.y, b.position.y) or is_equal_approx(b.end.y, a.position.y))
	return same_row or same_col


## 相邻两格之间的"缝"：另一轴投影重叠才算相邻（对角不算贴）；两轴都分开 → INF
static func _adjacency_gap(a: Rect2, b: Rect2) -> float:
	var overlap_x: bool = a.position.x < b.end.x and b.position.x < a.end.x
	var overlap_y: bool = a.position.y < b.end.y and b.position.y < a.end.y
	var gap_x := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var gap_y := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	if overlap_y and not overlap_x:
		return gap_x
	if overlap_x and not overlap_y:
		return gap_y
	return INF


func test_bullet_types_shapes_resolve() -> void:
	var keys := BulletCatalog.keys()
	assert_gt(keys.size(), 0, "BulletCatalog 应有弹型")
	for key in keys:
		var bt: BulletDef = BulletCatalog.find(key)
		assert_true(BulletShapes.BULLET_ATLAS.has_shape(bt.texture_key), "%s 的 texture_key=%s 应在图集中" % [key, bt.texture_key])
		var tex := BulletShapes.atlas_texture(bt.texture_key)
		assert_eq(tex.region, BulletShapes.pixel_rect(bt.texture_key), "%s region 应对应布局格" % key)
	assert_same(BulletShapes.atlas_texture(&"小玉"), BulletShapes.atlas_texture(&"小玉"), "同 shape 应复用同一 AtlasTexture 实例")
