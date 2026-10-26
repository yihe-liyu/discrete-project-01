extends GutTest
## ContentManifest：只读派生缓存，Stage / Boss / Phase / Variant 的索引与引用。

const MANIFEST := preload("res://scripts/data/content_manifest.gd")


func test_build_indexes_stages() -> void:
	var manifest = MANIFEST.new()
	var data: Dictionary = manifest.build()
	assert_eq(data.issues, [], "真实内容不应有 manifest issues")
	assert_eq(data.stages.size(), StageCatalog.all().size(), "manifest 应索引全部 StageData")
	assert_eq(data.bosses.size(), 6, "当前注册表有 6 个 BossData")
	assert_gt(data.phases.size(), 0, "应索引到阶段")

	var stage1: Dictionary = data.stages[0]
	assert_eq(stage1.stage_id, 1, "第一个面是 stage 1")
	assert_eq(stage1.create_script, "res://data/stages/stage01/stage_data/stage01.gd", "stage01 直接使用基准脚本")


func test_phases_are_deduped_and_referenced() -> void:
	var manifest = MANIFEST.new()
	var data: Dictionary = manifest.build()
	var seen: Dictionary = {}
	for phase in data.phases:
		assert_false(seen.has(phase.path), "phase 不应重复索引：" + phase.path)
		seen[phase.path] = true
		assert_gt(phase.used_by.size(), 0, "phase 应至少被一个难度槽引用：" + phase.path)
	assert_eq(seen.size(), data.phases.size(), "phase 索引数 = 去重后的路径数")


func test_boss_phase_slots_use_manifest_boss_path() -> void:
	var manifest = MANIFEST.new()
	var data: Dictionary = manifest.build()
	var boss: Dictionary = data.bosses[0]
	assert_true(boss.phases.has("0"), "Boss 应有难度 0 的槽表")
	for diff in Difficulty.COUNT:
		for path in boss.phases[str(diff)]:
			assert_true(seen_phase(data.phases, path), "Boss 槽引用的 phase 必须在 phases 索引里：" + path)


func seen_phase(phases: Array, path: String) -> bool:
	for phase in phases:
		if phase.path == path:
			return true
	return false
