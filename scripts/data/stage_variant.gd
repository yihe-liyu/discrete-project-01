## 关卡难度变体：只覆盖需要变化的字段，其余沿用 [StageData] 基准。
##
## 典型用法：Easy~Lunatic 共用同一份关卡脚本，只给 Extra 换结构脚本。
## 背景 / BGM 默认跨难度共享；对应字段已废弃，只保留供旧数据读取。
## [br]
## 空字段 = 不覆盖。关卡脚本必须仍是 [CoroutineScript]（由 StageRuntime 校验）。
class_name StageVariant
extends Resource

## 适用难度（0=Easy … 4=Extra）。
@export var difficulty: int = Difficulty.NORMAL
## 覆盖关卡脚本；null = 用 StageData.create_script。
@export var create_script: Script
## 已废弃：背景应由所有难度共享；字段保留只为旧数据兼容，配置后会报错。
@export var background_scene: PackedScene
## 已废弃：BGM 应由所有难度共享；字段保留只为旧数据兼容，配置后会报错。
@export var bgm_key: String = ""


## 是否至少覆盖了一项结构字段；全空 = 无意义变体。
func has_override() -> bool:
	return create_script != null


## 配置校验；返回错误列表（空 = 合法）。
func validate() -> Array[String]:
	var errs: Array[String] = []
	if not Difficulty.is_valid(difficulty):
		errs.append("StageVariant.difficulty = %d 必须在 0..%d" % [difficulty, Difficulty.COUNT - 1])
	if not has_override():
		errs.append("StageVariant[%s] 没有任何覆盖（create_script / background_scene / bgm_key 全空）" % Difficulty.display_name(difficulty))
	if create_script != null and not create_script.can_instantiate():
		errs.append("StageVariant[%s].create_script 不可实例化" % Difficulty.display_name(difficulty))
	if background_scene != null:
		errs.append("StageVariant[%s].background_scene 已废弃：背景应跨难度共享" % Difficulty.display_name(difficulty))
	if bgm_key != "":
		errs.append("StageVariant[%s].bgm_key 已废弃：BGM 应跨难度共享" % Difficulty.display_name(difficulty))
	return errs
