## Boss 定义：名称 + 视觉 + 阶段列表（构造链 + 数据 .tres）
extends Resource
class_name BossData

@export var boss_name: String = ""
@export var visual: PackedScene
## 阶段列表：phases = Normal（默认难度）；其他难度独立数组（空 = 回退 Normal）
## 难度档：0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra（对应 SpellRecord.Difficulty）
@export var phases: Array[PhaseData] = []
@export var phases_easy: Array[PhaseData] = []
@export var phases_hard: Array[PhaseData] = []
@export var phases_lunatic: Array[PhaseData] = []
@export var phases_extra: Array[PhaseData] = []
@export var score_value: int = 10000
@export var hitbox_radius: float = 36.0
## 入场/退场演出脚本（可选；无则默认顶部飞入/直接退场）
@export var enter_script: Script
@export var exit_script: Script

## ── 构造链 ──

func name(v: String) -> BossData:       boss_name = v; return self
func look(v: PackedScene) -> BossData:  visual = v; return self
func phase(v: PhaseData) -> BossData:   phases.append(v); return self
func easy_phase(v: PhaseData) -> BossData:  phases_easy.append(v); return self
func hard_phase(v: PhaseData) -> BossData:  phases_hard.append(v); return self
func lunatic_phase(v: PhaseData) -> BossData:  phases_lunatic.append(v); return self
func extra_phase(v: PhaseData) -> BossData:    phases_extra.append(v); return self
func score(v: int) -> BossData:         score_value = v; return self
func hitbox(v: float) -> BossData:       hitbox_radius = v; return self

## 按难度取阶段（0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra；空难度组回退 Normal/phases）
func phases_for_difficulty(diff: int) -> Array[PhaseData]:
	match diff:
		0: return phases_easy if not phases_easy.is_empty() else phases
		2: return phases_hard if not phases_hard.is_empty() else phases
		3: return phases_lunatic if not phases_lunatic.is_empty() else phases
		4: return phases_extra if not phases_extra.is_empty() else phases
		_: return phases  # Normal / 未知难度

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
	_validate_group(errs, "Normal", phases)
	_validate_group(errs, "Easy", phases_easy)
	_validate_group(errs, "Hard", phases_hard)
	_validate_group(errs, "Lunatic", phases_lunatic)
	_validate_group(errs, "Extra", phases_extra)
	if phases.is_empty() and phases_easy.is_empty() and phases_hard.is_empty() and phases_lunatic.is_empty() and phases_extra.is_empty():
		errs.append("BossData[%s] 没有任何难度阶段（空 Boss）" % boss_name)
	return errs

func _validate_group(errs: Array[String], diff_name: String, arr: Array[PhaseData]) -> void:
	for i in arr.size():
		if arr[i] == null:
			errs.append("BossData[%s] %s 难度 phases[%d] 为空" % [boss_name, diff_name, i])
		else:
			errs.append_array(arr[i].validate())
