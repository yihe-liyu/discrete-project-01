extends GutTest
## 内容源码静态扫描：字面 at / wait / 动态 at / 标签。

const SOURCE_FACTS = preload("res://scripts/content/source_facts.gd")
const TEMP_PATH := "user://content_source_facts_test.gd"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func _write_script() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	assert_not_null(file, "临时脚本应能写入")
	if file == null:
		return
	file.store_string("""extends CoroutineScript

func start(p_ctx, p_target = null):
	var timeline := start_timeline()
	timeline.at(35.0).do(func():
		_stage_director.boss("boss_mid", data, Vector2.ZERO, Vector2.ONE)
	)
	timeline.at(38.0).sequence_phases(func(): return boss, phases, 1.0)
	timeline.wait(2.0).do(func(): handle.retreat(Vector2.ZERO))
	for i in 3:
		timeline.at(1.0 + i * 0.1).do(func():
			ctx.enemies.spawn(data)
		)
""")
	file.close()


func test_scan_stage_extracts_cues_waits_and_dynamic() -> void:
	_write_script()
	var facts := SOURCE_FACTS.scan_stage(TEMP_PATH)
	var cues: Array = facts.get("cues", [])
	var waits: Array = facts.get("waits", [])
	var dynamic: Array = facts.get("dynamic", [])
	assert_eq(cues.size(), 2, "两个字面 at")
	assert_eq(waits.size(), 1, "一个 wait")
	assert_eq(dynamic.size(), 1, "一个动态 at")
	if cues.size() == 2:
		assert_eq(float(cues[0].get("t", 0.0)), 35.0)
		assert_eq(String(cues[0].get("label", "")), "Boss 进场")
		assert_eq(float(cues[1].get("t", 0.0)), 38.0)
		assert_eq(String(cues[1].get("label", "")), "阶段序列")
	if waits.size() == 1:
		assert_eq(float(waits[0].get("offset", 0.0)), 2.0)
		assert_eq(String(waits[0].get("label", "")), "Boss 退场")
	if dynamic.size() == 1:
		assert_eq(String(dynamic[0].get("label", "")), "波次")


func test_scan_missing_stage_returns_empty() -> void:
	var facts := SOURCE_FACTS.scan_stage("res://definitely_missing.gd")
	assert_eq((facts.get("cues", []) as Array).size(), 0)
	assert_eq((facts.get("waits", []) as Array).size(), 0)
	assert_eq((facts.get("dynamic", []) as Array).size(), 0)


func test_scan_script_literals_diff_pick_and_expression() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("""extends CoroutineScript

var 发射间隔: float = diff_pick([2.0, 1.75, 1.5, 1.25])
var 个数 = diff_pick([25, 35, 45, 50])
var 速度 := 3.5
var 表达式 = 1.0 + 2.0
""")
	file.close()
	var facts := SOURCE_FACTS.scan_script(TEMP_PATH)
	var vars: Array = facts.get("vars", [])
	assert_eq(vars.size(), 4, "四条 var")
	if vars.size() == 4:
		assert_eq(String(vars[0].get("kind", "")), "diff_pick")
		assert_eq((vars[0].get("values", []) as Array).size(), 4)
		assert_eq(String(vars[0].get("type", "")), "float")
		assert_eq(String(vars[1].get("kind", "")), "diff_pick")
		assert_eq(String(vars[2].get("kind", "")), "literal")
		assert_eq(float(vars[2].get("value", 0.0)), 3.5)
		assert_eq(String(vars[3].get("kind", "")), "expr")


func test_scan_script_multiline_diff_pick() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("""extends CoroutineScript

var 数量 = diff_pick([
	10,
	20,
	30,
	40,
	50,
])
""")
	file.close()
	var facts := SOURCE_FACTS.scan_script(TEMP_PATH)
	var vars: Array = facts.get("vars", [])
	assert_eq(vars.size(), 1)
	if vars.size() == 1:
		assert_eq(String(vars[0].get("kind", "")), "diff_pick")
		assert_eq((vars[0].get("values", []) as Array).size(), 5)
		assert_eq(int((vars[0].get("values", []) as Array)[4].get("value", 0)), 50)


func test_init_guard_only_allows_trivial_init() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("""extends CoroutineScript

func _init() -> void:
	auto_stop = true
""")
	file.close()
	assert_true(SOURCE_FACTS.init_is_trivial(TEMP_PATH), "只设置 auto_stop 的 _init 允许反射")

	file = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string("""extends CoroutineScript

func _init() -> void:
	RNG.randf()
""")
	file.close()
	assert_false(SOURCE_FACTS.init_is_trivial(TEMP_PATH), "有副作用调用的 _init 退回静态")


func test_scan_dialogue_events_and_stage_handlers() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string("""extends Node

func run(d):
	d.event("boss_enter")
	d.event('bgm_switch')

func setup():
	_stage_director.on("boss_enter", _on_boss_enter)
	_stage_director.on("stage_end", _on_stage_end)
""")
	file.close()
	var events := SOURCE_FACTS.scan_dialogue_events(TEMP_PATH)
	var handlers := SOURCE_FACTS.scan_stage_handlers(TEMP_PATH)
	assert_eq(events.size(), 2, "两个 dialogue event")
	assert_eq(handlers.size(), 2, "两个 stage handler")
	if events.size() == 2:
		assert_eq(String(events[0].get("event", "")), "boss_enter")
		assert_eq(String(events[1].get("event", "")), "bgm_switch")
	if handlers.size() == 2:
		assert_eq(String(handlers[0].get("event", "")), "boss_enter")
		assert_eq(String(handlers[1].get("event", "")), "stage_end")
