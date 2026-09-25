class_name StageData
extends Resource
## 关卡定义：id + 脚本 + 背景 + **显示名**
## 难度差分在 CoroutineScript 中通过 diff_pick() / diff_get() 运行时处理

@export var stage_id: int = 1
## **给人看**的关卡名（UI 用）。空 = 回落 `"Stage %d"%stage_id`。
## 与 `stage_id` 分工：**id 是记录主键**（`SpellRecord.stage`，必须唯一、不能复用），
## 显示名才是可读标签 —— 所以「3 面 B 线」这种可以有 id=4 + display_name="Stage 3B"，
## 不必把路线后缀编进 int。
@export var display_name: String = ""
## 本关 BGM 的**语义 key**（`AssetRegistry.BGM_PATHS` 里的，如 `stage1` / `stage3B`）。
## 练习模式没有关卡脚本、没人起 BGM（SE 没有衬托会显得特别响）→ 由这里起。
## 关卡脚本仍可在战中等时机自己切（如 Boss 曲）。
@export var bgm_key: String = ""
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
