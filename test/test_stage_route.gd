extends GutTest
## 难度路线：引用同一 StageData、按 route_index 推进；记录不依赖 route_index。

const EASY_STAGE1 := "res://data/stages/stage01/stage_data/stage01.tres"


func test_catalog_loads_all_difficulties_and_reuses_stage_data() -> void:
	StageRouteCatalog.load_routes()
	var easy := StageRouteCatalog.route_for(Difficulty.EASY)
	var hard := StageRouteCatalog.route_for(Difficulty.HARD)
	assert_not_null(easy)
	assert_not_null(hard)
	assert_eq(easy.stages[0].resource_path, EASY_STAGE1)
	assert_same(easy.stages[0], hard.stages[0], "不同路线应引用同一份 StageData，而不是复制资源")


func test_empty_route_is_invalid() -> void:
	var route := StageRoute.new()
	route.route_id = &"empty"
	route.difficulty = Difficulty.NORMAL
	route.stages.clear()
	assert_gt(route.validate().size(), 0)


func test_save_data_advances_route_and_ends_cleanly() -> void:
	StageRouteCatalog.load_routes()
	SaveData.reset_session()
	assert_true(SaveData.begin_route_for_difficulty(Difficulty.NORMAL))
	assert_eq(SaveData.current_route_index, 0)
	assert_eq(SaveData.current_route().stages[0].stage_id, SaveData.current_stage_id)

	var next := SaveData.advance_route()
	assert_not_null(next)
	assert_eq(SaveData.current_route_index, 1)
	assert_eq(SaveData.current_stage_id, next.stage_id)

	assert_null(SaveData.advance_route(), "路线末尾不应继续越界")
	assert_eq(SaveData.current_route_index, 1, "末尾失败不推进 index")


func test_reset_session_clears_route_but_keeps_difficulty() -> void:
	StageRouteCatalog.load_routes()
	SaveData.selected_difficulty = Difficulty.HARD
	SaveData.begin_route_for_difficulty(Difficulty.HARD)
	SaveData.reset_session()
	assert_eq(SaveData.current_route_id, &"")
	assert_eq(SaveData.current_route_index, 0)
	assert_eq(SaveData.current_stage_id, 1)
	assert_eq(SaveData.selected_difficulty, Difficulty.HARD)


func test_route_order_does_not_change_record_key() -> void:
	var book := SpellRecordBook.new()
	book.record_attempt(1, 2, 0, 0, Difficulty.NORMAL, false, 0, 0.0)
	var record := book.get_record(1, 2, 0, 0, Difficulty.NORMAL)
	assert_not_null(record, "按内容身份建记录")
	assert_eq(book.records.size(), 1)

	# 换一条路线、换一个 route_index：同一张卡仍应命中同一条记录。
	var route := StageRoute.new()
	route.route_id = &"reordered"
	route.difficulty = Difficulty.NORMAL
	route.stages = [StageCatalog.find(2), StageCatalog.find(1)]
	book.record_attempt(1, 2, 0, 0, Difficulty.NORMAL, true, 100, 1.0)
	assert_eq(book.records.size(), 1, "route / route_index 不应拆出第二条记录")
	assert_eq(record.captures, 1)
