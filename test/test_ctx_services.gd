extends GutTest
## ctx.* 服务（BossService / DifficultyService）纯逻辑测试：无树，校验"查询/按难度取值"。
## 直接测服务类（内容经由 ctx.boss / ctx.diff 触达它们）。

const BossService = preload("res://scripts/coroutine/services/boss_service.gd")
const DifficultyService = preload("res://scripts/coroutine/services/difficulty_service.gd")

func test_boss_service_no_boss():
	var s := BossService.new()
	assert_null(s.current(), "无活动 Boss 时 current 应为 null")
	assert_false(s.exists(), "无活动 Boss 时 exists 应为 false")

func test_diff_service_picks_by_difficulty():
	var orig := int(GameState.selected_difficulty)
	GameState.selected_difficulty = 2
	var s := DifficultyService.new()
	assert_eq(s.picked(), 2, "picked 应返回当前难度")
	assert_eq(s.pick([1, 3, 5, 8]), 5, "arr[2] 应为 5")
	assert_true(s.at_least(2), "难度 2 应 at_least(2)")
	assert_true(s.at_least(1), "难度 2 应 at_least(1)")
	assert_false(s.at_least(3), "难度 2 不应 at_least(3)")
	assert_eq(s.pick_from({0: {"a": 1}, 2: {"a": 9}}, "a", 0), 9, "字典按难度取值")
	GameState.selected_difficulty = orig

func test_diff_service_at_least_lunatic():
	var orig := int(GameState.selected_difficulty)
	GameState.selected_difficulty = 3
	var s := DifficultyService.new()
	assert_true(s.at_least(3), "Lunatic 应 at_least(3)")
	assert_false(s.at_least(4), "Lunatic 不应 at_least(4)")
	GameState.selected_difficulty = orig
