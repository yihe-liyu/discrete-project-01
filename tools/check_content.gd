extends Node
## 内容契约检查：注册表 / 引用 / BGM / 难度变体 / 目录类型。
##
## 只查能被 ResourceLoader 验证的东西，不改文件；输出 path + 字段 + 期望。
## 用法：./tools/check_content.sh
## 退出码：0 = 全过；1 = 有错误（warning 不红）。

const STAGE_REGISTRY := "res://data/registry/stage_registry.tres"
const BOSS_REGISTRY := "res://data/registry/boss_registry.tres"
const CONTENT_MANIFEST := preload("res://scripts/data/content_manifest.gd")

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _phase_uids: Dictionary = {}
var _manifest: Dictionary = {}
var _stage_paths: Dictionary = {}
var _variant_paths: Dictionary = {}
var _boss_paths: Dictionary = {}
var _phase_paths: Dictionary = {}


func _ready() -> void:
	_check_stage_registry()
	_check_boss_registry()
	_check_stage_folders()
	_build_manifest()
	_check_manifest_consistency()
	_check_orphans()
	_report()
	get_tree().quit(1 if not _errors.is_empty() else 0)


func _error(message: String) -> void:
	_errors.append(message)


func _warn(message: String) -> void:
	_warnings.append(message)


func _check_stage_registry() -> void:
	var reg := _load_as(STAGE_REGISTRY) as StageRegistry
	if reg == null:
		_error("%s 不是 StageRegistry 或加载失败" % STAGE_REGISTRY)
		return
	for err in reg.validate():
		_error("StageRegistry: " + err)
	var seen_ids: Dictionary = {}
	for stage in reg.stages:
		if stage == null:
			continue
		var path: String = stage.resource_path
		if seen_ids.has(stage.stage_id):
			_error("%s: stage_id=%d 与 %s 重复" % [path, stage.stage_id, seen_ids[stage.stage_id]])
		seen_ids[stage.stage_id] = path
		if stage.create_script != null and not stage.create_script.can_instantiate():
			_error("%s: create_script 不可实例化" % path)
		if stage.background_scene != null and not stage.background_scene.can_instantiate():
			_error("%s: background_scene 不可实例化" % path)
		_check_bgm(stage.bgm_key, path + ".bgm_key")
		for variant in stage.variants:
			if variant == null:
				continue
			var vpath: String = variant.resource_path
			if not vpath.contains("/stage_variants/"):
				_error("%s: StageVariant 必须放在 stage_variants/（当前在 stage_data/？）" % vpath)
			if variant.create_script != null and not variant.create_script.can_instantiate():
				_error("%s: create_script 不可实例化" % vpath)
			_check_bgm(variant.bgm_key, vpath + ".bgm_key")


func _check_boss_registry() -> void:
	var reg := _load_as(BOSS_REGISTRY) as BossRegistry
	if reg == null:
		_error("%s 不是 BossRegistry 或加载失败" % BOSS_REGISTRY)
		return
	for boss in reg.bosses:
		if boss == null:
			continue
		var path: String = boss.resource_path
		for err in boss.validate():
			_error("%s: %s" % [path, err])
		_check_bgm(boss.practice_bgm_key, path + ".practice_bgm_key")
		for diff in Difficulty.COUNT:
			for phase in boss.phases_for_difficulty(diff):
				if phase == null:
					continue
				if phase.uid != 0:
					if _phase_uids.has(phase.uid):
						_error("%s: PhaseData.uid=%d 与 %s 重复" % [phase.resource_path, phase.uid, _phase_uids[phase.uid]])
					_phase_uids[phase.uid] = phase.resource_path
				if phase.move_script != null and not phase.move_script.can_instantiate():
					_error("%s: move_script 不可实例化" % phase.resource_path)
				if phase.shoot_script != null and not phase.shoot_script.can_instantiate():
					_error("%s: shoot_script 不可实例化" % phase.resource_path)


## 构建只读 manifest；后续一致性 / 孤儿检查都以它为准。
func _build_manifest() -> void:
	var builder: RefCounted = CONTENT_MANIFEST.new()
	_manifest = builder.build()
	for issue in _manifest.get("issues", []):
		_error("ContentManifest: " + str(issue))
	for stage in _manifest.get("stages", []):
		_stage_paths[stage.path] = true
		for variant in stage.variants:
			_variant_paths[variant.path] = true
	for boss in _manifest.get("bosses", []):
		_boss_paths[boss.path] = true
	for phase in _manifest.get("phases", []):
		_phase_paths[phase.path] = true


## manifest 的字段必须和 ResourceLoader 读到的真实资源一致。
func _check_manifest_consistency() -> void:
	for entry in _manifest.get("stages", []):
		var stage := _load_any(entry.path) as StageData
		if stage == null:
			_error("%s: manifest 中的 Stage 无法加载" % entry.path)
			continue
		if stage.stage_id != entry.stage_id:
			_error("%s: manifest stage_id=%d ≠ 资源 %d" % [entry.path, entry.stage_id, stage.stage_id])
		if _path_of(stage.create_script) != entry.create_script:
			_error("%s: manifest create_script 与资源不一致" % entry.path)
		if _path_of(stage.background_scene) != entry.background_scene:
			_error("%s: manifest background_scene 与资源不一致" % entry.path)
		if stage.bgm_key != entry.bgm_key:
			_error("%s: manifest bgm_key 与资源不一致" % entry.path)
		if stage.variants.size() != entry.variants.size():
			_error("%s: manifest variants 数量与资源不一致" % entry.path)
		for diff in entry.difficulties:
			if _path_of(stage.script_for_difficulty(diff.difficulty)) != diff.create_script:
				_error("%s: 难度 %s 的 script 与资源不一致" % [entry.path, diff.label])
			if _path_of(stage.background_for_difficulty(diff.difficulty)) != diff.background_scene:
				_error("%s: 难度 %s 的 background 与资源不一致" % [entry.path, diff.label])
			if stage.bgm_key_for_difficulty(diff.difficulty) != diff.bgm_key:
				_error("%s: 难度 %s 的 bgm_key 与资源不一致" % [entry.path, diff.label])

	for entry in _manifest.get("bosses", []):
		var boss := _load_any(entry.path) as BossData
		if boss == null:
			_error("%s: manifest 中的 Boss 无法加载" % entry.path)
			continue
		if boss.stage_id != entry.stage_id or boss.order != entry.order:
			_error("%s: manifest stage_id/order 与资源不一致" % entry.path)
		if boss.boss_name != entry.name or boss.practice_bgm_key != entry.practice_bgm_key:
			_error("%s: manifest Boss 名称 / practice_bgm_key 与资源不一致" % entry.path)
		for diff in Difficulty.COUNT:
			var expected: Array = entry.phases.get(str(diff), [])
			var actual: Array = boss.phases_for_difficulty(diff)
			if expected.size() != actual.size():
				_error("%s: 难度 %s 的 phase 槽数与资源不一致" % [entry.path, Difficulty.display_name(diff)])
				continue
			for i in actual.size():
				if actual[i] != null and actual[i].resource_path != expected[i]:
					_error("%s: 难度 %s 槽 %d 的 phase 与资源不一致" % [entry.path, Difficulty.display_name(diff), i])

	for entry in _manifest.get("phases", []):
		var phase := _load_any(entry.path) as PhaseData
		if phase == null:
			_error("%s: manifest 中的 Phase 无法加载" % entry.path)
			continue
		if phase.uid != entry.uid or phase.name != entry.name:
			_error("%s: manifest uid/name 与资源不一致" % entry.path)
		if phase.move_script != null and phase.move_script.resource_path != entry.move_script:
			_error("%s: manifest move_script 与资源不一致" % entry.path)
		if phase.shoot_script != null and phase.shoot_script.resource_path != entry.shoot_script:
			_error("%s: manifest shoot_script 与资源不一致" % entry.path)
		if entry.used_by.is_empty():
			_error("%s: manifest phase 没有任何 used_by" % entry.path)


## 未被 manifest 收录的内容：先 warning，不红；测试面 / 未启用内容允许存在。
func _check_orphans() -> void:
	for path in _find_files("res://data/stages"):
		if not path.ends_with(".tres"):
			continue
		var dir := path.get_base_dir().get_file()
		var res := _load_any(path)
		match dir:
			"stage_data":
				if res is StageData and not _stage_paths.has(path):
					_warn("%s: StageData 未进入 StageRegistry（测试面 / 未启用？）" % path)
			"stage_variants":
				if res is StageVariant and not _variant_paths.has(path):
					_warn("%s: StageVariant 没有被任何 StageData 引用" % path)
			"boss":
				if res is BossData and not _boss_paths.has(path):
					_warn("%s: BossData 未进入 BossRegistry" % path)
			"phase":
				if res is PhaseData and not _phase_paths.has(path):
					_warn("%s: PhaseData 没有被任何 Boss 难度槽引用" % path)


func _path_of(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""




func _check_stage_folders() -> void:
	for path in _find_files("res://data/stages"):
		if not path.ends_with(".tres"):
			continue
		var dir := path.get_base_dir().get_file()
		if dir == "stage_data":
			var res = _load_any(path)
			if not res is StageData:
				_error("%s: stage_data/ 下的 .tres 必须是 StageData" % path)
		elif dir == "stage_variants":
			var res = _load_any(path)
			if not res is StageVariant:
				_error("%s: stage_variants/ 下的 .tres 必须是 StageVariant" % path)



func _check_bgm(key: String, where: String) -> void:
	if key == "":
		return
	if not AssetRegistry.BGM_PATHS.has(key):
		_error("%s: BGM key '%s' 不在 AssetRegistry.BGM_PATHS" % [where, key])


func _load_as(path: String) -> Resource:
	var res := _load_any(path)
	if res == null:
		return null
	if res.get_script() == null:
		return null
	return res


func _load_any(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res == null:
		_error("%s: ResourceLoader 返回 null" % path)
	return res


func _find_files(p_root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(p_root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := p_root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_find_files(path))
		else:
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _report() -> void:
	for warning in _warnings:
		print("⚠️ " + warning)
	for error in _errors:
		print("❌ " + error)
	if _errors.is_empty():
		print("✅ 内容契约全过（%d 个 warning）" % _warnings.size())
	else:
		print("❌ 内容契约失败：%d 个错误 / %d 个 warning" % [_errors.size(), _warnings.size()])
