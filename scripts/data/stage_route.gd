## 一条难度路线：只引用 StageData，不复制内容；顺序就是本局经过的关卡。
## Route 管成员/顺序，StageData / 内容脚本内部的 diff_pick 管强度。
class_name StageRoute
extends Resource

## 路线稳定主键（存档 / 调试 / 工具用；不要拿数组下标当身份）。
@export var route_id: StringName = &""
## 所属难度（Difficulty 0..COUNT-1）。
@export var difficulty: int = 1
## 本路线经过的关卡；允许不同路线引用同一个 StageData。
@export var stages: Array[StageData] = []


## 该位置关卡；越界返回 null。
func stage_at(index: int) -> StageData:
	if index < 0 or index >= stages.size():
		return null
	return stages[index]


## 配置校验：返回错误列表（空 = 合法）。
func validate() -> Array[String]:
	var errs: Array[String] = []
	if route_id == &"":
		errs.append("StageRoute.route_id 不能为空")
	if not Difficulty.is_valid(difficulty):
		errs.append("StageRoute[%s] difficulty=%d 非法" % [route_id, difficulty])
	if stages.is_empty():
		errs.append("StageRoute[%s] 没有关卡" % route_id)
	var seen: Dictionary = {}
	for i in stages.size():
		var stage := stages[i]
		if stage == null:
			errs.append("StageRoute[%s] 第 %d 项为空" % [route_id, i])
			continue
		if seen.has(stage.stage_id):
			errs.append("StageRoute[%s] 重复引用 stage_id=%d" % [route_id, stage.stage_id])
		seen[stage.stage_id] = true
	return errs
