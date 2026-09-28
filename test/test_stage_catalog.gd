extends GutTest
## StageCatalog：按 id 取舞台（注册表优先 → **目录扫描兜底**）+ 显示名解析。
##
## 回归：`_load_all()` 曾只扫 `res://data/stages/` **顶层** .tres，而文件实际在
## `data/stages/<面>/stage_data/<面>.tres`（嵌套）→ 扫描兜底**从未生效**
## （`scan` / `all` / `background` 在注册表缺项时全是死路）。


## 扫描兜底：注册表不可用时，仍能从**嵌套** stage_data/ 目录找到舞台
func test_scan_fallback_finds_nested_stage_data():
	var saved: StageRegistry = StageCatalog.registry
	StageCatalog.registry = null          # 强制走扫描路径
	var sd: StageData = StageCatalog.find(1)
	StageCatalog.registry = saved
	assert_not_null(sd, "注册表不可用时应回退目录扫描（stage_data 是嵌套目录）")
	if sd:
		assert_eq(sd.stage_id, 1, "按 id 取到正确舞台")


## 显示名回落：没有 StageData / 没填 display_name → "Stage %d"
func test_display_name_falls_back_to_stage_number():
	assert_eq(StageCatalog.display_name_of(-99), "Stage -99", "未收录的 id 应回落 Stage N")


## 面的默认 BGM key（练习曲的回落项）：真内容有值、未收录的面回落空串
func test_bgm_key_of_reads_stage_data():
	assert_eq(StageCatalog.bgm_key_of(1), "stage1", "1 面的默认 BGM = stage1")
	assert_eq(StageCatalog.bgm_key_of(9), "stageEX", "EX 面的默认 BGM = stageEX")
	assert_eq(StageCatalog.bgm_key_of(-99), "", "未收录的面 → 空串（不是崩 / 不是乱猜）")
