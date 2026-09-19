extends GutTest
## ScreenShake：trauma（一次性冲击）按 DECAY 衰减、sustain（持续）保持到清零；强度封顶 1。
## 另测魔理沙 mist bomb：setup 持有持续震屏、释放时归零。

const MIST_BOMB := preload("res://scripts/kernel_bridge/kernel_mist_bomb.gd")

func test_add_trauma_clamps_to_one() -> void:
	var s := ScreenShake.new()
	s.add_trauma(0.4)
	assert_almost_eq(s.amount(), 0.4, 0.001)
	s.add_trauma(5.0)
	assert_almost_eq(s.amount(), 1.0, 0.001, "封顶 1")


func test_trauma_decays_to_zero() -> void:
	var s := ScreenShake.new()
	s.add_trauma(1.0)
	s._process(0.25)
	assert_almost_eq(s.amount(), 1.0 - ScreenShake.DECAY * 0.25, 0.001, "按 DECAY 线性衰减")
	s._process(10.0)
	assert_almost_eq(s.amount(), 0.0, 0.001, "最终归零")
	assert_eq(s.offset, Vector2.ZERO, "归零后位移复位")


func test_sustain_holds_until_cleared() -> void:
	var s := ScreenShake.new()
	s.set_sustain(0.3)
	s._process(5.0)
	assert_almost_eq(s.amount(), 0.3, 0.001, "持续震不随时间衰减")
	s.set_sustain(0.0)
	s._process(0.0)
	assert_almost_eq(s.amount(), 0.0, 0.001, "清零后停止")


func test_bound_layer_follows_camera_offset_negated() -> void:
	var s := ScreenShake.new()
	var layer := CanvasLayer.new()
	s.bind_layer(layer)
	s.add_trauma(1.0)
	s._process(0.0)
	assert_eq(layer.offset, -s.offset, "背景层与 Camera2D 反向同步（屏幕上同向）")
	assert_almost_eq(s.amount(), 1.0, 0.001, "此时震幅仍为 1")
	s._process(10.0)
	assert_eq(layer.offset, Vector2.ZERO, "停震后背景层归零")


func test_bomb_data_shake_defaults_off() -> void:
	var d := BombData.new()
	assert_eq(d.shake_impulse, 0.0, "默认不震（冲击）")
	assert_eq(d.shake_sustain, 0.0, "默认不震（持续）")


func test_mist_bomb_holds_and_releases_sustain() -> void:
	var data := MistBombData.new()
	data.shake_sustain = 0.5
	var bomb := MIST_BOMB.new() as BombEntity
	add_child_autofree(bomb)
	var got: Array = []
	var cb := func(v: float) -> void: got.append(v)
	GameEvents.screen_shake_sustain.connect(cb)
	bomb.setup(data, Vector2.ZERO, Vector2.DOWN)
	assert_eq(got, [0.5], "setup 时持有持续震屏")
	bomb.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameEvents.screen_shake_sustain.disconnect(cb)
	assert_eq(got, [0.5, 0.0], "释放时归零")
