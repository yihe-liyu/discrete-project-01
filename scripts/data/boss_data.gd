## Boss 定义：名称 + 视觉 + 各难度阶段 + 演出素材（构造链 + .tres）。
##
## [b]模型[/b][br]
## 一份 BossData 只带“这只 Boss 自己打”的阶段；阶段编号由 [BossCatalog] 的规范阶段顺序统一决定。
## [codeblock]
## 关卡内容：
##   BossCatalog.boss(stage, index) → StageDirector.boss(key, data, ...)
##                                → StageRuntime.spawn_boss(data, ...)
## [/codeblock]
## [br]
## [b]用法[/b][br]
## [codeblock]
## BossData.new()
##     .name("卡摩瑞").look(visual)
##     .normal_phase(phase).in_stage(1).at_order(0)
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 各难度阶段独立：某难度为空 = 该难度无阶段，不回退到其它难度。[br]
## - stage_id / order 只决定 BossCatalog 的分组与 boss_index，不决定阶段编号。[br]
## - 符卡背景 / 立绘 / 全破演出都按 Boss 配；符卡练习也复用同一份 BossData。
extends Resource
class_name BossData

## 显示名（HUD / 日志 / 练习列表）。
@export var boss_name: String = ""
## 阶段列表前缀（如“道中”/“关底”）：同一关有多只 Boss 时，练习列表用它区分“谁的非符/符卡”。空 = 不加前缀。
@export var section_label: String = ""
## 外观场景；[code]StageRuntime.spawn_boss()[/code] 实例化后挂到 Boss 下。
@export var visual: PackedScene
## 符卡背景场景：只在该 Boss 的符卡期间显示（非符不显示）；空 = 不用。
## 由 SpellBackdropLayer 实例化并淡入淡出；场景里 (0,0) = 场地正中，整幅场地尺寸的图正好铺满。
## 模板：scenes/effect/spell_backdrop_plain.tscn（Sprite2D + SpellBackdropScroll，速度在它自己的 @export）。
@export var spell_background: PackedScene
## 符卡宣言立绘：宣言时从游戏框右上角“快慢快”扫到左下角后淡出；空 = 不用。
## 尺寸随意，以中心锚定。
@export var portrait: Texture2D
## 符卡练习时该 Boss 用的 BGM key（AssetRegistry.BGM_PATHS 的语义 key）。
## 空 = 回落该面的 StageData.bgm_key；只影响练习，正常关卡 BGM 由关卡脚本 stage_director.bgm(key) 起。
@export var practice_bgm_key: String = ""
## 全破爆点特效场景（BossHandle.defeat 播，池化 HitEffect）；空 = 通用 boss_defeat.tscn。
@export var defeat_fx: PackedScene
## 全破音效 key（AssetRegistry.sounds）；空 = 默认 boss_die。
@export var defeat_sfx: StringName = &""
## 全破定格时长（秒；0 = 不定格）。
@export var defeat_hitstop: float = 0.12
## Easy 难度阶段列表（按出战顺序；空 = 该难度无阶段，不回退）。
@export var phases_easy: Array[PhaseData] = []
## Normal 难度阶段列表（按出战顺序；空 = 该难度无阶段，不回退）。
@export var phases_normal: Array[PhaseData] = []
## Hard 难度阶段列表（按出战顺序；空 = 该难度无阶段，不回退）。
@export var phases_hard: Array[PhaseData] = []
## Lunatic 难度阶段列表（按出战顺序；空 = 该难度无阶段，不回退）。
@export var phases_lunatic: Array[PhaseData] = []
## Extra 难度阶段列表（按出战顺序；空 = 该难度无阶段，不回退）。
@export var phases_extra: Array[PhaseData] = []
## 击破分数（保留字段；当前 Boss 流程未读取，计分走阶段 bonus）。
@export var score_value: int = 10000
## Boss 判定半径（像素）；[code]Boss.setup()[/code] 写进 CircleShape2D。
@export var hitbox_radius: float = 36.0
## 所在关卡面（BossCatalog 按它分组）。
@export var stage_id: int = 0
## 同面内排序（升序 = boss_index）。
@export var order: int = 0
## 入场演出脚本（可选；当前 Boss 入场走默认逻辑，该字段尚未接入）。
@export var enter_script: Script
## 退场演出脚本（可选；当前 Boss 退场走默认逻辑，该字段尚未接入）。
@export var exit_script: Script

# ── 构造链 ──

## 设显示名。
func name(v: String) -> BossData:       boss_name = v; return self
## 设外观场景。
func look(v: PackedScene) -> BossData:  visual = v; return self
## 追加 Normal 阶段。
func normal_phase(v: PhaseData) -> BossData:  phases_normal.append(v); return self
## 追加 Easy 阶段。
func easy_phase(v: PhaseData) -> BossData:  phases_easy.append(v); return self
## 追加 Hard 阶段。
func hard_phase(v: PhaseData) -> BossData:  phases_hard.append(v); return self
## 追加 Lunatic 阶段。
func lunatic_phase(v: PhaseData) -> BossData:  phases_lunatic.append(v); return self
## 追加 Extra 阶段。
func extra_phase(v: PhaseData) -> BossData:    phases_extra.append(v); return self
## 设击破分数（保留字段，当前流程未读取）。
func score(v: int) -> BossData:         score_value = v; return self
## 设判定半径（像素）。
func hitbox(v: float) -> BossData:       hitbox_radius = v; return self
## 设所在关卡面（BossCatalog 分组键）。
func in_stage(v: int) -> BossData:       stage_id = v; return self
## 设同面内排序（升序 = boss_index）。
func at_order(v: int) -> BossData:       order = v; return self

## 按难度取阶段（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）。
## 不回退：该难度数组空即返回空；未知难度按 Normal 处理。
func phases_for_difficulty(diff: int) -> Array[PhaseData]:
	match diff:
		0: return phases_easy
		2: return phases_hard
		3: return phases_lunatic
		4: return phases_extra
		_: return phases_normal  # Normal / 未知难度

## 难度显示名（工作台 / 日志用；未知难度按 Normal）。
static func difficulty_name(diff: int) -> String:
	match diff:
		0: return "Easy"
		1: return "Normal"
		2: return "Hard"
		3: return "Lunatic"
		4: return "Extra"
		_: return "Normal"


## 校验各难度阶段：空条目 + 每个 PhaseData 自身校验；全难度都空 ⇒ 空 Boss 错误。
## 返回错误列表（空 = 合法）。
func validate() -> Array[String]:
	var errs: Array[String] = []
	_validate_group(errs, "Normal", phases_normal)
	_validate_group(errs, "Easy", phases_easy)
	_validate_group(errs, "Hard", phases_hard)
	_validate_group(errs, "Lunatic", phases_lunatic)
	_validate_group(errs, "Extra", phases_extra)
	if phases_normal.is_empty() and phases_easy.is_empty() and phases_hard.is_empty() and phases_lunatic.is_empty() and phases_extra.is_empty():
		errs.append("BossData[%s] 没有任何难度阶段（空 Boss）" % boss_name)
	return errs

func _validate_group(errs: Array[String], diff_name: String, arr: Array[PhaseData]) -> void:
	for i in arr.size():
		if arr[i] == null:
			errs.append("BossData[%s] %s 难度 phases[%d] 为空" % [boss_name, diff_name, i])
		else:
			errs.append_array(arr[i].validate())
