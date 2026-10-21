## 关卡定义：id + 脚本 + 背景 + 显示名
## 难度差分在 CoroutineScript 中通过 diff_pick() / diff_get() 运行时处理
class_name StageData
extends Resource

## 关卡主键：全作唯一、不复用（3B 面 = 4、EX 面 = 9，不等于面序号）。
## 是存档 / 符卡记录 / 选关的主键；给人看的面号与名字分别用 [code]stage_no[/code] / [code]display_name[/code]。
@export var stage_id: int = 1
## 符卡奖励分用的面序号（[code]SpellBonus[/code] 公式里的 stage）：1..6，EX = 7。
## 与 [code]stage_id[/code] 分工：[code]stage_id[/code] 是记录主键（存档唯一，3B 面因此取 4、EX 取 9），
## 而奖励分要的是原作面数（3A/3B 都是 3、6A/6B 都是 6、EX = 7）。
## [code]0[/code] = 未指定 → 回落 [code]stage_id[/code]。
@export var stage_no: int = 0
## 给人看的关卡名（UI 用）。空 = 回落 [code]"Stage %d"%stage_id[/code]。
## 与 [code]stage_id[/code] 分工：id 是记录主键（[code]SpellRecord.stage[/code]，必须唯一、不能复用），
## 显示名才是可读标签 —— 所以「3 面 B 线」这种可以有 id=4 + display_name="Stage 3B"，
## 不必把路线后缀编进 int。
@export var display_name: String = ""
## 本关 BGM 的语义 key（[code]AssetRegistry.BGM_PATHS[/code] 里的，如 [code]stage1[/code] / [code]stage3B[/code]）。
## 练习模式没有关卡脚本、没人起 BGM（SE 没有衬托会显得特别响）→ 由这里起。
## 关卡脚本仍可在战中等时机自己切（如 Boss 曲）。
@export var bgm_key: String = ""
## 关卡脚本：新建后必须得到 [code]CoroutineScript[/code]（开局时实例化并启动）。
## null = 这面只在目录里提供命名 / 背景，不能开局（[code]StageCatalog.playable[/code] 会过滤掉）。
@export var create_script: Script
## 该面的背景场景（根节点应为 [code]StageBackground[/code]）。null = 不加背景。
## 普通关卡与符卡练习共用这一张；工作台 / 截图工具也从这里取。
@export var background_scene: PackedScene


## 配置校验：返回错误列表（空 = 合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if stage_id < 1:
		errs.append("StageData.stage_id = %s 必须 >= 1" % stage_id)
	if create_script == null:
		errs.append("StageData[%d] 缺少 create_script（关卡无法生成）" % stage_id)
	return errs
