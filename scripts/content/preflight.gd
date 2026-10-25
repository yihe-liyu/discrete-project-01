## 内容预检：高价值内容问题清单（只读；不替 check_content 做全量）。
class_name Preflight
extends RefCounted

const PARAM_VALIDATOR = preload("res://scripts/data/param_validator.gd")


static func run(index: ContentIndex) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	_scan_index(index, issues)
	_scan_dialogue(index, issues)
	_scan_stages(index, issues)
	_scan_orphans(index, issues)
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var la := String(a.get("level", ""))
		var lb := String(b.get("level", ""))
		if la != lb:
			return la == "error"
		return String(a.get("code", "")) < String(b.get("code", ""))
	)
	return issues


static func _scan_index(index: ContentIndex, issues: Array[Dictionary]) -> void:
	var uid_map: Dictionary = {}
	for path in index.phases:
		var entry: Dictionary = index.phases[path]
		var phase: PhaseData = entry.get("phase")
		if phase == null:
			continue
		if phase.uid > 0:
			if not uid_map.has(phase.uid):
				uid_map[phase.uid] = []
			(uid_map[phase.uid] as Array).append(path)
		# 空 move/shoot 是合法的（纯演出 / 纯走位阶段），不在这里判缺失。
		var scripts: Array = []
		for script in [phase.pre_move_script, phase.move_script, phase.shoot_script]:
			if script != null:
				scripts.append(script)
		for warning in PARAM_VALIDATOR.validate_unknown_keys_union(scripts, phase.params):
			issues.append(_issue("warning", "phase_param_unknown",
				"%s · %s" % [_phase_label(phase), warning], path))
	for uid in uid_map:
		var paths: Array = uid_map[uid]
		if paths.size() > 1:
			for path in paths:
				issues.append(_issue("error", "phase_uid_duplicate",
					"uid %d 重复：%d 个资源" % [uid, paths.size()], path))


static func _scan_dialogue(index: ContentIndex, issues: Array[Dictionary]) -> void:
	for event_key in index.dialogue_senders:
		if index.stage_handlers.has(event_key):
			continue
		var senders: Array = index.dialogue_senders[event_key]
		var source := String((senders[0] as Dictionary).get("source", "")) if not senders.is_empty() else ""
		issues.append(_issue("warning", "dialogue_event_no_receiver",
			"对话事件「%s」发了没人接" % event_key, source))
	for event_key in index.stage_handlers:
		if index.dialogue_senders.has(event_key):
			continue
		var handlers: Array = index.stage_handlers[event_key]
		var source := String((handlers[0] as Dictionary).get("source", "")) if not handlers.is_empty() else ""
		issues.append(_issue("warning", "dialogue_event_no_sender",
			"对话事件「%s」接了没人发" % event_key, source))


static func _scan_stages(index: ContentIndex, issues: Array[Dictionary]) -> void:
	for stage in StageCatalog.known():
		if stage == null:
			continue
		var boss_count := int(index.stage_boss_count.get(stage.stage_id, 0))
		if boss_count == 0:
			issues.append(_issue("warning", "stage_no_boss",
				"%s 没有 Boss" % StageCatalog.display_name_of(stage.stage_id), stage.resource_path))
		if StageCatalog.registry != null and StageCatalog.registry.find(stage.stage_id) == null:
			issues.append(_issue("warning", "stage_not_registered",
				"%s 未进入 StageRegistry" % StageCatalog.display_name_of(stage.stage_id), stage.resource_path))
		var bgm_key := String(stage.bgm_key)
		if bgm_key != "" and not AssetRegistry.BGM_PATHS.has(bgm_key):
			issues.append(_issue("error", "stage_bgm_missing",
				"%s 的 BGM key 不存在：%s" % [StageCatalog.display_name_of(stage.stage_id), bgm_key], stage.resource_path))


static func _scan_orphans(index: ContentIndex, issues: Array[Dictionary]) -> void:
	for path in _phase_paths_on_disk("res://data/stages"):
		if not index.phases.has(path):
			issues.append(_issue("warning", "phase_orphan",
				"%s 未进入任何 Boss 难度槽" % path.get_file(), path))


static func _phase_paths_on_disk(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_phase_paths_on_disk(dir_path.path_join(entry)))
		elif entry.ends_with(".tres") and dir_path.get_file() == "phase":
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out


static func _issue(level: String, code: String, message: String, source: String) -> Dictionary:
	return {"level": level, "code": code, "message": message, "source": source}


static func _phase_label(phase: PhaseData) -> String:
	if phase.name.strip_edges() != "":
		return phase.name
	var file_name := phase.resource_path.get_file().get_basename()
	return file_name if file_name != "" else "非符"
