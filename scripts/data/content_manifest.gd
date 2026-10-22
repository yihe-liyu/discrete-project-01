## 内容清单（只读派生缓存）：把 data/** 的 Stage / Boss / Phase / Variant 收成一张图。
##
## 不是第二套 registry：源仍是 .tres + 注册表；manifest 只负责给 UI / check_content / 工具查询。
## 第一版输出结构化 Dictionary；CLI 再序列化为 JSON。
class_name ContentManifest
extends RefCounted

const STAGE_REGISTRY := "res://data/registry/stage_registry.tres"
const BOSS_REGISTRY := "res://data/registry/boss_registry.tres"

var issues: Array[String] = []


## 从默认注册表构建。
func build() -> Dictionary:
	issues.clear()
	var stage_reg := _load_resource(STAGE_REGISTRY) as StageRegistry
	var boss_reg := _load_resource(BOSS_REGISTRY) as BossRegistry
	if stage_reg == null:
		issues.append("无法加载 StageRegistry：" + STAGE_REGISTRY)
	if boss_reg == null:
		issues.append("无法加载 BossRegistry：" + BOSS_REGISTRY)
	return build_from(stage_reg, boss_reg)


## 从注入的注册表构建（测试 / 工具可传自己的表）。
func build_from(stage_reg: StageRegistry, boss_reg: BossRegistry) -> Dictionary:
	issues.clear()
	var stages: Array[Dictionary] = []
	var bosses: Array[Dictionary] = []
	var phases: Dictionary = {}
	var bosses_by_stage: Dictionary = {}

	for boss in (boss_reg.bosses if boss_reg != null else []):
		if boss == null:
			continue
		var boss_entry := _boss_entry(boss)
		bosses.append(boss_entry)
		if not bosses_by_stage.has(boss.stage_id):
			bosses_by_stage[boss.stage_id] = []
		bosses_by_stage[boss.stage_id].append(boss_entry)
		_collect_phases(boss, boss_entry, phases)

	for stage in (stage_reg.stages if stage_reg != null else []):
		if stage == null:
			continue
		stages.append(_stage_entry(stage, bosses_by_stage.get(stage.stage_id, [])))

	bosses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.stage_id == b.stage_id:
			return a.order < b.order
		return a.stage_id < b.stage_id)
	var phase_list: Array = phases.values()
	phase_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.path < b.path)
	return {
		"version": 1,
		"generated_by": "ContentManifest",
		"stages": stages,
		"bosses": bosses,
		"phases": phase_list,
		"issues": issues.duplicate(),
	}


func _stage_entry(stage: StageData, stage_bosses: Array) -> Dictionary:
	var variants: Array[Dictionary] = []
	for variant in stage.variants:
		if variant == null:
			continue
		variants.append({
			"difficulty": variant.difficulty,
			"path": variant.resource_path,
			"create_script": _path_of(variant.create_script),
			"background_scene": _path_of(variant.background_scene),
			"bgm_key": variant.bgm_key,
		})
	var difficulties: Array[Dictionary] = []
	for diff in Difficulty.COUNT:
		var variant := stage.variant_for(diff)
		difficulties.append({
			"difficulty": diff,
			"label": Difficulty.display_name(diff),
			"source": "variant" if variant != null else "base",
			"variant_path": variant.resource_path if variant != null else "",
			"create_script": _path_of(stage.script_for_difficulty(diff)),
			"background_scene": _path_of(stage.background_for_difficulty(diff)),
			"bgm_key": stage.bgm_key_for_difficulty(diff),
		})
	return {
		"stage_id": stage.stage_id,
		"stage_no": stage.stage_no,
		"path": stage.resource_path,
		"display_name": stage.display_name,
		"playable": stage.create_script != null,
		"bgm_key": stage.bgm_key,
		"create_script": _path_of(stage.create_script),
		"background_scene": _path_of(stage.background_scene),
		"variants": variants,
		"difficulties": difficulties,
		"bosses": stage_bosses.duplicate(),
	}


func _boss_entry(boss: BossData) -> Dictionary:
	var phase_paths: Dictionary = {}
	for diff in Difficulty.COUNT:
		var list: Array[String] = []
		for phase in boss.phases_for_difficulty(diff):
			if phase != null:
				list.append(phase.resource_path)
		phase_paths[str(diff)] = list
	return {
		"stage_id": boss.stage_id,
		"order": boss.order,
		"path": boss.resource_path,
		"name": boss.boss_name,
		"section_label": boss.section_label,
		"practice_bgm_key": boss.practice_bgm_key,
		"phases": phase_paths,
	}


func _collect_phases(boss: BossData, boss_entry: Dictionary, phases: Dictionary) -> void:
	for diff in Difficulty.COUNT:
		var list: Array = boss.phases_for_difficulty(diff)
		for slot in list.size():
			var phase := list[slot] as PhaseData
			if phase == null:
				continue
			if not phases.has(phase.resource_path):
				phases[phase.resource_path] = {
					"path": phase.resource_path,
					"uid": phase.uid,
					"name": phase.name,
					"hp": phase.hp,
					"time_limit": phase.time_limit,
					"move_script": _path_of(phase.move_script),
					"shoot_script": _path_of(phase.shoot_script),
					"used_by": [],
				}
			phases[phase.resource_path].used_by.append({
				"boss": boss_entry.path,
				"difficulty": diff,
				"slot": slot,
			})


func _path_of(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""


func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
