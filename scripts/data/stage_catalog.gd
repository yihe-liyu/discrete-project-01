## 关卡目录：注册表加载 + 按 id 查找 / 扫描（从 SaveData 拆出，职责单一）。
class_name StageCatalog
extends RefCounted

const REGISTRY_PATH := "res://data/registry/stage_registry.tres"

## 关卡注册表（启动装配时加载；为空则回退扫描 data/stages/）
static var registry: StageRegistry


## 加载注册表——由 SaveData.boot() 调一次
static func load_registry() -> void:
	if ResourceLoader.exists(REGISTRY_PATH):
		registry = ResourceLoader.load(REGISTRY_PATH)


## 按 id 取 StageData（注册表优先，空则扫描目录）
static func find(stage_id: int) -> StageData:
	if registry:
		return registry.find(stage_id)
	return scan(stage_id)


## 扫描 res://data/stages/ 顶层 .tres 找匹配 id（注册表缺失时的回退）
static func scan(stage_id: int) -> StageData:
	for stage_data in _load_all():
		if stage_data.stage_id == stage_id:
			return stage_data
	return null


## 所有 StageData（练习菜单等界面遍历用）
static func all() -> Array[StageData]:
	if registry and not registry.stages.is_empty():
		return registry.stages
	return _load_all()


## 某关卡的背景场景（练习用）
static func background(stage_id: int) -> PackedScene:
	var d := find(stage_id)
	return d.background_scene if d else null


static func _load_all() -> Array[StageData]:
	var result: Array[StageData] = []
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var stage_data: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if stage_data:
				result.append(stage_data)
		file_name = dir.get_next()
	return result
