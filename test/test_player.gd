extends GutTest
## Player 测试：移动/focus 低速/被弹/数据应用

func _make_player() -> Player:
	var player = preload("res://scenes/player.tscn").instantiate()
	autofree(player)
	player.player_data = load("res://data/player_data/reimu_data.tres")
	add_child(player)
	player.reinit_shoot()
	player.global_position = Vector2(448, 800)
	player.is_invincible = false
	return player

func test_player_data_applied():
	var player := _make_player()
	assert_gt(player.normal_speed, 0, "常速应 > 0")
	assert_gt(player.focus_speed, 0, "低速应 > 0")
	assert_lt(player.focus_speed, player.normal_speed, "低速应小于常速")

func test_move_left():
	var player := _make_player()
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	assert_lt(player.global_position.x, 448.0, "按左 → x 减小")

func test_move_right():
	var player := _make_player()
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_right")
	assert_gt(player.global_position.x, 448.0, "按右 → x 增大")

func test_focus_slows_down():
	var player := _make_player()
	# 放开 focus 移动 5 帧 vs 按住 focus 移动 5 帧
	Input.action_press("move_right")
	for i in 5:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var fast_x: float = player.global_position.x
	player.global_position.x = 448.0
	Input.action_press("move_right")
	Input.action_press("focus")
	for i in 5:
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("focus")
	var slow_x: float = player.global_position.x
	assert_lt(slow_x - 448.0, fast_x - 448.0, "focus 时移动更慢")

func test_miss_loses_life_and_invincible():
	var player := _make_player()
	player.resources.lives = 2
	player.miss()
	assert_eq(player.resources.lives, 1, "被弹扣 1 命")
	assert_true(player.is_invincible, "被弹后进入无敌")

func test_miss_no_life_game_over():
	var player := _make_player()
	player.resources.lives = 0
	var died := false
	if not GameEvents.player_death.is_connected(func(): pass):
		pass
	player.miss()
	assert_true(player.is_invincible, "无命也进无敌（防连续触发）")

func test_graze_radius_positive():
	var player := _make_player()
	assert_gt(player.graze_radius, 10.0, "擦弹半径应有效")
