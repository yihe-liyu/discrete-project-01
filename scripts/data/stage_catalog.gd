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


## 按 id 取 StageData：注册表优先；未收录则回退目录扫描。
## 分工：注册表 = 可玩清单（[code]StageData.validate[/code] 要求 create_script）；
## 仅用于命名/背景的舞台（如还没做关卡脚本的 B 线）不进注册表，走扫描兜底。
static func find(stage_id: int) -> StageData:
	if registry:
		var stage_data := registry.find(stage_id)
		if stage_data != null:
			return stage_data
	return scan(stage_id)


## 扫描 [code]data/stages//stage_data/*.tres[/code] 找匹配 id（注册表未收录时的回退）
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


## 可玩清单：[code]all()[/code] 里真有 [code]create_script[/code] 的那些。
## [code]all()[/code] 在注册表缺失时会回退目录扫描，而那个回退会带上没做关卡脚本的面（如 3B / EX）
## ⇒ 凡是要问"这面能不能开局"的地方（关卡练习菜单 / 工作台关卡下拉）一律走这里，
## 别再各写一遍过滤（抄第二遍就会漂）。
static func playable() -> Array[StageData]:
	var out: Array[StageData] = []
	for stage in all():
		if stage != null and stage.create_script != null:
			out.append(stage)
	return out


## 某关卡的背景场景（练习用）
static func background(stage_id: int) -> PackedScene:
	var stage_data := find(stage_id)
	return stage_data.background_scene if stage_data else null


## 给人看的关卡名：[code]StageData.display_name[/code] → 回落 [code]"Stage %d"[/code]。
## UI 一律走这里，别自己拼 [code]"Stage %d"[/code] —— 否则「3 面 B 线」这类就没法显示。
static func display_name_of(stage_id: int) -> String:
	var stage_data := find(stage_id)
	if stage_data and stage_data.display_name != "":
		return stage_data.display_name
	return "Stage %d" % stage_id


## 符卡奖励分用的面序号（[code]StageData.stage_no[/code] → 未指定回落 [code]stage_id[/code]）。
## 别拿 [code]stage_id[/code] 直接算奖励分：3B 面是 4、EX 是 9，而公式要的是 3 / 7。
static func stage_no_of(stage_id: int) -> int:
	var stage_data := find(stage_id)
	if stage_data and stage_data.stage_no > 0:
		return stage_data.stage_no
	return stage_id


## 该面的默认 BGM key（[code]StageData.bgm_key[/code]；无 StageData / 未填 → ""）。
## 用途：符卡练习的回落曲 —— 见 [code]BossCatalog.practice_bgm_key()[/code]。
static func bgm_key_of(stage_id: int) -> String:
	var stage_data := find(stage_id)
	return stage_data.bgm_key if stage_data else ""


## 递归扫 [code]data/stages//stage_data/*.tres[/code]。
## 曾经只看 [code]res://data/stages/[/code] 顶层 .tres，而文件一直在 [code]<面>/stage_data/[/code]（嵌套）
## → 扫描兜底从未生效（[code]scan[/code] / [code]all[/code] / [code]background[/code] 在注册表缺项时全死）。回归见 test_stage_catalog。
static func _load_all() -> Array[StageData]:
	var result: Array[StageData] = []
	for path in _find_stage_data_files("res://data/stages"):
		var stage_data: StageData = ResourceLoader.load(path)
		if stage_data:
			result.append(stage_data)
	return result


## 递归收集 [code]<dir>//stage_data/*.tres[/code]（只认约定目录，避免把别的 .tres 当舞台）。
static func _find_stage_data_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_find_stage_data_files(dir_path.path_join(entry)))
		elif entry.ends_with(".tres") and dir_path.get_file() == "stage_data":
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out
