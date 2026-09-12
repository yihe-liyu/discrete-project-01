extends GutTest
## W4b-1：PlayerResources 抽取 + GameState 转发（186 引用零改动）。

func after_each() -> void:
	GameState.reset_all()


func test_game_state_owns_single_resources() -> void:
	assert_not_null(GameState.resources, "GameState 应持有单一 PlayerResources")
	assert_true(GameState.resources is PlayerResources, "类型正确")


func test_property_read_write_forwards() -> void:
	GameState.lives = 5
	assert_eq(GameState.resources.lives, 5, "写入应转发到 resources")
	GameState.resources.lives = 7
	assert_eq(GameState.lives, 7, "读取应取同一真源")
	GameState.memory_value = 33.0
	assert_almost_eq(GameState.resources.memory_value, 33.0, 0.001, "memory 转发")


func test_methods_delegate_to_resources() -> void:
	GameState.resources.reset_all()
	GameState.add_memory(10.0)
	assert_almost_eq(GameState.resources.memory_value, 60.0, 0.001, "add_memory 改 resources")
	GameState.add_score(123)
	assert_eq(GameState.resources.current_score, 123, "add_score 改 resources")
	GameState.collect_bomb_fragment()
	assert_eq(GameState.resources.bomb_fragments, 1, "碎片改 resources")


func test_reset_forwards() -> void:
	GameState.resources.lives = 0
	GameState.resources.power_raw = 300
	GameState.reset_all()
	assert_eq(GameState.lives, 2, "reset_all 回初始命数")
	assert_eq(GameState.power_raw, 0, "reset_all 回初始火力")
