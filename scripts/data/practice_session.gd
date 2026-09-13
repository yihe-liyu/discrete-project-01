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


## 开一局符卡练习：先经 SaveData.reset_session() 清干净上一局，再装载本局载荷。
static func start(p_phase: PhaseData, p_boss_scene: PackedScene, p_boss_name: String, p_stage_id: int, p_phase_index: int = 0) -> void:
	SaveData.reset_session()
	is_practice_mode = true
	phase = p_phase
	boss_scene = p_boss_scene
	boss_name = p_boss_name
	stage_id = p_stage_id
	phase_index = p_phase_index
	background = StageCatalog.background(p_stage_id)


## 结束练习（重开中不清：restarting 时保留载荷）
static func finish() -> void:
	if SaveData.restarting:
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
