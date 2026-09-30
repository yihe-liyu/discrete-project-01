extends GutTest
## 符卡背景（**每 Boss 一张场景**，只在符卡期间显示）：
## 宿主层 `SpellBackdropLayer` 管「显隐 / 层级 / 淡入淡出 / 同场景不重建」，
## 滚动层 `SpellBackdropScroll` 是作者可选贴在场景内的"自动向上无缝滚动"组件。
## 场景用**运行时 pack 的夹具**，不绑真实内容。

const LAYER := preload("res://scripts/scenes/spell_backdrop_layer.gd")
const SCROLL := preload("res://scripts/scenes/spell_backdrop_scroll.gd")
const PLAIN_TEMPLATE := preload("res://scenes/effect/spell_backdrop_plain.tscn")


func _phase(uid: int) -> PhaseData:
	var p := PhaseData.new()
	p.uid = uid
	p.hp = 1000
	p.time_limit = 30.0
	return p


## 运行时造一个 PackedScene 夹具（根 = Node2D）
func _mk_scene() -> PackedScene:
	var node := Node2D.new()
	node.name = "BackdropFixture"
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	return packed


func _mk_layer() -> SpellBackdropLayer:
	var layer := LAYER.new() as SpellBackdropLayer
	add_child_autofree(layer)
	return layer


## 场地尺寸（768×896）的占位图 —— 滚动层夹具
func _tex() -> Texture2D:
	var t := PlaceholderTexture2D.new()
	t.size = Vector2(768.0, 896.0)
	return t


func _mk_scroll() -> SpellBackdropScroll:
	var sprite := SCROLL.new() as SpellBackdropScroll
	sprite.texture = _tex()
	add_child_autofree(sprite)
	return sprite


## 判据：**符卡才显示**；非符 / 无阶段不显示（「有没有场景」由调用方保证，见下一条）
func test_should_show_rule():
	assert_true(LAYER.should_show(_phase(1)), "符卡 → 显示")
	assert_false(LAYER.should_show(_phase(0)), "**非符 → 不显示**")
	assert_false(LAYER.should_show(null), "无阶段 → 不显示")


## apply()：符卡 + 有场景 → 实例化并淡入；非符 / 没配场景 → 淡出收掉
func test_apply_instantiates_and_fades_in():
	var layer := _mk_layer()
	var scene := _mk_scene()
	layer.apply(_phase(1), scene)
	assert_true(layer.visible, "符卡 + 有场景 → 显示")
	assert_eq(layer.get_child_count(), 1, "场景实例挂在宿主下（继承位置/层级/透明度）")
	assert_true(layer.get_child(0) is Node2D, "挂的就是那个场景的根")

	await wait_seconds(0.5)
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "淡入完成")

	layer.apply(_phase(1), null)      # Boss 没配场景
	await wait_seconds(0.5)
	assert_false(layer.visible, "没配场景 → 隐藏")
	assert_eq(layer.get_child_count(), 0, "淡出后实例应被释放")

	layer.apply(_phase(1), scene)
	await wait_seconds(0.5)
	layer.apply(_phase(0), scene)     # 非符：即便配了也不显示
	await wait_seconds(0.5)
	assert_false(layer.visible, "非符 → 淡出隐藏")


## 同一张场景重复 apply：**不重建、不重播淡入**（同 Boss 连打两张符卡不闪）
func test_same_scene_is_not_rebuilt_nor_refaded():
	var layer := _mk_layer()
	var scene := _mk_scene()
	layer.apply(_phase(1), scene)
	await wait_seconds(0.5)
	var inst: Node = layer.get_child(0)
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "淡入完成")

	layer.apply(_phase(2), scene)     # 换阶段、同一张场景
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "同场景不重播淡入（alpha 不该被清零）")
	assert_same(layer.get_child(0), inst, "实例也复用，不重建")


## 换场景 → 换实例（旧的会被释放）
func test_different_scene_replaces_instance():
	var layer := _mk_layer()
	layer.apply(_phase(1), _mk_scene())
	await wait_seconds(0.5)
	var first: Node = layer.get_child(0)

	layer.apply(_phase(1), _mk_scene())
	await get_tree().process_frame      # 旧实例走 queue_free → 帧末才真的走
	assert_eq(layer.get_child_count(), 1, "同时只留一个实例（旧的已释放）")
	assert_ne(layer.get_child(0), first, "换场景应换实例")
	assert_false(is_instance_valid(first), "旧实例已释放")


## 摆放：宿主在**场地中心**、用 `LayerConfig.SPELL_BG`；场景里的 (0,0) 就是场地正中
func test_layout_and_layer():
	var layer := _mk_layer()
	assert_eq(layer.position, Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y),
		"宿主在场地中心（作者场景的 (0,0) = 场地正中）")
	assert_eq(layer.z_index, LayerConfig.SPELL_BG, "用 LayerConfig.SPELL_BG")
	assert_lt(layer.z_index, LayerConfig.PLAYER_BULLET, "在自机子弹之下")
	assert_lt(layer.z_index, LayerConfig.SPELL_PORTRAIT, "在符卡立绘之下")
	assert_false(layer.visible, "默认隐藏（等 apply）")


## clear()：淡出后隐藏 + 释放实例
func test_clear_fades_out_and_frees():
	var layer := _mk_layer()
	layer.apply(_phase(1), _mk_scene())
	await wait_seconds(0.5)
	layer.clear()
	assert_true(layer.visible, "渐隐期间先别急着隐藏")
	await wait_seconds(0.5)
	assert_false(layer.visible, "淡完隐藏")
	assert_eq(layer.get_child_count(), 0, "实例已释放")


## 淡出**没走完**又回到同一张 → 复用同一个实例，只把透明度拉回来
func test_resume_same_scene_reuses_instance():
	var layer := _mk_layer()
	var scene := _mk_scene()
	layer.apply(_phase(1), scene)
	await wait_seconds(0.5)
	var inst: Node = layer.get_child(0)

	layer.clear()
	await wait_seconds(0.1)           # 淡出中途
	layer.apply(_phase(1), scene)     # 又打了一张（同 Boss）
	await wait_seconds(0.5)
	assert_same(layer.get_child(0), inst, "中途折返应复用实例，不重建")
	assert_almost_eq(layer.modulate.a, 1.0, 0.01, "又淡回来")


## 滚动层：窗口**下移** = 画面向上滚；对图高取模 → 循环处无缝、不会越滚越远
func test_scroll_moves_window_down_and_wraps():
	var sprite := _mk_scroll()
	sprite.set_process(false)                  # 手动步进，避免与自动 _process 打架
	var y0: float = sprite.region_rect.position.y
	sprite._process(1.0)
	assert_almost_eq(sprite.region_rect.position.y, y0 + sprite.scroll_speed, 0.01,
		"窗口按 scroll_speed 下移 = 画面向上滚")
	for i in 200:
		sprite._process(1.0)
	assert_between(sprite.region_rect.position.y, 0.0, float(sprite.texture.get_height()),
		"取模后始终在 [0, 图高) 内（无缝循环）")


## 无缝的两个前提 + 速度可调（0 = 静止；每层各调各的 ⇒ 视差）
func test_scroll_ready_sets_repeat_and_window_and_speed():
	var sprite := _mk_scroll()
	assert_eq(sprite.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "开启重复采样")
	assert_true(sprite.region_enabled, "用 region 当滚动窗口")
	assert_eq(sprite.region_rect.size, sprite.texture.get_size(), "窗口 = 整张图")
	assert_true(sprite.is_processing(), "非 0 速度 → 自动滚")

	sprite.scroll_speed = 0.0
	sprite._ready()
	assert_false(sprite.is_processing(), "速度 0 = 静止（不再吃帧）")


## 模板场景可用性（防它烂掉）：Sprite2D + 滚动脚本 + 居中原点
func test_plain_template_usable():
	var tpl := PLAIN_TEMPLATE.instantiate()
	add_child_autofree(tpl)
	assert_true(tpl is SpellBackdropScroll, "模板根应是贴着滚动脚本的 Sprite2D")
	assert_true((tpl as Sprite2D).centered, "以中心定位（图心落在宿主原点 = 场地正中）")
