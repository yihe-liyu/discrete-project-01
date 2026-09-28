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


func test_rest_x_left_aligns_visual_left_to_parent_edge() -> void:
	var label_w := 384.0             # 夹具：8 个全角字
	var stop_x := AnnounceLabel.rest_x_left(label_w)
	var visual_left := stop_x + label_w * AnnounceLabel.EDGE_HALF
	assert_almost_eq(visual_left, 0.0, 0.001, "自机符卡名视觉左缘贴场地左缘")


func test_player_rest_offset_lifts_final_position() -> void:
	var parent := Vector2(768.0, 896.0)
	var label_size := Vector2(384.0, 70.0)
	var base := AnnounceLabel.player_rest_pos(parent, label_size, Vector2.ZERO)
	var lifted := AnnounceLabel.player_rest_pos(parent, label_size, Vector2(0.0, -120.0))
	assert_almost_eq(base.y - lifted.y, 120.0 / AnnounceLabel.SHRINK, 0.001, "负 y 偏移把最终位置抬高")
	assert_almost_eq(lifted.x, base.x, 0.001, "x 不受 y 偏移影响")


func test_player_style_background_left_aligned() -> void:
	var label := _make_label()
	label.play("梦想封印", Vector2(768, 896), _make_bg(), AnnounceLabel.Style.PLAYER)
	var bg := label.get_node("Background") as TextureRect
	assert_almost_eq(bg.position.x, 0.0, 0.001, "自机样式底衬局部 x=0")
	# 底衬视觉左缘 = 名字视觉左缘
	var pivot_x := label.size.x / 2.0
	var bg_visual_left := label.position.x + pivot_x + (bg.position.x - pivot_x) * AnnounceLabel.SHRINK
	var name_visual_left := label.position.x + label.size.x * (1.0 - AnnounceLabel.SHRINK) / 2.0
	assert_almost_eq(bg_visual_left, name_visual_left, 0.001, "底衬左缘 = 名字视觉左缘")


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
	label.background_offset = Vector2.ZERO   # 夹具起点，避开场景里的人工调值
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
	assert_ne(label.bonus_prefix, "", "Bonus 说明前缀声明在场景里")
	assert_ne(label.capture_prefix, "", "Capture 说明前缀声明在场景里")
	assert_eq(bonus.text, label.bonus_prefix + "59273", "Bonus 文本 = 前缀 + 值")
	assert_eq(capture.text, label.capture_prefix + "00/01", "Capture 文本 = 前缀 + n/m")


## 回归（2026-09-26）：加了说明前缀后 Bonus/Capture 两串变宽 —— 曾①各贴一端直接**叠在一起**、
## ②按名字宽度比例落点**顶出场地右缘**（实测越界 48px）。
## 现在整行**右对齐到名字视觉右缘**、向左依次排开：不重叠、且整行窄于场地。
func test_info_labels_right_aligned_without_overlap() -> void:
	var label := _make_label()
	label.play("阳符「宏辉抑世」", Vector2(768, 896))
	label._show_info_labels()
	label.set_bonus_text("1234567")
	label.set_capture_text("01/03")

	var bonus := label.get_node("BonusLabel") as Label
	var capture := label.get_node("CaptureLabel") as Label
	var bonus_w := bonus.get_minimum_size().x
	var capture_w := capture.get_minimum_size().x

	assert_almost_eq(capture.position.x + capture_w, label.size.x, 0.5,
		"整行右缘贴名字视觉右缘（= 场地右缘）")
	assert_almost_eq(capture.position.x - (bonus.position.x + bonus_w), AnnounceLabel.INFO_GAP, 0.5,
		"两串之间恰好 INFO_GAP（不重叠）")
	var row_w := (capture.position.x + capture_w - bonus.position.x) * AnnounceLabel.SHRINK
	assert_lt(row_w, 768.0, "整行缩放后必须窄于场地（实测 %.1f）" % row_w)


## 回归（2026-09-26 作者报）：bonus 逐帧递减 → 「奖励分数」整块会往右**抽动**。
## 根因：落点用的是**当前**文本宽度，而本作字体数字不等宽（实测 "1"=15px、"8"=18px）。
## 现在 Bonus 的预留宽度**只增不减**（递减计数器 ⇒ 见过的最宽即此后最宽）→ 框钉住不动。
func test_bonus_row_does_not_move_while_counting_down() -> void:
	var label := _make_label()
	label.play("阳符「宏辉抑世」", Vector2(768, 896))
	label._show_info_labels()
	label.set_capture_text("01/03")
	label.set_bonus_text("100000")
	var fixed_x: float = label._bonus_label.position.x
	var fixed_capture_x: float = label._capture_label.position.x

	for value in ["99999", "88888", "11111", "9999", "1", "0"]:
		label.set_bonus_text(value)
		assert_almost_eq(label._bonus_label.position.x, fixed_x, 0.001,
			"bonus 掉到 %s 时整块不应重排（否则抽动）" % value)
	assert_almost_eq(label._capture_label.position.x, fixed_capture_x, 0.001, "Capture 也不动")
	# 预留框（最宽时的 Bonus）与 Capture 之间必须留住 INFO_GAP → 最宽的数字也不会压到收取数
	assert_almost_eq(
		label._capture_label.position.x - (label._bonus_label.position.x + label._bonus_reserve),
		AnnounceLabel.INFO_GAP, 0.001, "预留宽度保住 INFO_GAP（不重叠）")
