extends GutTest
## Boss 位置指示器回归测试：生成/跟随 x/框外对齐/随 Boss 销毁

func test_boss_indicator_follows_boss():
	# 测试环境需要 UI 层（游戏里是 game_scene 的 "UI" CanvasLayer layer=32）
	var ui := CanvasLayer.new()
	ui.name = "UI"
	get_tree().root.add_child(ui)
	autofree(ui)

	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child(boss)
	boss.start_boss()

	var indicator: Sprite2D = boss._pos_indicator
	assert_not_null(indicator, "start_boss 后应创建指示器")
	if indicator == null:
		return

	# 挂 UI 层（层级高于游戏元素）
	assert_eq(indicator.get_parent(), ui, "指示器应挂在 UI 层")

	# x 跟随 Boss（y 固定）
	boss.global_position = Vector2(300, 150)
	boss._process(0.016)
	assert_eq(indicator.global_position.x, 300.0, "指示器 x 应跟随 Boss")

	# y 在游戏框底线之下（完全在框外，贴图中心 = FIELD_BOTTOM + 半高）
	var expected_y: float = GameConfig.FIELD_BOTTOM + indicator.texture.get_height() / 2.0
	assert_eq(indicator.global_position.y, expected_y, "指示器 y 应在游戏框底线之下（框外）")

	# Boss 移动后指示器 x 继续跟随
	boss.global_position = Vector2(600, 400)
	boss._process(0.016)
	assert_eq(indicator.global_position.x, 600.0, "指示器 x 应持续跟随 Boss")
	assert_eq(indicator.global_position.y, expected_y, "指示器 y 应保持不变")

	# Boss 销毁 → 指示器删除
	boss.queue_free()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(indicator), "Boss 销毁后指示器应被删除")


func test_boss_indicator_alpha_fades_with_distance():
	# 测试环境需要 UI 层 + 假玩家
	var ui := CanvasLayer.new()
	ui.name = "UI"
	get_tree().root.add_child(ui)
	autofree(ui)
	var fake_player := Player.new()
	fake_player.global_position = Vector2(448, 800)
	# 注意：不 add_child（Player._ready 依赖场景子节点，裸 new 进树会报错）；
	# 未进树时 global_position == position，足够测 alpha
	var refs := EntityRegistry.new()
	refs.bind_player(fake_player)

	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	boss.registry = refs
	boss.start_boss()
	var indicator: Sprite2D = boss._pos_indicator
	assert_not_null(indicator, "start_boss 后应创建指示器")
	if indicator == null:
		return

	# 自机与 Boss 同 x → 最淡
	boss.global_position = Vector2(448, 200)
	boss._process(0.016)
	assert_almost_eq(indicator.modulate.a, 0.25, 0.01, "同 x 时指示器应最淡")

	# 自机远离 Boss（dx > 400）→ 完全清晰
	boss.global_position = Vector2(1100, 200)  # dx = 652 > 400
	boss._process(0.016)
	assert_eq(indicator.modulate.a, 1.0, "远离时指示器应完全清晰")

	# 中间距离 → 缓动过渡（pow 0.5：越近透明得越快）
	boss.global_position = Vector2(448 + 260.0, 200)  # dx=260，t=(260-60)/340≈0.588 → pow=0.767
	boss._process(0.016)
	var expected_a: float = 0.25 + (1.0 - 0.25) * pow((260.0 - 60.0) / (400.0 - 60.0), 0.5)
	assert_almost_eq(indicator.modulate.a, expected_a, 0.01, "中间距离应缓动过渡")

	# 还原
	fake_player.free()


func test_indicator_follows_after_die():
	# Boss 击破后（外部控制离场，不 queue_free）：指示器仍应跟随 Boss 移动
	var ui := CanvasLayer.new()
	ui.name = "UI"
	get_tree().root.add_child(ui)
	autofree(ui)

	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	boss.start_boss()
	var indicator: Sprite2D = boss._pos_indicator
	assert_not_null(indicator, "start_boss 后应创建指示器")
	if indicator == null:
		return

	boss.set_exit_controlled()  # 离场演出由外部控制 → 不 queue_free
	boss.die()
	boss.global_position = Vector2(700, 300)
	boss._process(0.016)
	assert_eq(indicator.global_position.x, 700.0, "死后离场移动指示器仍应跟随")
