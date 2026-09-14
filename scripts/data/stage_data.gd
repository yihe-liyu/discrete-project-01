class_name StageData
extends Resource
## 关卡定义：id + 脚本 + 背景
## 难度差分在 CoroutineScript 中通过 diff_pick() / diff_get() 运行时处理

@export var stage_id: int = 1
@export var create_script: Script
@export var background_scene: PackedScene


## 配置校验：返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if stage_id < 1:
		errs.append("StageData.stage_id = %s 必须 >= 1" % stage_id)
	if create_script == null:
		errs.append("StageData[%d] 缺少 create_script（关卡无法生成）" % stage_id)
	return errs
