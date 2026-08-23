class_name PhaseIdentity
extends RefCounted
## 一个 phase（非符/符卡）的唯一身份标识
##
## 主键 = (stage_id, phase_index, character, difficulty)

var uid: int               ## 展示用 No.xxx
var character: int
var difficulty: int
var stage_id: int
var boss_index: int = 0    ## 第几个 Boss（0 = 第一个/唯一；多 Boss 关卡区分记录）
var phase_index: int       ## 在 phases 数组中的索引（真正的唯一标识）
var phase_type: int        ## SpellRecord.PhaseType
var phase_number: int      ## 第几张非符/第几张符卡


## 从 Boss 运行时的 PhaseData + 上下文推导
static func from_phase(phase: PhaseData, p_stage_id: int, p_phase_index: int,
		spell_count: int, non_count: int, p_boss_index: int = 0) -> PhaseIdentity:
	var pid := PhaseIdentity.new()
	var is_spell := phase.uid != 0
	pid.uid = phase.uid
	pid.character = GameState.selected_character
	pid.difficulty = GameState.selected_difficulty
	pid.stage_id = p_stage_id
	pid.boss_index = p_boss_index
	pid.phase_index = p_phase_index
	pid.phase_type = SpellRecord.PhaseType.SPELL if is_spell else SpellRecord.PhaseType.NONSPELL
	pid.phase_number = spell_count if is_spell else non_count
	return pid


