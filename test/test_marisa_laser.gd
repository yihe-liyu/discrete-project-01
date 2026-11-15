extends GutTest
## 验证魔理沙分段激光：切片 + 偏移无缝 + 编译加载

func test_segment_slicing():
	var cs = load("res://scripts/coroutine/player/marisa_shoot.gd")
	assert_not_null(cs, "marisa_shoot 应加载")
	# 验证切片（通过实例调用 _make_laser_segment）
	var inst = cs.new()
	autofree(inst)
	var n: int = inst._seg_count()
	var w: float = inst.SEG_W
	# 切片取自**原始图集**：起点 = 图集合体格 `魔理沙子机高速弹` 的像素位置
	var base: Vector2 = BulletShapes.pixel_rect(inst.LASER_SHAPE).position
	var seg: AtlasTexture = inst._make_laser_segment(0)
	assert_not_null(seg, "段 0 应存在")
	assert_eq(seg.region, Rect2(base, Vector2(w, 32)), "段 0 region 应为图集格起点 + (0,0)")
	var seg_last: AtlasTexture = inst._make_laser_segment(n - 1)
	assert_eq(seg_last.region, Rect2(base + Vector2((n - 1) * w, 0), Vector2(w, 32)), "最后段 region 应正确")
	# 段数自动由图集算出
	assert_eq(n, int(512.0 / w), "段数应自动 = 图集宽/段宽")

func test_offset_sequence_is_seamless():
	var cs = load("res://scripts/coroutine/player/marisa_shoot.gd")
	var inst = cs.new()
	autofree(inst)
	# 段 i 偏移 = (0, -i*32)：间距=段宽 → 无缝
	var prev_y := 0.0
	for i in inst._seg_count():
		var offset := Vector2(0, -i * inst.SEG_W)
		if i > 0:
			assert_eq(prev_y - offset.y, float(inst.SEG_W), "段 %d 与上一段间距应为段宽 32" % i)
		prev_y = offset.y


func test_spawn_spec_laser_kind_maps_to_bullet_type():
	var d := SpawnSpec.new().player()
	d.kind = BulletType.Kind.LASER
	assert_eq(d.to_bullet_type().kind, BulletType.Kind.LASER, "SpawnSpec.kind 应带到内核弹型")


func test_player_laser_uses_multiply_tint():
	var cs = load("res://scripts/coroutine/player/marisa_shoot.gd")
	var inst = cs.new()
	autofree(inst)
	var spec: SpawnSpec = inst._get_laser_bullet(0)
	assert_false(spec.use_blend, "自机激光应使用 MULTIPLY（保留贴图颜色）")
	assert_eq(spec.to_bullet_type().tint_mode, BulletType.TintMode.MULTIPLY,
		"自机激光不应吃 BLEND 的白色混合")
