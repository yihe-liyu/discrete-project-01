## 内容索引：阶段 / Boss / 脚本的反向关系。
##
## 不做第二套注册表：BossCatalog + PhaseData 还是唯一来源；本类只建查询缓存。
class_name ContentIndex
extends RefCounted

## phase_path -> {phase, uses: Array[Dictionary]}
var phases: Dictionary = {}
## script_path -> {phase_path: true}
var script_phases: Dictionary = {}
## 所有 (stage, boss, difficulty, slot) 使用项
var uses: Array[Dictionary] = []
## stage_id -> Boss 数
var stage_boss_count: Dictionary = {}
## dialogue event -> Array[{source, event}]
var dialogue_senders: Dictionary = {}
## dialogue event -> Array[{source, event}]
var stage_handlers: Dictionary = {}


func build() -> void:
	_build(BossCatalog.all())


func build_from(grouped: Dictionary) -> void:
	_build(grouped)


func _build(grouped: Dictionary) -> void:
	phases.clear()
	script_phases.clear()
	uses.clear()
	stage_boss_count.clear()
	dialogue_senders.clear()
	stage_handlers.clear()
	for stage_id in grouped:
		var bosses: Array = grouped[stage_id]
		stage_boss_count[int(stage_id)] = bosses.size()
		for bi in bosses.size():
			var boss: BossData = bosses[bi]
			if boss == null:
				continue
			for diff in Difficulty.COUNT:
				var list: Array = boss.phases_for_difficulty(diff)
				for slot in list.size():
					var phase := list[slot] as PhaseData
					if phase == null:
						continue
					_add_use(stage_id, bi, boss, diff, slot, phase)
	_scan_dialogue()


func _scan_dialogue() -> void:
	var stage_paths: Dictionary = {}
	for stage in StageCatalog.known():
		if stage == null:
			continue
		for diff in Difficulty.COUNT:
			var script := stage.script_for_difficulty(diff)
			if script != null and script.resource_path != "":
				stage_paths[script.resource_path] = stage.stage_id
	for path in stage_paths:
		for entry in SourceFacts.scan_stage_handlers(String(path)):
			var key := String((entry as Dictionary).get("event", ""))
			if key == "":
				continue
			if not stage_handlers.has(key):
				stage_handlers[key] = []
			(stage_handlers[key] as Array).append(entry)
	for path in _dialogue_scripts("res://data/dialogue"):
		for entry in SourceFacts.scan_dialogue_events(path):
			var key := String((entry as Dictionary).get("event", ""))
			if key == "":
				continue
			if not dialogue_senders.has(key):
				dialogue_senders[key] = []
			(dialogue_senders[key] as Array).append(entry)


func _dialogue_scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_dialogue_scripts(dir_path.path_join(entry)))
		elif entry.ends_with(".gd"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func dialogue_wired_count() -> int:
	var count := 0
	for key in dialogue_senders:
		if stage_handlers.has(key):
			count += 1
	return count


func _add_use(stage_id: int, boss_index: int, boss: BossData, diff: int, slot: int, phase: PhaseData) -> void:
	var path := phase.resource_path
	if not phases.has(path):
		phases[path] = {"phase": phase, "uses": []}
	var use := {
		"stage_id": stage_id,
		"boss_index": boss_index,
		"boss": boss.boss_name,
		"boss_path": boss.resource_path,
		"section": boss.section_label,
		"difficulty": diff,
		"slot": slot,
		"phase": phase,
		"phase_path": path,
	}
	(phases[path].uses as Array).append(use)
	uses.append(use)
	for item in [phase.pre_move_script, phase.move_script, phase.shoot_script]:
		var script_res: Script = item
		if script_res == null:
			continue
		var sp: String = script_res.resource_path
		if sp == "":
			continue
		if not script_phases.has(sp):
			script_phases[sp] = {}
		script_phases[sp][path] = true


func uses_for_phase(phase_path: String) -> Array:
	if not phases.has(phase_path):
		return []
	return (phases[phase_path] as Dictionary).get("uses", [])


func phases_for_script(script_path: String) -> Array[String]:
	var out: Array[String] = []
	if not script_phases.has(script_path):
		return out
	for path in script_phases[script_path]:
		out.append(String(path))
	out.sort()
	return out


func script_phase_count(script_path: String) -> int:
	return phases_for_script(script_path).size()


func phase_paths() -> Array[String]:
	var out: Array[String] = []
	for path in phases:
		out.append(String(path))
	out.sort()
	return out
