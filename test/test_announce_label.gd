extends GutTest
## AnnounceLabel：右停落点（视觉盒贴边）+ 场景声明的底衬 / Bonus / Capture 子节点。

const ANNOUNCE_SCENE := preload("res://scenes/ui/announce_label.tscn")


## 视觉右缘 = 布局框 x + size.x*(1+SHRINK)/2。按 pivot 语义独立推导，不复用实现常量。
func _visual_right(label_size_x: float, stop_x: float) -> float:
	return stop_x + label_size_x * (1.0 + AnnounceLabel.SHRINK) / 2.0


## 实例化组件场景（子节点声明在 .tscn 里）。
func _make_label() -> AnnounceLabel:
	var label := ANNOUNCE_SCENE.instantiate() as AnnounceLabel
	add_child_autofree(label)
	return label


## 底衬夹具：400×63 占位纹理（不碰真实素材）。
func _make_bg() -> Texture2D:
	var tex := PlaceholderTexture2D.new()
	tex.size = Vector2(400.0, 63.0)
	return tex


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


func test_background_is_behind_label_and_keeps_source_size() -> void:
	var label := _make_label()
	label.play("音符「定点扩散」", Vector2(768, 896), _make_bg())
	var bg := label.get_node_or_null("Background") as TextureRect
	assert_not_null(bg, "底衬节点声明在场景里")
	assert_true(bg.show_behind_parent, "底衬画在文字之后（背后）")
	assert_true(bg.visible, "传了底衬就显示")
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


func test_background_hidden_when_not_provided() -> void:
	var label := _make_label()
	label.play("音符「定点扩散」", Vector2(768, 896))
	var bg := label.get_node_or_null("Background") as TextureRect
	assert_not_null(bg, "底衬节点始终在场景里")
	assert_false(bg.visible, "没传底衬就不显示")


func test_background_offset_shifts_position_by_screen_pixels() -> void:
	var label := _make_label()
	label.play("音符「定点扩散」", Vector2(768, 896), _make_bg())
	var bg := label.get_node("Background") as TextureRect
	var base := bg.position
	label.background_offset = Vector2(10.0, -6.0)
	label.play("音符「定点扩散」", Vector2(768, 896), _make_bg())
	assert_almost_eq(bg.position.x - base.x, 10.0 / AnnounceLabel.SHRINK, 0.001, "x 偏移按屏幕像素（除以 SHRINK）")
	assert_almost_eq(bg.position.y - base.y, -6.0 / AnnounceLabel.SHRINK, 0.001, "y 偏移按屏幕像素（除以 SHRINK）")


func test_info_labels_declared_and_hidden_until_finished() -> void:
	var label := _make_label()
	label.play("音符「定点扩散」", Vector2(768, 896))
	var bonus := label.get_node_or_null("BonusLabel") as Label
	var capture := label.get_node_or_null("CaptureLabel") as Label
	assert_not_null(bonus, "Bonus 声明在场景里")
	assert_not_null(capture, "Capture 声明在场景里")
	assert_false(bonus.visible, "播报中先隐藏")
	assert_false(capture.visible, "播报中先隐藏")
	label.set_bonus_text("59273")
	label.set_capture_text("00/01")
	assert_eq(bonus.text, "59273", "Bonus 文本走 setter")
	assert_eq(capture.text, "00/01", "Capture 文本走 setter")
