## 符卡练习会话：模式标志 + 载荷（阶段 / Boss 场景 / 名字 / 关卡 / 背景）。
## 从 SaveData 拆出。「开一局」的整局复位由 SaveData.reset_session() 统一编排。
class_name PracticeSession
extends RefCounted

## 符卡练习模式（单 phase Boss）
static var is_practice_mode: bool = false
## 本次练习的阶段数据。
static var phase: PhaseData
## 本次练习的 Boss 外观场景。
static var boss_scene: PackedScene
## 本次练习的 Boss 显示名。
static var boss_name: String
## 所属关卡主键。
static var stage_id: int = 1
## 练习目标在规范阶段序里的下标。
static var phase_index: int = 0
## 该面的背景场景（来自 StageCatalog）。
static var background: PackedScene
## 符卡背景（每 Boss 一张，PackedScene）：[code]start_spell_card()[/code] 自建 BossData 会丢
## [code]BossData.spell_background[/code]，故练习载荷单独携带一份，由 game_scene 优先取 Boss 的、回落取这份。
static var spell_background: PackedScene
## 本局练习的 BGM key（菜单按选中的卡解析：[code]BossCatalog.practice_bgm_key()[/code] = Boss 覆盖 → 面默认）。
## game_scene 起场景时用它；空 = 练习静音。
static var bgm_key: String = ""
## 从练习返回符卡练习菜单时，要还原到的层级与选中项（[code]{section, stage, phase, diff, char}[/code]）。
## 故意不在 [code]clear()[/code] 里清 —— 它必须活过会话拆除（[code]finish()[/code] → [code]clear()[/code]）。
## 由菜单在开练习前写入、在 [code]on_enter()[/code] 里消费后自行清空。
static var return_menu_state: Dictionary = {}
## 仅"从练习返回"这一趟为 true。没有它，残留的 [code]return_menu_state[/code] 会让下次正常进入
## 也直接跳到第三级（曾出此 bug）—— 所以还原必须由"这次是返回"来授权，而不是"有状态就还原"。
static var restore_menu_on_enter: bool = false


## 开一局符卡练习：先经 SaveData.reset_session() 清干净上一局，再装载本局载荷。
static func start(p_phase: PhaseData, p_boss_scene: PackedScene, p_boss_name: String, p_stage_id: int,
		p_phase_index: int = 0, p_spell_background: PackedScene = null, p_bgm_key: String = "") -> void:
	SaveData.reset_session()
	is_practice_mode = true
	phase = p_phase
	boss_scene = p_boss_scene
	boss_name = p_boss_name
	stage_id = p_stage_id
	phase_index = p_phase_index
	background = StageCatalog.background(p_stage_id, SaveData.selected_difficulty)
	spell_background = p_spell_background
	bgm_key = p_bgm_key


## 结束练习（重开中不清：is_restarting 时保留载荷）
static func finish() -> void:
	if SaveData.is_restarting:
		return
	clear()


## 清空练习模式 + 载荷（不碰 is_stage_practice——那是逐面玩法标志，由 reset_session 管）
static func clear() -> void:
	is_practice_mode = false
	phase = null
	boss_scene = null
	boss_name = ""
	stage_id = 1
	phase_index = 0
	background = null
	spell_background = null
	bgm_key = ""
