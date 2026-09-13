extends GutTest
## 书签提取器测试：字面量 + 循环展开

const Extractor = preload("res://scripts/workbench/bookmark_extractor.gd")


func test_extracts_tl_at_literals() -> void:
	var script := GDScript.new()
	script.source_code = """
func start(ctx):
	var timeline := start_timeline()
	timeline.at(0.0).play_bgm(bgm)
	timeline.at(7.0).do(func(): pass)
	timeline.at(35.0).start_phase(func(): return null, phase)
	timeline.wait(2.0).do(func(): pass)  # 不应被提取
	"""
	var bookmarks := Extractor.extract_from_script(script)
	var ts: Array = []
	for b in bookmarks:
		ts.append(b.t)
	assert_eq(ts, [0.0, 7.0, 35.0], "应提取字面量时刻且升序")


func test_expands_loop_pattern() -> void:
	# 循环展开：at(1.0 + i * 0.1) + for i in 7 → 1.0~1.6
	var script := GDScript.new()
	script.source_code = """
	for i in 7:
		timeline.at(1.0 + i * 0.1).do(func(): pass)
	"""
	var bookmarks := Extractor.extract_from_script(script)
	var ts: Array = []
	for b in bookmarks:
		ts.append(b.t)
	# 去重合并后应有 1.0 和 1.3~1.6 一带（0.2s 阈值内相邻合并）
	assert_true(ts.has(1.0), "应有起点 1.0")
	assert_true(ts.size() >= 3, "应展开出多个时刻")


func test_empty_on_null_script() -> void:
	assert_eq(Extractor.extract_from_script(null), [], "null 脚本返回空")


func test_dedup_close_times() -> void:
	var script := GDScript.new()
	script.source_code = "func s():\n\ttimeline.at(5.0).do(f)\n\ttimeline.at(5.05).do(f)\n"
	var bookmarks := Extractor.extract_from_script(script)
	assert_eq(bookmarks.size(), 1, "0.2s 内合并")
