extends GutTest
## 符卡背景（**每 Boss 一张**，只在符卡期间显示）。
## 判定抽成纯函数 → 机制测试不绑内容；显隐用夹具图（PlaceholderTexture2D）。

const BACKDROP := preload("res://scripts/scenes/spell_backdrop.gd")


func _phase(uid: int) -> PhaseData:
	var p := PhaseData.new()
	p.uid = uid
	p.hp = 1000
	p.time_limit = 30.0
	return p


func _boss(tex: Texture2D) -> BossData:
	var b := BossData.new()
	b.boss_name = "夹具"
	b.spell_background = tex
	return b


## 场地尺寸（768×896）的占位图 —— 尺寸本身不参与判定，形状与真图一致而已
func _tex() -> Texture2D:
	var t := PlaceholderTexture2D.new()
	t.size = Vector2(768.0, 896.0)
	return t


func _mk():
	var node = BACKDROP.new()
	add_child_autofree(node)
	return node


## 判据：**符卡才显示**；非符 / 无阶段不显示（「有没有图」由调用方保证，见下一条）
func test_should_show_rule():
	assert_true(BACKDROP.should_show(_phase(1)), "符卡 → 显示")
	assert_false(BACKDROP.should_show(_phase(0)), "**非符 → 不显示**")
	assert_false(BACKDROP.should_show(null), "无阶段 → 不显示")


## apply() 真的挂上图 / 淡出摘掉；没图或非符都不显示
func test_apply_shows_then_clears():
	var node = _mk()
	var tex := _tex()
	node.apply(_phase(1), tex)
	assert_true(node.visible, "符卡 + 有图 → 显示")
	assert_eq(node.texture, tex, "挂的是这张图")
	node.apply(_phase(1), null)          # Boss 没配图
	await wait_seconds(0.5)              # 等淡出 tween 走完
	assert_false(node.visible, "没图 → 隐藏")
	node.apply(_phase(1), tex)
	await wait_seconds(0.4)
	node.apply(_phase(0), tex)           # 非符：即便有图也不显示
	await wait_seconds(0.5)
	assert_false(node.visible, "非符 → 淡出隐藏")


## 同一张图重复 apply 不重放淡入（连着两张符卡不闪）
func test_same_texture_does_not_refade():
	var node = _mk()
	var tex := _tex()
	node.apply(_phase(1), tex)
	await wait_seconds(0.4)
	assert_almost_eq(node.modulate.a, 1.0, 0.01, "淡入完成")
	node.apply(_phase(2), tex)   # 换阶段、同图
	assert_almost_eq(node.modulate.a, 1.0, 0.01, "同图不重播淡入")


## 摆放：居中于场地、不缩放、夹在 3D 背景与弹幕之间
func test_layout_matches_field():
	var node = _mk()
	assert_eq(node.position, Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y), "居中于场地")
	assert_true(node.centered, "以中心定位")
	assert_eq(node.scale, Vector2.ONE, "不缩放（图按场地尺寸画）")
	assert_eq(node.z_index, LayerConfig.SPELL_BG, "用 LayerConfig.SPELL_BG")
	assert_lt(node.z_index, LayerConfig.PLAYER_BULLET, "在自机子弹之下")


## 向上滚动：窗口**下移** = 画面向上滚；对图高取模 → 循环处无缝、不会越滚越远
func test_scroll_moves_window_down_and_wraps():
	var node = _mk()
	var tex := _tex()
	node.apply(_phase(1), tex)
	node.set_process(false)                     # 手动步进，避免与自动 _process 打架
	var y0: float = node.region_rect.position.y
	node._process(1.0)
	assert_almost_eq(node.region_rect.position.y, y0 + BACKDROP.SCROLL_SPEED, 0.01,
		"窗口按速度下移 = 画面向上滚")
	for i in 200:
		node._process(1.0)
	assert_between(node.region_rect.position.y, 0.0, tex.get_height(),
		"取模后始终在 [0, 图高) 内（无缝循环）")


## 无缝的两个前提：重复采样 + 窗口恒为**场地尺寸**（不溢出场外）
func test_seamless_requires_repeat_and_field_sized_window():
	var node = _mk()
	assert_eq(node.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "开启重复采样")
	node.apply(_phase(1), _tex())
	assert_true(node.region_enabled, "用 region 当滚动窗口")
	assert_eq(node.region_rect.size,
		Vector2(GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
			GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP),
		"窗口 = 场地尺寸")
