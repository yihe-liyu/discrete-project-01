extends GutTest
## FieldFilterLayer：场地颜色滤镜 —— 透明色不播；有色时铺满游戏框、从框中心扩圆。

const FILTER_SCENE := preload("res://scenes/effect/field_filter_layer.tscn")


func _make() -> FieldFilterLayer:
	var layer := FILTER_SCENE.instantiate() as FieldFilterLayer
	add_child_autofree(layer)
	return layer


func _mat(layer: FieldFilterLayer) -> ShaderMaterial:
	return (layer.get_node("Filter") as ColorRect).material as ShaderMaterial


func test_rect_covers_play_field() -> void:
	var layer := _make()
	var rect := layer.get_node("Filter") as ColorRect
	assert_eq(rect.position, Vector2(64.0, 32.0), "从游戏框左上角起")
	assert_eq(rect.size, Vector2(768.0, 896.0), "范围严格限制在游戏框内")


func test_transparent_color_ignored() -> void:
	var layer := _make()
	GameEvents.field_filter.emit(Color(1.0, 0.0, 0.0, 0.0))
	assert_false((layer.get_node("Filter") as ColorRect).visible, "a<=0 不播")


func test_plays_from_field_center() -> void:
	var layer := _make()
	var col := Color(1.0, 0.35, 0.45, 0.35)
	GameEvents.field_filter.emit(col)
	var rect := layer.get_node("Filter") as ColorRect
	assert_true(rect.visible, "有色就显示")
	var mat := _mat(layer)
	assert_eq(mat.get_shader_parameter("filter_color"), col, "滤镜颜色来自 BombData")
	assert_eq(mat.get_shader_parameter("center_uv"), Vector2(0.5, 0.5), "圆心 = 游戏框中心")
	assert_almost_eq(float(mat.get_shader_parameter("radius")), 0.0, 0.001, "从半径 0 起扩圆")


## 被弹炸弹窗口：**整框**直接给满半径（不是扩圆）+ alpha 从 0 **渐显**
## —— 窗口期全局被定格（`time_scale = 0`），所以这条 tween 必须 `ignore_time_scale` 才走得动
func test_deathbomb_started_fades_whole_field_in() -> void:
	var layer := _make()
	GameEvents.deathbomb_started.emit()
	var rect := layer.get_node("Filter") as ColorRect
	assert_true(rect.visible, "窗口开 → 显示")
	var mat := _mat(layer)
	assert_eq(mat.get_shader_parameter("filter_color"), layer.deathbomb_color,
			"颜色来自 @export（框内整体红）")
	assert_almost_eq(float(mat.get_shader_parameter("radius")), rect.size.length() * 0.75, 0.001,
			"整框铺满：半径直接给满，不扩圆")
	assert_almost_eq(float(mat.get_shader_parameter("alpha")), 0.0, 0.001, "从 0 起渐显")

	Engine.time_scale = 0.0   # 模拟窗口期的定格：还走不动就说明忘了 ignore_time_scale
	for _i in 8:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	assert_gt(float(mat.get_shader_parameter("alpha")), 0.0, "定格中也照样渐显")


## 窗口关 → 渐隐并收起
func test_deathbomb_ended_fades_whole_field_out() -> void:
	var layer := _make()
	GameEvents.deathbomb_started.emit()
	for _i in 4:
		await get_tree().process_frame
	GameEvents.deathbomb_ended.emit()
	await get_tree().create_timer(layer.deathbomb_fade_out + 0.2).timeout
	assert_false((layer.get_node("Filter") as ColorRect).visible, "渐隐后收起")
