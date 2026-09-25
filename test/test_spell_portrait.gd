extends GutTest
## 宣言立绘（Boss 符卡 右上→左下 / 自机 Bomb 左下→右上）：层级 + 起点 + **行进方向** + 淡出。
## ⚠️ **不锁具体坐标** —— 那两个角是作者会调的（曾把端点外扩到框外、时长也改过）；
##    锁的是「从哪个常量起 + 朝哪边走」，这样调手感时测试不会白红。

const PORTRAIT := preload("res://scripts/scenes/spell_portrait.gd")


func _tex() -> Texture2D:
	var t := PlaceholderTexture2D.new()
	t.size = Vector2(400.0, 700.0)
	return t


func _mk():
	var node = PORTRAIT.new()
	add_child_autofree(node)
	return node


## 层级：符卡背景之上、自机子弹之下（不挡读弹幕）
func test_layer_between_backdrop_and_bullets():
	var node = _mk()
	assert_eq(node.z_index, LayerConfig.SPELL_PORTRAIT, "用 LayerConfig.SPELL_PORTRAIT")
	assert_gt(node.z_index, LayerConfig.SPELL_BG, "在符卡背景之上")
	assert_lt(node.z_index, LayerConfig.PLAYER_BULLET, "在自机子弹之下")


## Boss 符卡：从**右上角常量**起，朝左下走（x 减小、y 增大）
func test_boss_sweep_goes_top_right_to_bottom_left():
	var node = _mk()
	node.sweep(_tex())
	assert_true(node.visible, "起跑即显示")
	assert_not_null(node.texture, "挂上图")
	assert_eq(node.global_position, PORTRAIT.CORNER_TOP_RIGHT, "起点 = 脚本自己的右上角常量")
	await wait_physics_frames(6)
	var p: Vector2 = node.global_position
	assert_lt(p.x, PORTRAIT.CORNER_TOP_RIGHT.x, "朝左下：x 减小")
	assert_gt(p.y, PORTRAIT.CORNER_TOP_RIGHT.y, "朝左下：y 增大")


## 自机 Bomb：从**左下角常量**起，朝右上走（镜像）
func test_bomb_sweep_goes_bottom_left_to_top_right():
	var node = _mk()
	node.sweep_from_bottom_left(_tex())
	assert_eq(node.global_position, PORTRAIT.CORNER_BOTTOM_LEFT, "起点 = 脚本自己的左下角常量")
	await wait_physics_frames(6)
	var p: Vector2 = node.global_position
	assert_gt(p.x, PORTRAIT.CORNER_BOTTOM_LEFT.x, "朝右上：x 增大")
	assert_lt(p.y, PORTRAIT.CORNER_BOTTOM_LEFT.y, "朝右上：y 减小")


## 扫完淡出隐藏（时长取脚本常量，不写死）
func test_sweep_ends_hidden():
	var node = _mk()
	node.sweep(_tex())
	await wait_seconds(PORTRAIT.SWEEP_SEC + PORTRAIT.FADE_SEC + 0.4)
	assert_false(node.visible, "扫完 + 淡出 → 隐藏")
	assert_almost_eq(node.modulate.a, 0.0, 0.01, "淡出到全透明")


## 空图不显示；扫场中重复调用被忽略（不叠两条 tween）
func test_sweep_guards():
	var node = _mk()
	node.sweep(null)
	assert_false(node.visible, "空图不显示")
	node.sweep(_tex())
	assert_eq(node.global_position, PORTRAIT.CORNER_TOP_RIGHT, "第一遍从右上角常量起")
	node.sweep(_tex())
	assert_eq(node.global_position, PORTRAIT.CORNER_TOP_RIGHT, "第二遍被忽略（没重置位置）")
