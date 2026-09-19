extends GutTest
## AnnounceLabel 右停落点：缩放绕中心 pivot，视觉包围盒每侧比布局框多 size*(1-SHRINK)/2。
## 不变量：停靠后「视觉右缘」贴父容器右缘——越界会被上层 HUD 相框（false_front）盖掉。

## 视觉右缘 = 布局框 x + size.x*(1+SHRINK)/2。按 pivot 语义独立推导，不复用实现常量。
func _visual_right(label_size_x: float, stop_x: float) -> float:
	return stop_x + label_size_x * (1.0 + AnnounceLabel.SHRINK) / 2.0


func test_rest_x_aligns_visual_right_to_parent_edge() -> void:
	var parent_w := 768.0            # BossUI Control（场地）宽
	var label_w := 384.0             # 夹具：8 个全角字 @ font 48
	var stop_x := AnnounceLabel.rest_x(parent_w, label_w)
	assert_almost_eq(_visual_right(label_w, stop_x), parent_w, 0.001,
		"长符卡名右缘贴场地右缘（不再越界被 HUD 相框切）")


func test_rest_x_keeps_visual_box_inside_for_short_names() -> void:
	var parent_w := 768.0
	var label_w := 192.0             # 夹具：4 个字
	var stop_x := AnnounceLabel.rest_x(parent_w, label_w)
	assert_true(stop_x >= 0.0, "短名字也不能跑到场地左边之外")
	assert_almost_eq(_visual_right(label_w, stop_x), parent_w, 0.001)


func test_rest_x_moves_left_as_label_grows() -> void:
	var parent_w := 768.0
	var short_x := AnnounceLabel.rest_x(parent_w, 192.0)
	var long_x := AnnounceLabel.rest_x(parent_w, 384.0)
	assert_true(long_x < short_x, "名字越长落点越靠左（右缘固定）")
	assert_almost_eq(short_x - long_x, 192.0 * AnnounceLabel.VISUAL_HALF, 0.001)


## 底衬夹具：400×63 占位纹理（不碰真实素材）。
func _make_bg() -> Texture2D:
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(400.0, 63.0)
	return tex


func test_background_is_behind_label_and_matches_size() -> void:
	var label := AnnounceLabel.new()
	add_child_autofree(label)
	label.play("音符「定点扩散」", Vector2(768, 896), _make_bg())
	var bg := label.get_node_or_null("Background") as TextureRect
	assert_not_null(bg, "给了底衬就挂 Background 子节点")
	assert_true(bg.show_behind_parent, "底衬画在文字之后（背后）")
	# 贴图原尺寸，大小不动；靠子 scale = 1/SHRINK 抵消父节点最终缩放
	assert_eq(bg.size, Vector2(400.0, 63.0), "底衬保持贴图原尺寸")
	var rendered := bg.size * bg.scale * AnnounceLabel.SHRINK
	assert_almost_eq(rendered.x, 400.0, 0.001, "静止时渲染宽 = 原宽（无缩放）")
	assert_almost_eq(rendered.y, 63.0, 0.001, "静止时渲染高 = 原高（无缩放）")
	# 视觉右缘 = 名字视觉右缘（父节点缩到 SHRINK 时右缘贴边）
	var local_right := bg.position.x + bg.size.x * bg.scale.x
	var pivot_x := label.size.x / 2.0
	var bg_visual_right := label.position.x + pivot_x + (local_right - pivot_x) * AnnounceLabel.SHRINK
	var name_visual_right := label.position.x + label.size.x * (1.0 + AnnounceLabel.SHRINK) / 2.0
	assert_almost_eq(bg_visual_right, name_visual_right, 0.001, "底衬右缘 = 名字视觉右缘")
	assert_eq(bg.modulate.a, 0.0, "初始透明，缩回正常后再渐显")


func test_no_background_node_when_not_provided() -> void:
	var label := AnnounceLabel.new()
	add_child_autofree(label)
	label.play("音符「定点扩散」", Vector2(768, 896))
	assert_null(label.get_node_or_null("Background"), "没给底衬就不挂子节点")
