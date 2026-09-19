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
