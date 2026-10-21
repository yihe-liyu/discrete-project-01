extends GutTest
## 难度维度契约：0..4、展示名、diff_pick / diff_get 的边界与 Extra 越界守卫。

const DIFFICULTY_SERVICE = preload("res://scripts/coroutine/services/difficulty_service.gd")

var _original_difficulty := Difficulty.NORMAL


func before_each() -> void:
	_original_difficulty = SaveData.selected_difficulty


func after_each() -> void:
	SaveData.selected_difficulty = _original_difficulty


func test_values_and_names_are_contiguous() -> void:
	assert_eq(Difficulty.COUNT, 5, "难度总数应为 5")
	assert_eq(Difficulty.EASY, 0, "Easy = 0")
	assert_eq(Difficulty.NORMAL, 1, "Normal = 1")
	assert_eq(Difficulty.HARD, 2, "Hard = 2")
	assert_eq(Difficulty.LUNATIC, 3, "Lunatic = 3")
	assert_eq(Difficulty.EXTRA, 4, "Extra = 4")
	assert_eq(Difficulty.display_name(Difficulty.EXTRA), "Extra", "Extra 展示名")
	assert_false(Difficulty.is_valid(-1), "负数不是合法难度")
	assert_false(Difficulty.is_valid(Difficulty.COUNT), "COUNT 不是合法难度")
	assert_eq(Difficulty.display_name(-1), "?", "非法难度显示 ?")


func test_diff_pick_uses_selected_difficulty() -> void:
	SaveData.selected_difficulty = Difficulty.HARD
	var script := CoroutineScript.new()
	autofree(script)
	assert_eq(script.diff_pick([10, 20, 30, 40, 50]), 30, "Hard 应取第 3 项")
	assert_eq(Difficulty.pick([10, 20, 30, 40, 50], Difficulty.HARD, "test"), 30, "静态入口同值")


func test_short_array_at_extra_fails_loudly_and_falls_back_to_last() -> void:
	SaveData.selected_difficulty = Difficulty.EXTRA
	assert_eq(Difficulty.pick([10, 20, 30, 40], Difficulty.EXTRA, "test"), 40,
		"4 项数组在 Extra 下回落最后一项，不能越界崩溃")
	assert_push_error("只有 4 项", "Extra 使用 4 项数组必须报错")


func test_invalid_difficulty_falls_back_to_normal() -> void:
	assert_eq(Difficulty.pick([10, 20, 30], -1, "test"), 20, "非法难度回落 Normal")
	assert_push_error("非法难度", "非法难度必须报错")


func test_diff_get_missing_row_and_bad_row() -> void:
	SaveData.selected_difficulty = Difficulty.NORMAL
	var script := CoroutineScript.new()
	autofree(script)
	assert_eq(script.diff_get({Difficulty.NORMAL: {"count": 7}}, "count", -1), 7, "Normal 行应命中")
	assert_eq(script.diff_get({Difficulty.NORMAL: {"count": 7}}, "missing", -1), -1, "缺 key 取默认")
	assert_eq(script.diff_get({Difficulty.HARD: {"count": 9}}, "count", -1), -1, "缺行取默认")
	assert_eq(script.diff_get({Difficulty.NORMAL: 5}, "count", -1), -1, "非 Dictionary 行取默认")
	assert_push_error("不是 Dictionary", "非 Dictionary 行必须报错")


func test_difficulty_service_uses_same_guard() -> void:
	var service: RefCounted = DIFFICULTY_SERVICE.new()
	SaveData.selected_difficulty = Difficulty.EXTRA
	assert_eq(service.pick([10, 20, 30, 40]), 40, "ctx.diff.pick 与 diff_pick 同一回落")
	assert_push_error("只有 4 项", "服务入口也要报错")
