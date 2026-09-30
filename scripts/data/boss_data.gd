## Boss 定义：名称 + 视觉 + 阶段列表（构造链 + 数据 .tres）
extends Resource
class_name BossData

@export var boss_name: String = ""
## 阶段列表里的**区分前缀**（如"道中"/"关底"）—— 同一关有多只 Boss 时，光看"非符1/符卡1"
## 分不清是谁的（道中非符 vs 关底非符）。空 = 不加前缀。
@export var section_label: String = ""
@export var visual: PackedScene
## 符卡背景（**每 Boss 一张**）：压在 3D 背景之上、弹幕之下的一层**场景**。
## 只在**符卡**期间显示（非符不显示）；空 = 该 Boss 不用符卡背景。
## 场景由 `SpellBackdropLayer` 实例化并淡入淡出 —— 里面放什么（几张图 / 视差 / shader / 动画）
## 完全自由；想要"一张会向上滚的图"就用 `scenes/effect/spell_backdrop_plain.tscn` 当模板
## （Sprite2D + `SpellBackdropScroll`，速度是它自己的 @export）。
## **坐标约定**：宿主在场地中心 ⇒ 场景里 `(0,0)` = 场地正中；整幅场地尺寸的图放 `(0,0)` 正好铺满。
@export var spell_background: PackedScene
## 符卡宣言立绘（**每 Boss 一张**）：宣言时从游戏框右上角快慢快扫到左下角后淡出。
## 空 = 该 Boss 不用立绘。尺寸随意 —— 以**中心**锚定，右上角进、左下角出。
@export var portrait: Texture2D
## **符卡练习**时该 Boss 用哪首 BGM（`AssetRegistry.BGM_PATHS` 的语义 key）。
## 空 = 回落该面的 `StageData.bgm_key`。练习是按「单张卡」打的、一场只面对一只 Boss，
## 所以道中 Boss 填道中曲、关底 Boss 填 Boss 曲 —— 否则整面只能听同一首（曾如此）。
## ⚠️ 只影响练习；正常关卡的 BGM 由关卡脚本 `stage_director.bgm(key)` 起。
@export var practice_bgm_key: String = ""
## **全破演出**用的爆点特效场景（`BossHandle.defeat()` 播；池化 `HitEffect` 场景）。
## 空 = 用默认 `AssetRegistry` 的通用全破特效（`scenes/effect/boss_defeat.tscn`）。
@export var defeat_fx: PackedScene
## 全破音效 key（`AssetRegistry.sounds`）。空 = 默认 `&"boss_die"`。
@export var defeat_sfx: StringName = &""
## 全破**定格**时长（秒；0 = 不定格）。原作那种"炸开之前顿一下"的手感。
@export var defeat_hitstop: float = 0.12
## 阶段列表：各难度**独立数组，互不回退**（某难度空 = 该难度无阶段）。
## 难度档：0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra（对应 SpellRecord.Difficulty）
@export var phases_easy: Array[PhaseData] = []
@export var phases_normal: Array[PhaseData] = []
@export var phases_hard: Array[PhaseData] = []
@export var phases_lunatic: Array[PhaseData] = []
@export var phases_extra: Array[PhaseData] = []
@export var score_value: int = 10000
@export var hitbox_radius: float = 36.0
## 所在关卡面（BossCatalog 按它分组）
@export var stage_id: int = 0
## 同面内排序（升序 = boss_index）
@export var order: int = 0
## 入场/退场演出脚本（可选；无则默认顶部飞入/直接退场）
@export var enter_script: Script
@export var exit_script: Script

## ── 构造链 ──

func name(v: String) -> BossData:       boss_name = v; return self
func look(v: PackedScene) -> BossData:  visual = v; return self
func normal_phase(v: PhaseData) -> BossData:  phases_normal.append(v); return self
func easy_phase(v: PhaseData) -> BossData:  phases_easy.append(v); return self
func hard_phase(v: PhaseData) -> BossData:  phases_hard.append(v); return self
func lunatic_phase(v: PhaseData) -> BossData:  phases_lunatic.append(v); return self
func extra_phase(v: PhaseData) -> BossData:    phases_extra.append(v); return self
func score(v: int) -> BossData:         score_value = v; return self
func hitbox(v: float) -> BossData:       hitbox_radius = v; return self
func in_stage(v: int) -> BossData:       stage_id = v; return self
func at_order(v: int) -> BossData:       order = v; return self

## 按难度取阶段（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra）。**不回退**：该难度数组空即返回空。
func phases_for_difficulty(diff: int) -> Array[PhaseData]:
	match diff:
		0: return phases_easy
		2: return phases_hard
		3: return phases_lunatic
		4: return phases_extra
		_: return phases_normal  # Normal / 未知难度

## 难度名（工作台/日志用）
static func difficulty_name(diff: int) -> String:
	match diff:
		0: return "Easy"
		1: return "Normal"
		2: return "Hard"
		3: return "Lunatic"
		4: return "Extra"
		_: return "Normal"


## 配置校验：校验默认 + 各难度阶段。返回错误列表（空 = 合法）
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
