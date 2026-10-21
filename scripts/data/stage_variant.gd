## 关卡难度变体：只覆盖需要变化的字段，其余沿用 [StageData] 基准。
##
## 典型用法：Easy~Lunatic 共用同一份关卡脚本，只给 Extra 换脚本 / 背景 / BGM；
## 或给某一难度单独换背景，不复制整份 StageData。
## [br]
## 空字段 = 不覆盖。关卡脚本必须仍是 [CoroutineScript]（由 StageRuntime 校验）。
class_name StageVariant
extends Resource

## 适用难度（0=Easy … 4=Extra）。
@export var difficulty: int = Difficulty.NORMAL
## 覆盖关卡脚本；null = 用 StageData.create_script。
@export var create_script: Script
## 覆盖背景场景；null = 用 StageData.background_scene。
@export var background_scene: PackedScene
## 覆盖 BGM key；空 = 用 StageData.bgm_key。
@export var bgm_key: String = ""


## 是否至少覆盖了一项；全空 = 无意义变体。
func has_override() -> bool:
	return create_script != null or background_scene != null or bgm_key != ""


## 配置校验；返回错误列表（空 = 合法）。
func validate() -> Array[String]:
	var errs: Array[String] = []
	if not Difficulty.is_valid(difficulty):
		errs.append("StageVariant.difficulty = %d 必须在 0..%d" % [difficulty, Difficulty.COUNT - 1])
	if not has_override():
		errs.append("StageVariant[%s] 没有任何覆盖（create_script / background_scene / bgm_key 全空）" % Difficulty.display_name(difficulty))
	if create_script != null and not create_script.can_instantiate():
		errs.append("StageVariant[%s].create_script 不可实例化" % Difficulty.display_name(difficulty))
	return errs
