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


func after_each() -> void:
	# 安全阀：任何用例把"被弹炸弹"窗口留在半开状态，都不能污染后面的用例（time_scale 卡 0 会冻住整个套件）
	Engine.time_scale = 1.0


## 直接把这次 miss 结算到底：**先清空雷**，不给被弹炸弹窗口机会。
## 关心"miss 的后果"的用例用它；窗口本身的行为另有专门用例。
func _miss_now(player: Player) -> void:
	player.resources.bomb_count = 0
	player.miss()


## 合成一次 "cancel&bomb" 按键事件（R4：bomb 走 `_unhandled_input`，测试就直接喂事件）
func _bomb_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "cancel&bomb"
	ev.pressed = true
	return ev

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
	_miss_now(player)
	assert_eq(player.resources.lives, 1, "被弹扣 1 命")
	assert_true(player.is_invincible, "被弹后进入无敌")

func test_miss_no_life_game_over():
	var player := _make_player()
	player.resources.lives = 0
	_miss_now(player)
	assert_true(player.is_invincible, "无命也进无敌（防连续触发）")


## Miss 削火力（原作口径）：`on_miss_power_penalty()` 必须真的接在 miss 路径上
func test_miss_applies_power_penalty():
	var player := _make_player()
	player.resources.power_raw = 300
	_miss_now(player)
	assert_eq(player.resources.power_raw, 250, "miss 应削 50 火力")


## 无舞台 ctx（单测 / 非关卡场景）时：扣火力照常，撒点分支安全跳过（不崩）
func test_miss_without_ctx_is_safe():
	var player := _make_player()
	assert_null(player.ctx, "夹具没有 ctx")
	player.resources.power_raw = 100
	_miss_now(player)
	assert_eq(player.resources.power_raw, 50, "无 ctx 也照常削火力")
	assert_true(player.is_invincible, "无 ctx 也照常进无敌")


## Miss 补偿：**直接 +2 个完整雷**（作者："不用掉落物，直接加"）—— 且**雷碎片那条线不动**
func test_miss_grants_two_bombs_without_touching_fragments():
	var player := _make_player()
	player.resources.bomb_count = 1
	player.resources.bomb_fragments = 3
	player.miss()   # 不能用 `_miss_now`（它为了绕开窗口会先把雷清零）
	assert_eq(player.resources.bomb_count, 1 + Player.MISS_BOMB_GAIN, "miss 直接补 2 个雷（不撒道具）")
	assert_eq(player.resources.bomb_fragments, 3, "雷碎片不动（碎片是另一条线）")


## 补偿受上限约束：到 `MAX_BOMBS` 就停住，不越界
func test_miss_bomb_gain_respects_cap():
	var player := _make_player()
	player.resources.bomb_count = PlayerResources.MAX_BOMBS - 1
	player.miss()   # 夹具没配 `PlayerData.bomb` → 不会开被弹炸弹窗口
	assert_eq(player.resources.bomb_count, PlayerResources.MAX_BOMBS,
			"补到 %d 封顶" % PlayerResources.MAX_BOMBS)


## 被弹炸弹**抵消**掉的那次不算 miss ⇒ **不发补偿**（没真的被弹，不能白拿雷）
func test_deathbomb_cancel_grants_no_bomb_compensation():
	var player := _make_player()
	_arm_bomb(player)
	player.resources.bomb_count = 4
	player.miss()
	player._unhandled_input(_bomb_event())
	assert_eq(player.resources.bomb_count, 4 - Player.DEATHBOMB_COST, "只付被弹炸弹的代价，不补")


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

	_miss_now(player)
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
	_miss_now(player)
	assert_eq(player.global_position, Player.MISS_RESPAWN_FROM, "第一次先瞬移到框下")

	player.is_invincible = false          # 允许再中一次
	player.global_position = Vector2(600, 300)
	_miss_now(player)
	assert_eq(player.global_position, Player.MISS_RESPAWN_FROM, "第二次也先瞬移到框下（同一处）")
	assert_eq(player._respawn_pos, Vector2(448, 840), "复位点不变")

func test_graze_radius_positive():
	var player := _make_player()
	assert_gt(player.graze_radius, 10.0, "擦弹半径应有效")


# ═══ 被弹炸弹（deathbomb）：被弹瞬间定格几帧，按 bomb 抢命 ═══

## 夹具机体默认没配雷（真机体在 `PlayerData.bomb` 的 .tres 里），这里补上
func _arm_bomb(player: Player) -> void:
	player.player_data.bomb = BombData.new()


## 有雷 → 被弹先**定格开窗**：命 / 雷 / miss 副作用全部还没发生
func test_deathbomb_window_freezes_before_any_miss_effect():
	var player := _make_player()
	_arm_bomb(player)
	watch_signals(GameEvents)
	player.resources.lives = 3
	player.resources.bomb_count = 3
	player.resources.power_raw = 300

	player.miss()
	assert_true(player._is_deathbombing, "开窗：进入被弹炸弹窗口")
	assert_eq(Engine.time_scale, 0.0, "定格：全局暂停几帧（time_scale = 0）")
	assert_eq(player.resources.lives, 3, "窗口里还没掉命")
	assert_eq(player.resources.bomb_count, 3, "窗口里还没扣雷")
	assert_eq(player.resources.power_raw, 300, "窗口里还没削火力")
	assert_signal_not_emitted(GameEvents, "player_missed", "窗口里还不算 miss")
	Engine.time_scale = 1.0   # 别把定格留给下一个用例（after_each 兜底）


## 窗口里按 bomb → 抵消这次 miss：花 2 个雷、掉 0 命、炸弹照放、定格解开
func test_deathbomb_press_cancels_miss_and_costs_two_bombs():
	var player := _make_player()
	_arm_bomb(player)
	watch_signals(GameEvents)
	player.resources.lives = 3
	player.resources.bomb_count = 3

	player.miss()
	player._unhandled_input(_bomb_event())
	assert_eq(player.resources.bomb_count, 1, "抵消 miss 花 2 个雷")
	assert_eq(player.resources.lives, 3, "不掉命")
	assert_false(player._is_deathbombing, "窗口关闭")
	assert_eq(Engine.time_scale, 1.0, "定格解开")
	assert_true(player.is_invincible, "炸弹的无敌照给")
	assert_signal_emitted(GameEvents, "player_bomb", "照常放炸弹")
	assert_signal_not_emitted(GameEvents, "player_missed", "没发生 miss")


## 只剩 1 个雷也给窗口（DEATHBOMB_MIN_BOMBS），且**只扣 1 个**
func test_deathbomb_with_single_bomb_costs_one():
	var player := _make_player()
	_arm_bomb(player)
	player.resources.lives = 3
	player.resources.bomb_count = 1

	player.miss()
	assert_true(player._is_deathbombing, "只有 1 个雷也开窗")
	player._unhandled_input(_bomb_event())
	assert_eq(player.resources.bomb_count, 0, "只剩 1 个 → 只扣 1 个")
	assert_eq(player.resources.lives, 3, "不掉命")


## 没雷 → 不开窗、不定格，miss 立即结算
func test_no_deathbomb_window_without_bombs():
	var player := _make_player()
	_arm_bomb(player)
	player.resources.lives = 3
	player.resources.bomb_count = 0

	player.miss()
	assert_false(player._is_deathbombing, "没雷不开窗")
	assert_eq(player.resources.lives, 2, "直接掉命")
	assert_eq(Engine.time_scale, 1.0, "不定格")


## 窗口到点没按 bomb → 这次 miss 照常结算（掉命、**不扣雷**（还倒给 miss 补偿 +2）、定格解开）
func test_deathbomb_window_expiry_applies_miss():
	var player := _make_player()
	_arm_bomb(player)
	watch_signals(GameEvents)
	player.resources.lives = 3
	player.resources.bomb_count = 3

	player.miss()
	for _i in Player.DEATHBOMB_FRAMES + 6:
		await get_tree().physics_frame
	assert_eq(player.resources.lives, 2, "窗口过期 → 掉命")
	assert_eq(player.resources.bomb_count, 3 + Player.MISS_BOMB_GAIN,
			"没按 bomb → 不扣雷；miss 补偿照给（+%d）" % Player.MISS_BOMB_GAIN)
	assert_eq(Engine.time_scale, 1.0, "定格解开")
	assert_signal_emitted(GameEvents, "player_missed", "这才是真的 miss")
	assert_signal_emitted(GameEvents, "deathbomb_ended", "窗口结束信号（滤镜渐隐靠它）")


## 回归（作者实测）：窗口里按暂停 → 既没有暂停菜单、也解不开暂停。
## 病根 = 窗口收尾挂在被定格/暂停卡住的帧循环上 → `time_scale` 永远回不来。
## 现在收尾走**真实时间**计时器，暂停中也照走完并还回 `time_scale`。
func test_deathbomb_window_finishes_even_while_paused():
	var player := _make_player()
	_arm_bomb(player)
	player.resources.lives = 3
	player.resources.bomb_count = 3

	player.miss()
	get_tree().paused = true   # 模拟"窗口内按了暂停"
	for _i in Player.DEATHBOMB_FRAMES + 6:
		await get_tree().physics_frame
	get_tree().paused = false  # 先解开，别把暂停状态漏给下一个用例

	assert_false(player._is_deathbombing, "暂停中也照走完窗口")
	assert_eq(Engine.time_scale, 1.0, "定格必须还回去（否则暂停菜单被一起冻住）")
	assert_eq(player.resources.lives, 2, "没按 bomb → miss 照常结算")


# ═══ 无敌时长 & 闪烁 ═══

## 契约：有残机 = 固定时长；残机归零 = **跟着 DEATH_MENU_DELAY 走**（菜单延迟调大，无敌自动跟上）
func test_miss_invincible_time_links_to_death_menu_delay():
	assert_eq(Player.miss_invincible_time(false), Player.MISS_INVINCIBLE_TIME, "有残机用固定值")
	var dead_time := Player.miss_invincible_time(true)
	assert_true(dead_time >= Player.MISS_INVINCIBLE_TIME, "残机归零不低于固定值")
	assert_true(dead_time >= GameConfig.DEATH_MENU_DELAY + Player.MISS_DEATH_INVINCIBLE_MARGIN,
			"残机归零：无敌必须盖住等 Game Over 菜单的时间")


## 无敌闪烁：只动机体贴图 alpha，判定点/枪口不动；无敌一结束立刻恢复不透明
func test_invincible_blink_toggles_ship_sprite_only():
	var player := _make_player()
	player.is_invincible = true
	player._invincible_timer = 10.0
	var half := 0.5 / Player.INVINCIBLE_BLINK_HZ
	var hpd_alpha: float = player._hit_point_display.modulate.a

	player._update_invincible_blink(half * 0.5)   # 落在暗半周期
	assert_almost_eq(player.animation.modulate.a, Player.INVINCIBLE_BLINK_MIN_ALPHA, 0.001,
			"暗时用 BLINK_MIN_ALPHA")
	assert_eq(player._hit_point_display.modulate.a, hpd_alpha, "判定点自管 focus 淡入淡出，不被闪烁干扰")

	player._update_invincible_blink(half * 1.2)   # 跨进亮半周期
	assert_almost_eq(player.animation.modulate.a, 1.0, 0.001, "亮时完全不透明")

	player.is_invincible = false
	player._update_invincible_blink(half)
	assert_almost_eq(player.animation.modulate.a, 1.0, 0.001, "无敌结束后恢复不透明")
