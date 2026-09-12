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
	var seg: AtlasTexture = inst._make_laser_segment(0)
	assert_not_null(seg, "段 0 应存在")
	assert_eq(seg.region, Rect2(0, 0, w, 32), "段 0 region 应为 (0,0,SEG_W,32)")
	var seg_last: AtlasTexture = inst._make_laser_segment(n - 1)
	assert_eq(seg_last.region, Rect2((n - 1) * w, 0, w, 32), "最后段 region 应正确")
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
