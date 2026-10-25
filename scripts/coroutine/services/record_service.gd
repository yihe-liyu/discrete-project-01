## 记录服务 —— 阶段身份 + 记录的单一入口。
## Boss 不再直接摸 SaveData.record_*（系统走注入/集中，不再散摸全局）。
## 身份经 BossCatalog.resolve_identity 解析（Boss 不再自我推导）。
## 用静态方法：bare Boss（无 ctx 的测试/练习）也能直接用。
class_name RecordService
extends RefCounted

## 沙盒开关：创作台 / 调试排练置 true 时，阶段开始 / 收取都不写符卡簿。
## 只影响记录落盘，不影响 Boss 战斗、奖励分与 UI 演出；离开沙盒必须恢复 false。
static var is_sandbox: bool = false

## 阶段开始：普通 = 解锁 + 记尝试；练习 = 记尝试；沙盒 = 不记。
static func record_phase_start(pid: PhaseIdentity) -> void:
	if not pid or is_sandbox:
		return
	if PracticeSession.is_practice_mode:
		SaveData.spell_book_mgr.record_practice(pid, false)
	else:
		SaveData.spell_book_mgr.unlock_spell(pid)
		SaveData.spell_book_mgr.record_spell(pid, false, 0, 0.0)


## 阶段结束补记：练习 = 只补 capture；普通 = 干净收取才补 capture（miss 后不收）；沙盒 = 不记。
static func record_phase_capture(pid: PhaseIdentity, captured: bool, bonus: int, elapsed: float) -> void:
	if not pid or is_sandbox:
		return
	if PracticeSession.is_practice_mode:
		SaveData.spell_book_mgr.record_practice_capture(pid)
	elif captured:
		SaveData.spell_book_mgr.record_capture(pid, bonus, elapsed)
