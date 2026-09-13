extends GutTest
## PlayerResources 数值系统测试（不经全局转发）：分数/火力/记忆/残机/Bomb

var _player_resources: PlayerResources

func before_each():
	_player_resources = PlayerResources.new()
	_player_resources.reset_all()

## ── 分数 ──

func test_score_accumulates():
	_player_resources.add_score(100)
	_player_resources.add_score(250)
	assert_eq(_player_resources.current_score, 350, "分数应累加")

func test_max_point_increments_score():
	var pts := _player_resources.add_max_point()
	assert_eq(pts, 10000, "首次捡点 = 当前 max_point")
	assert_eq(_player_resources.max_point, 10010, "max_point 每次 +10")
	assert_eq(_player_resources.current_score, 10000, "分数立即入账")

## ── 火力 ──

func test_power_float():
	assert_eq(_player_resources.get_power_float(), 1.0, "power 0 = 1.00")
	_player_resources.add_power(100)
	assert_eq(_player_resources.get_power_float(), 2.0, "power 100 = 2.00")
	_player_resources.add_power(200)
	assert_eq(_player_resources.get_power_float(), 4.0, "power 300 = 4.00（上限）")

func test_power_penalty():
	_player_resources.add_power(100)
	_player_resources.on_miss_power_penalty()
	assert_eq(_player_resources.power_raw, 50, "被弹 -50 power")
	_player_resources.on_miss_power_penalty()
	assert_eq(_player_resources.power_raw, 0, "被弹到 0 不再降")

## ── 记忆值 ──

func test_memory_clamped():
	_player_resources.memory_value = 10.0
	_player_resources.add_memory(200.0)
	assert_eq(_player_resources.memory_value, 100.0, "记忆值上限 100")
	_player_resources.reduce_memory(500.0)
	assert_eq(_player_resources.memory_value, 0.0, "记忆值下限 0")

## ── 残机 ──

func test_life_fragments_combine():
	_player_resources.lives = 1
	for i in 4:
		_player_resources.collect_life_fragment()
	assert_eq(_player_resources.life_fragments, 4, "4 片未合成")
	_player_resources.collect_life_fragment()
	assert_eq(_player_resources.life_fragments, 0, "第 5 片合成清空")
	assert_eq(_player_resources.lives, 2, "合成 +1 命")

func test_life_cap():
	_player_resources.lives = 8
	_player_resources.collect_life_full()
	assert_eq(_player_resources.lives, 8, "命上限 8")

func test_lose_life():
	_player_resources.lives = 2
	assert_true(_player_resources.lose_life(), "有命时被弹返回 true")
	assert_eq(_player_resources.lives, 1, "扣 1 命")
	_player_resources.lives = 0
	assert_false(_player_resources.lose_life(), "无命时返回 false")
	assert_eq(_player_resources.lives, 0, "不会负数")

## ── Bomb ──

func test_bomb_fragments_combine():
	_player_resources.bomb_count = 1
	for i in 4:
		_player_resources.collect_bomb_fragment()
	assert_eq(_player_resources.bomb_fragments, 4, "4 片未合成")
	_player_resources.collect_bomb_fragment()
	assert_eq(_player_resources.bomb_fragments, 0, "第 5 片合成清空")
	assert_eq(_player_resources.bomb_count, 2, "合成 +1 Bomb")

func test_bomb_cap():
	_player_resources.bomb_count = 8
	for i in 5:
		_player_resources.collect_bomb_fragment()
	assert_eq(_player_resources.bomb_count, 8, "Bomb 上限 8")

## ── 复位 ──

func test_reset_all():
	_player_resources.current_score = 99999
	_player_resources.power_raw = 300
	_player_resources.lives = 8
	_player_resources.reset_all()
	assert_eq(_player_resources.current_score, 0, "分数复位")
	assert_eq(_player_resources.power_raw, 0, "火力复位")
	assert_eq(_player_resources.lives, 2, "命复位 2")
	assert_eq(_player_resources.bomb_count, 3, "Bomb 复位 3")
