extends GutTest
## Player 测试：移动/focus 低速/被弹/数据应用
## 机体数据用**自建夹具**（机制测试不绑内容 —— 见 docs/TEST_INDEX.md「内容绑定契约」）。

const FIXTURES = preload("res://test/fixtures/fixture_lib.gd")


## 夹具机体 A / B：**两个不同实例** —— 「换机体要重建 shoot」验的是新实例（脚本可同）。
func _mech_a() -> PlayerData:
	return FIXTURES.player_data(6, 2)


func _mech_b() -> PlayerData:
	return FIXTURES.player_data(10, 4)


func _make_player() -> Player:
	var player = preload("res://scenes/player.tscn").instantiate()
	autofree(player)
	player.player_data = _mech_a()
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


func test_setup_character_same_is_idempotent():
	var player := _make_player()
	var shoot := player._player_shoot_script
	assert_not_null(shoot, "自举后应已有射击脚本")
	player.setup_character(player.player_data)
	assert_eq(player._player_shoot_script, shoot, "同机体重复 setup 不应重建射击脚本（避免组合根重复初始化）")


func test_setup_character_switches_rebuilds_shoot():
	var player := _make_player()
	var shoot := player._player_shoot_script
	var other := _mech_b()
	player.setup_character(other)
	assert_ne(player._player_shoot_script, shoot, "换机体应重建射击脚本")
	# 身份断言，不写死资源路径（路径是内容的易变属性）
	assert_eq(player.player_data, other, "player_data 应切到新机体")

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
	player.miss()
	assert_true(player.is_invincible, "无命也进无敌（防连续触发）")

func test_graze_radius_positive():
	var player := _make_player()
	assert_gt(player.graze_radius, 10.0, "擦弹半径应有效")
