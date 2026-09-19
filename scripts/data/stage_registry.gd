# StageRegistry.gd — 全关卡注册表
extends Resource
class_name StageRegistry

@export var stages: Array[StageData] = []  ## 所有关卡（一个 stage_id 一个文件）


## 按 stage_id 查找
func find(stage_id: int) -> StageData:
	for stage in stages:
		if stage.stage_id == stage_id:
			return stage
	return null


## 获取所有关卡
func get_all() -> Array[StageData]:
	return stages


## 全关卡校验：查重 + 逐个校验。返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	var seen: Dictionary = {}
	for stage in stages:
		if stage == null:
			errs.append("StageRegistry 含空 StageData 条目")
			continue
		if seen.has(stage.stage_id):
			errs.append("StageRegistry 中 stage_id = %d 重复" % stage.stage_id)
		seen[stage.stage_id] = true
		errs.append_array(stage.validate())
	return errs
