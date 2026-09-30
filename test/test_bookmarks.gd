extends GutTest
## `Bookmarks`（书签模型）**无树**单测：S3 把"静态提取 / 人工打点持久化 / 合并规则"从
## `workbench.gd` 与 `bookmark_panel.gd` 收进一个 store 之后，这些规则可以直接断言。
##
## 其中 `test_manual_survives_reopen` 是**真 bug 的回归**：`BookmarkCache.load()` / `has_cache()`
## 在抽 store 之前**从未被调用过** —— 人工打点只写不读，重启工作台就全丢。
##
## 内容依赖 = 0：关卡脚本用 `GDScript.new()` + `source_code` 现造（提取器只看源码文本，
## 与 `test_bookmark_extractor` 同一手法）→ 改真实关卡编排不会让本文件变红。

const BOOKMARKS := preload("res://scripts/workbench/bookmarks.gd")
const CACHE := preload("res://scripts/workbench/bookmark_cache.gd")
const SOURCE := """
func _run() -> void:
	timeline.at(3.0)
	timeline.at(12.5)
	for i in 3:
		timeline.at(20.0 + i * 0.5)
"""

## 专用测试档位（避开真实关卡 id：3A=1 / 3B=4 / EX=9）
const TEST_ID := 9901
const TEST_PATH := "user://bookmarks/stage9901.json"
const ZERO_PATH := "user://bookmarks/stage0.json"

var store: Bookmarks


func before_each() -> void:
	store = BOOKMARKS.new()
	_rm(TEST_PATH)
	_rm(ZERO_PATH)


func after_each() -> void:
	_rm(TEST_PATH)
	_rm(ZERO_PATH)


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## 夹具脚本：3.0 / 12.5 两个字面量 + 循环展开出 20.0 / 20.5 / 21.0
func _fixture_script(code: String = SOURCE) -> GDScript:
	var s := GDScript.new()
	s.source_code = code
	return s


## 夹具关卡：id = 测试档位 + 夹具脚本（内容哈希只由源码决定 → 可复现）
func _fixture_stage(code: String = SOURCE) -> StageData:
	var st := StageData.new()
	st.stage_id = TEST_ID
	st.create_script = _fixture_script(code)
	return st


# ═══ 合并规则 ═══

func test_merge_manual_overrides_auto_and_sorts() -> void:
	var auto: Array = [{"t": 20.0}, {"t": 10.0}, {"t": 30.0}]
	var manual: Array = [{"t": 10.0, "label": "Boss 最难点"}]
	var items := BOOKMARKS.merged_of(auto, manual)
	assert_eq(items.size(), 3, "人工覆盖同刻自动 → 不重复")
	assert_eq(items[0].t, 10.0)
	assert_eq(items[0].label, "Boss 最难点", "同刻由人工提供标签")
	assert_true(items[0].is_manual, "标记为人工")
	assert_eq(items[1].t, 20.0)
	assert_eq(items[1].label, "t=20.0s", "自动书签标签按时刻生成")
	assert_false(items[1].is_manual)


func test_merge_accepts_bare_floats() -> void:
	var items := BOOKMARKS.merged_of([5.0], [1.0])
	assert_eq(items.size(), 2)
	assert_eq(items[0].t, 1.0)
	assert_eq(items[1].t, 5.0)


func test_instance_merge_reflects_adopt() -> void:
	store.adopt([{"t": 3.0}], [])
	assert_eq(store.merged().size(), 1, "merged() 就是当前 store 的视图")


## adopt 必须存副本：否则宿主/面板再改原数组会从背后改掉 store（落盘写进脏数据）
func test_adopt_copies_input() -> void:
	var src: Array = [{"t": 1.0, "label": "A"}]
	store.adopt([], src)
	src.append({"t": 2.0, "label": "B"})
	assert_eq(store.manual.size(), 1, "外部再改不影响 store")


# ═══ 静态提取 ═══

func test_open_extracts_auto_from_script_source() -> void:
	var info := store.open(_fixture_stage())
	assert_eq(int(info.auto), 5, "字面量 2 个 + 循环展开 3 个")
	var ts: Array = []
	for b in store.auto:
		ts.append(float(b.t))
	assert_eq(ts, [3.0, 12.5, 20.0, 20.5, 21.0], "提取结果升序且就是这几个时刻")


func test_open_null_stage_is_empty() -> void:
	var info := store.open(null)
	assert_eq(int(info.auto), 0)
	assert_eq(int(info.manual), 0)
	assert_false(bool(info.cache_hit), "没关卡就没有缓存可言")


# ═══ 持久化 ═══

func test_manual_survives_reopen() -> void:
	var st := _fixture_stage()
	var first := store.open(st)
	assert_false(bool(first.cache_hit), "首次：无缓存档")
	store.adopt(store.auto, [{"t": 12.5, "label": "Boss 入场"}, {"t": 40.0, "label": "终符"}])
	store.save()
	assert_true(FileAccess.file_exists(TEST_PATH), "应写出 user:// 档")

	var reopened := BOOKMARKS.new()
	var info := reopened.open(st)
	assert_eq(int(info.manual), 2, "**人工打点必须读回来**（抽 store 前这里是 0：只写不读）")
	assert_true(bool(info.cache_hit), "第二次：缓存档在")
	assert_true(bool(info.cache_fresh), "哈希未变 → 缓存新鲜")
	assert_eq(reopened.manual[0].label, "Boss 入场")
	assert_eq(int(info.auto), 5, "自动书签现场重算（不依赖缓存里的 auto）")


## 内容变化（哈希不符）→ 自动书签作废待重收集，**人工打点保留**
func test_cache_hash_mismatch_keeps_manual() -> void:
	CACHE.save(TEST_ID, 111, [{"t": 1.0}], [{"t": 2.0, "label": "留着"}])
	var stale := CACHE.load(TEST_ID, 222)
	assert_false(bool(stale.ok), "哈希不符 = 缓存不新鲜")
	assert_eq((stale.manual as Array).size(), 1, "人工打点不随内容变化丢弃")
	assert_eq((stale.auto as Array).size(), 0, "自动书签交给现场重收集")


func test_foreign_stage_id_in_file_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute("user://bookmarks")
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"stage_id": 12345, "script_hash": "0", "manual": [{"t": 1.0}]}))
	f.close()
	var data := CACHE.load(TEST_ID, 0)
	assert_false(bool(data.ok))
	assert_eq((data.manual as Array).size(), 0, "档里 stage_id 对不上 → 整份不认（防串档）")


## 未打开关卡就 save()：不该凭空写出 stage0.json
func test_save_without_open_is_noop() -> void:
	var fresh := BOOKMARKS.new()
	fresh.adopt([], [{"t": 1.0}])
	fresh.save()
	assert_false(FileAccess.file_exists(ZERO_PATH), "stage_id <= 0 不落盘")


# ═══ 内容哈希 ═══

## 哈希必须**可复现**：目录遍历顺序不稳定，不排序 → 每次不同 → 缓存永不命中（已修，立回归）
func test_content_hash_is_stable_and_positive() -> void:
	var a := CACHE.stage_content_hash(_fixture_stage())
	var b := CACHE.stage_content_hash(_fixture_stage())
	assert_eq(a, b, "同一内容两次哈希必须相同")
	assert_gt(a, 0, "哈希应为正")
	assert_ne(CACHE.stage_content_hash(_fixture_stage("timeline.at(9.0)\n")), a,
		"源码不同 → 哈希不同（缓存失效靠它）")
