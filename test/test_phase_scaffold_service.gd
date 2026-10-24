extends GutTest
## PhaseScaffoldService：只追加、UID 校验、BossData 文本追加、临时副本 apply。

const SERVICE := preload("res://scripts/workbench/phase_scaffold_service.gd")
const STAGE01 := "res://data/stages/stage01/stage_data/stage01.tres"
const BOSS01 := "res://data/stages/stage01/boss/卡摩瑞关底.tres"
const TMP_ROOT := "user://phase_scaffold_test"
const TMP_STAGE := TMP_ROOT + "/stage_data/stage01.tres"
const TMP_BOSS := TMP_ROOT + "/boss/boss.tres"
const TMP_PHASE_DIR := TMP_ROOT + "/phase/tmp_phase"


func _options(overrides: Dictionary = {}) -> Dictionary:
	var opts := {
		"kind": "spell",
		"difficulties": [Difficulty.NORMAL],
		"name": "测试符卡",
		"uid": 9999,
		"hp": 1200,
		"time_limit": 15.0,
		"timeout_only": false,
		"slug": "tmp_phase",
	}
	for key in overrides:
		opts[key] = overrides[key]
	return opts


func _copy(path: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	var file := FileAccess.open(dst, FileAccess.WRITE)
	assert_not_null(file, "应能写临时文件：" + dst)
	if file:
		file.store_string(FileAccess.get_file_as_string(path))


func _cleanup() -> void:
	for path in [TMP_PHASE_DIR + "/tmp_phase.tres", TMP_PHASE_DIR + "/tmp_phase_shoot.gd", TMP_PHASE_DIR + "/tmp_phase_shoot.gd.uid", TMP_BOSS, TMP_STAGE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for dir in [TMP_PHASE_DIR, TMP_ROOT + "/phase", TMP_ROOT + "/boss", TMP_ROOT + "/stage_data", TMP_ROOT]:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func test_plan_appends_to_selected_difficulty() -> void:
	var stage: StageData = load(STAGE01)
	var boss: BossData = load(BOSS01)
	var plan: Dictionary = SERVICE.new().plan(stage, boss, _options())
	assert_true(plan.ok, "合法计划应 ok：" + str(plan.get("issues", [])))
	assert_string_contains(plan.phase_path, "/phase/tmp_phase/tmp_phase.tres", "阶段目录")
	assert_string_contains(plan.phase_text, "uid = 9999", "PhaseData uid")
	assert_string_contains(plan.phase_text, "shoot_script", "默认生成 shoot 脚本")
	assert_string_contains(plan.boss_text, "phases_normal", "BossData 应追加 Normal")


func test_plan_rejects_duplicate_uid() -> void:
	var stage: StageData = load(STAGE01)
	var boss: BossData = load(BOSS01)
	var plan: Dictionary = SERVICE.new().plan(stage, boss, _options({"uid": 1}))
	assert_false(plan.ok, "已存在的 uid 应拒绝")
	assert_true(plan.issues.any(func(e: String) -> bool: return "已被使用" in e), "错误应说明 UID 冲突")


func test_nonspell_requires_zero_uid() -> void:
	var stage: StageData = load(STAGE01)
	var boss: BossData = load(BOSS01)
	var plan: Dictionary = SERVICE.new().plan(stage, boss, _options({"kind": "nonspell", "name": "", "uid": 7}))
	assert_false(plan.ok, "非符 uid 非 0 应拒绝")
	assert_true(plan.issues.any(func(e: String) -> bool: return "非符 uid" in e), "错误应说明非符 uid")


func test_apply_writes_phase_and_reloads_boss() -> void:
	_copy(STAGE01, TMP_STAGE)
	_copy(BOSS01, TMP_BOSS)
	var stage: StageData = load(TMP_STAGE)
	var boss: BossData = load(TMP_BOSS)
	var before := boss.phases_normal.size()
	var plan: Dictionary = SERVICE.new().plan(stage, boss, _options({"uid": 9998}))
	assert_true(plan.ok, "临时副本应能生成计划：" + str(plan.get("issues", [])))
	var errs := SERVICE.new().apply(plan, boss)
	assert_eq(errs, [], "apply 不应报错")
	assert_eq(boss.phases_normal.size(), before + 1, "内存 BossData 应追加")
	var reloaded: BossData = load(TMP_BOSS)
	assert_eq(reloaded.phases_normal.size(), before + 1, "重新加载后 BossData 应追加")
	var added := reloaded.phases_normal[reloaded.phases_normal.size() - 1]
	assert_not_null(added, "追加项应能加载")
	if added:
		assert_eq(added.uid, 9998, "追加的 PhaseData uid")
		assert_eq(added.name, "测试符卡", "追加的 PhaseData 名称")
