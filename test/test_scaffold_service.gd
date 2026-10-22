extends GutTest
## ScaffoldService：生成 StageVariant 计划、保留 StageData UID 文本、apply 到临时 user:// 副本。

const SERVICE := preload("res://scripts/workbench/scaffold_service.gd")
const STAGE01 := "res://data/stages/stage01/stage_data/stage01.tres"
const STAGE01_SCRIPT := "res://data/stages/stage01/stage_script/stage01.gd"
const TMP_ROOT := "user://scaffold_test"
const TMP_STAGE := TMP_ROOT + "/stage_data/stage01.tres"


func _service() -> ScaffoldService:
	return SERVICE.new()


func _copy_stage01_to_tmp() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP_ROOT + "/stage_data"))
	var src := FileAccess.get_file_as_string(STAGE01)
	var file := FileAccess.open(TMP_STAGE, FileAccess.WRITE)
	assert_not_null(file, "应能写临时 StageData")
	if file:
		file.store_string(src)


func _cleanup_tmp() -> void:
	for path in [TMP_STAGE, TMP_ROOT + "/stage_variants/stage01_extra.tres"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for dir in [TMP_ROOT + "/stage_variants", TMP_ROOT + "/stage_data", TMP_ROOT]:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func before_each() -> void:
	_cleanup_tmp()


func after_each() -> void:
	_cleanup_tmp()


func test_plan_creates_variant_path_and_stage_text() -> void:
	var data: StageData = load(STAGE01)
	var plan := _service().plan_stage_variant(data, Difficulty.EXTRA, load(STAGE01_SCRIPT))
	assert_true(plan.ok, "合法请求应生成计划")
	assert_eq(plan.variant_path, "res://data/stages/stage01/stage_variants/stage01_extra.tres", "变体路径")
	assert_string_contains(plan.variant_text, "difficulty = 4", "变体写难度")
	assert_string_contains(plan.variant_text, "create_script", "变体引用脚本")
	assert_string_contains(plan.stage_text, "stage01_extra.tres", "StageData 文本引用新变体")
	assert_string_contains(plan.stage_text, "ExtResource(\"variant_", "StageData 的 variants 数组追加新项")


func test_plan_rejects_duplicate_difficulty() -> void:
	var data: StageData = load(STAGE01)
	var plan := _service().plan_stage_variant(data, Difficulty.NORMAL, load(STAGE01_SCRIPT))
	assert_false(plan.ok, "已有 Normal 变体时应拒绝")
	assert_true(plan.issues.any(func(e: String) -> bool: return "已经有变体" in e), "错误应说明重复")


func test_apply_writes_variant_and_reloads_stage() -> void:
	_copy_stage01_to_tmp()
	var data: StageData = load(TMP_STAGE)
	var plan := _service().plan_stage_variant(data, Difficulty.EXTRA, load(STAGE01_SCRIPT))
	assert_true(plan.ok, "临时副本应能生成计划")
	var errs := _service().apply(plan, data)
	assert_eq(errs, [], "apply 不应报错")
	assert_eq(data.variants.size(), 5, "内存 StageData 应追加变体")
	var reloaded: StageData = load(TMP_STAGE)
	assert_eq(reloaded.variants.size(), 5, "重新加载后 variants 应为 5")
	assert_not_null(reloaded.variant_for(Difficulty.EXTRA), "重新加载后 Extra 变体应存在")
