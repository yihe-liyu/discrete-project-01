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


## Miss 削火力（原作口径）：`on_miss_power_penalty()` 必须真的接在 miss 路径上
func test_miss_applies_power_penalty():
	var player := _make_player()
	player.resources.power_raw = 300
	player.miss()
	assert_eq(player.resources.power_raw, 250, "miss 应削 50 火力")


## 无舞台 ctx（单测 / 非关卡场景）时：扣火力照常，撒点分支安全跳过（不崩）
func test_miss_without_ctx_is_safe():
	var player := _make_player()
	assert_null(player.ctx, "夹具没有 ctx")
	player.resources.power_raw = 100
	player.miss()
	assert_eq(player.resources.power_raw, 50, "无 ctx 也照常削火力")
	assert_true(player.is_invincible, "无 ctx 也照常进无敌")


## 契约：扇形半径必须**大于**道具吸附半径 —— 否则弧飞完那一刻就被吸走，"竖直下落"看不到
func test_miss_fan_radius_exceeds_item_pull_range():
	assert_gt(Player.MISS_POWER_RADIUS, Item.PROXIMITY_RANGE,
			"扇形半径要飞出吸附圈（否则第二段下落不可见）")


## 契约：扇形的左右夹取边界必须真的**在场地框内侧**（留白 ≥ 半张贴图，否则贴图会骑框）
func test_miss_fan_x_bounds_inside_playfield():
	var x_min := GameConfig.FIELD_LEFT + Player.MISS_POWER_MARGIN
	var x_max := GameConfig.FIELD_RIGHT - Player.MISS_POWER_MARGIN
	assert_gt(x_min, GameConfig.FIELD_LEFT, "左留白 > 0（32×32 贴图不越框）")
	assert_lt(x_max, GameConfig.FIELD_RIGHT, "右留白 > 0（32×32 贴图不越框）")
	assert_lt(x_min, x_max, "留白不能吃光整个场地")


## 中弹复位两步：① **瞬移到框下方之外**（水平正中）→ ② 移动到 `_respawn_pos`（终点），期间锁输入。
## 关键语义：`_respawn_pos` 是**终点**；**起点是框下正中**（`MISS_RESPAWN_FROM`），不是中弹位置。
func test_miss_teleports_below_field_then_moves_to_respawn_pos():
	var player := _make_player()
	player._respawn_pos = Vector2(448, 840)
	player.global_position = Vector2(500, 600)

	player.miss()
	assert_eq(player.global_position, Player.MISS_RESPAWN_FROM, "第一步：瞬移到框下方之外（正中）")
	assert_gt(player.global_position.y, GameConfig.FIELD_BOTTOM, "起点确实在场地框下方之外")
	assert_true(player._is_respawning, "第二步：复位移动已开始")

	# 锁输入：即便按住方向键、直接跑一帧移动逻辑，也不动
	Input.action_press("move_right")
	var before := player.global_position
	player.update_move(1.0)
	Input.action_release("move_right")
	assert_eq(player.global_position, before, "复位移动期间锁输入（方向键不生效）")

	await get_tree().create_timer(Player.MISS_RESPAWN_TIME + 0.25).timeout
	assert_almost_eq(player.global_position.x, player._respawn_pos.x, 0.5, "终点 = 复位点 x")
	assert_almost_eq(player.global_position.y, player._respawn_pos.y, 0.5, "终点 = 复位点 y")
	assert_false(player._is_respawning, "移动结束后解锁输入")


## 第二次中弹同样两步：仍先瞬移到框下（同一处），复位点也不变
func test_second_miss_repeats_teleport_and_respawn():
	var player := _make_player()
	player._respawn_pos = Vector2(448, 840)
	player.global_position = Vector2(200, 700)
	player.miss()
	assert_eq(player.global_position, Player.MISS_RESPAWN_FROM, "第一次先瞬移到框下")

	player.is_invincible = false          # 允许再中一次
	player.global_position = Vector2(600, 300)
	player.miss()
	assert_eq(player.global_position, Player.MISS_RESPAWN_FROM, "第二次也先瞬移到框下（同一处）")
	assert_eq(player._respawn_pos, Vector2(448, 840), "复位点不变")

func test_graze_radius_positive():
	var player := _make_player()
	assert_gt(player.graze_radius, 10.0, "擦弹半径应有效")
