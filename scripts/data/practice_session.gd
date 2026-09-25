## 符卡练习会话：模式标志 + 载荷（阶段 / Boss 场景 / 名字 / 关卡 / 背景）。
## 从 SaveData 拆出。「开一局」的整局复位由 SaveData.reset_session() 统一编排。
class_name PracticeSession
extends RefCounted

## 符卡练习模式（单 phase Boss）
static var is_practice_mode: bool = false
static var phase: PhaseData
static var boss_scene: PackedScene
static var boss_name: String
static var stage_id: int = 1
static var phase_index: int = 0
static var background: PackedScene
## 符卡背景（每 Boss 一张）：`start_spell_card()` 自建 BossData 会丢 `BossData.spell_background`，
## 故练习载荷单独携带一张，由 game_scene 优先取 Boss 的、回落取这张。
static var spell_background: Texture2D
## 从练习返回符卡练习菜单时，要还原到的**层级与选中项**（`{section, stage, phase, diff, char}`）。
## ⚠️ 故意**不**在 `clear()` 里清 —— 它必须活过会话拆除（`finish()` → `clear()`）。
## 由菜单在开练习前写入、在 `on_enter()` 里消费后自行清空。
static var return_menu_state: Dictionary = {}
## **仅"从练习返回"这一趟**为 true。没有它，残留的 `return_menu_state` 会让**下次正常进入**
## 也直接跳到第三级（曾出此 bug）—— 所以还原必须由"这次是返回"来授权，而不是"有状态就还原"。
static var restore_menu_on_enter: bool = false


## 开一局符卡练习：先经 SaveData.reset_session() 清干净上一局，再装载本局载荷。
static func start(p_phase: PhaseData, p_boss_scene: PackedScene, p_boss_name: String, p_stage_id: int,
		p_phase_index: int = 0, p_spell_background: Texture2D = null) -> void:
	SaveData.reset_session()
	is_practice_mode = true
	phase = p_phase
	boss_scene = p_boss_scene
	boss_name = p_boss_name
	stage_id = p_stage_id
	phase_index = p_phase_index
	background = StageCatalog.background(p_stage_id)
	spell_background = p_spell_background


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
