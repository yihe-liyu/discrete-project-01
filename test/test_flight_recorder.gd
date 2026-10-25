extends GutTest
## 运行时飞行记录仪：环形缓冲 / 来源行 / JSON 导出。

const RECORDER = preload("res://scripts/debug/flight_recorder.gd")


func test_record_ring_buffer_keeps_latest():
	var recorder = RECORDER.new()
	recorder.begin({"stage_id": 1, "seed": 1337})
	for i in RECORDER.MAX_EVENTS + 3:
		recorder.record("sample", {"i": i}, "", float(i))
	assert_eq(recorder.events.size(), RECORDER.MAX_EVENTS, "超出上限只保留最近 MAX_EVENTS 条")
	assert_eq(int(recorder.events[0].get("payload", {}).get("i", -1)), 3, "最旧的 3 条被丢掉")
	assert_eq(int(recorder.events[recorder.events.size() - 1].get("id", -1)), RECORDER.MAX_EVENTS + 3, "id 持续递增")


func test_pick_source_prefers_data_frames():
	var stack := [
		{"source": "res://scripts/stage/stage_runtime.gd", "line": 12},
		{"source": "res://data/stages/stage01/stage_script/stage01.gd", "line": 96},
	]
	assert_eq(RECORDER.pick_source(stack), "res://data/stages/stage01/stage_script/stage01.gd:96")
	assert_eq(RECORDER.pick_source([]), "", "没有来源 = 空串，不猜")
	assert_eq(RECORDER.pick_source([{"source": "res://scripts/x.gd", "line": 1}]), "", "只有 scripts/ 不算内容来源")


func test_json_contains_meta_events_and_samples():
	var recorder = RECORDER.new()
	recorder.begin({"stage_id": 1, "difficulty": 1})
	recorder.record("enemy_spawn", {"script": "res://data/stages/x/enemy.gd"}, "res://data/stages/x/stage.gd:39", 1.25)
	recorder.sample(1.25, {"bullets": 12, "enemies": 3})
	var data := recorder.to_dict()
	assert_eq(int(data.get("version", 0)), 1)
	assert_eq(data.get("meta", {}).get("stage_id", 0), 1)
	assert_eq((data.get("events", []) as Array).size(), 1)
	assert_eq((data.get("samples", []) as Array).size(), 1)
	var parsed = JSON.parse_string(recorder.to_json())
	assert_not_null(parsed, "导出的 JSON 必须可解析")
	if parsed != null:
		assert_eq((parsed.get("events", []) as Array).size(), 1)
